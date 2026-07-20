-- ============================================================================
-- palm6_business/server/main.lua
--
-- Player-owned businesses: registry, pooled BANK account, employees, payroll,
-- customer charges, a capped NPC walk-in income faucet, and a full ledger.
-- Server-authoritative throughout; the client sends intent only.
--
-- MONEY SAFETY (spec §2): a business account is pooled REAL money, never minted.
-- Every credit is charge-before-credit; every debit is an atomic guarded UPDATE
-- (WHERE balance >= amount) so the account can't overdraw; NPC income is bounded
-- by a clean-money cost basis + per-worker cooldown + per-business daily cap;
-- every move writes a palm6_business_ledger row.
-- ============================================================================

local function enabled() return Config.Enabled == true end

-- ---------------------------------------------------------------------------
-- Utils
-- ---------------------------------------------------------------------------

-- Finite non-negative integer, or nil. `n ~= n` rejects NaN (which floor()
-- passes through and every </> comparison treats as false — the lottery lesson);
-- math.huge rejects Inf. ALL client-supplied amounts pass through here first.
local function sanitizeInt(v)
    v = tonumber(v)
    if not v or v ~= v or v == math.huge or v == -math.huge then return nil end
    v = math.floor(v)
    if v < 0 then return nil end
    return v
end

local function clampInt(v, lo, hi)
    v = sanitizeInt(v)
    if not v then return nil end
    if v < lo then v = lo end
    if v > hi then v = hi end
    return v
end

local function nowSec() return os.time() end
local function dayKey() return os.date('!%Y-%m-%d') end  -- UTC bucket

local function sanitizeName(raw)
    if type(raw) ~= 'string' then return nil end
    local s = raw:gsub("[^%w %&'%-]", '')
    s = s:gsub('%s+', ' '):gsub('^%s+', ''):gsub('%s+$', '')
    if #s < Config.NameMinLen or #s > Config.NameMaxLen then return nil end
    local low = s:lower()
    for _, bad in ipairs(Config.Blocklist) do
        if low:find(bad, 1, true) then return nil end
    end
    return s
end

local function typeInfo(key)
    for _, t in ipairs(Config.Types) do
        if t.key == key then return t end
    end
    return nil
end

local function notify(src, title, msg, t) Bridge.Notify(src, title, msg, t) end

-- ---------------------------------------------------------------------------
-- DB layer (our schema — portable). Account never held in memory: the DB row is
-- authoritative, mutated only through the atomic helpers below.
-- ---------------------------------------------------------------------------

local function getMembership(cid)
    if not cid then return nil end
    return MySQL.single.await([[
        SELECT m.citizenid, m.business_id, m.role, m.wage, m.clocked_in, m.last_serve_at,
               b.name AS business_name, b.biz_type, b.account_balance, b.supply_units,
               b.day_key, b.day_npc_income, b.owner_cid
          FROM palm6_business_members m
          JOIN palm6_businesses b ON b.id = m.business_id
         WHERE m.citizenid = ?
    ]], { cid })
end

local function getBusinessById(id)
    return MySQL.single.await('SELECT * FROM palm6_businesses WHERE id = ?', { id })
end

local function rosterOf(businessId)
    return MySQL.query.await(
        'SELECT citizenid, role, wage, clocked_in, name FROM palm6_business_members WHERE business_id = ? ORDER BY role DESC, hired_at ASC',
        { businessId }) or {}
end

local function insertLedger(businessId, actorCid, action, amount, balanceAfter, memo)
    pcall(function()
        MySQL.insert.await(
            'INSERT INTO palm6_business_ledger (business_id, actor_cid, action, amount, balance_after, memo) VALUES (?,?,?,?,?,?)',
            { businessId, actorCid, action, amount, balanceAfter, memo })
    end)
end

-- Credit the account by `amount` (amount already came from a real player). Logs.
-- Returns the new balance.
local function creditAccount(businessId, amount, actorCid, action, memo)
    MySQL.update.await('UPDATE palm6_businesses SET account_balance = account_balance + ? WHERE id = ?', { amount, businessId })
    local bal = MySQL.scalar.await('SELECT account_balance FROM palm6_businesses WHERE id = ?', { businessId }) or 0
    insertLedger(businessId, actorCid, action, amount, bal, memo)
    return bal
end

-- Atomic guarded debit — the account can NEVER go negative. Returns the new
-- balance on success, or nil if the account could not cover `amount`. Caller
-- logs the ledger row (with the right action/memo) on success.
local function debitAccount(businessId, amount)
    local aff = MySQL.update.await(
        'UPDATE palm6_businesses SET account_balance = account_balance - ? WHERE id = ? AND account_balance >= ?',
        { amount, businessId, amount })
    if aff ~= 1 then return nil end
    return MySQL.scalar.await('SELECT account_balance FROM palm6_businesses WHERE id = ?', { businessId }) or 0
end

-- ---------------------------------------------------------------------------
-- Ephemeral intent (in-memory, NOT money state): pending hire/charge prompts +
-- per-actor anti-spam cooldowns. Cleared on drop.
-- ---------------------------------------------------------------------------
local pendingHire = {}    -- [targetSrc] = { businessId, businessName, ownerCid, expiresAt }
local pendingCharge = {}  -- [targetSrc] = { businessId, businessName, cashierCid, amount, memo, expiresAt }
local hireCd = {}         -- [src] = epoch
local chargeCd = {}       -- [src] = epoch

local function onCooldown(map, src, seconds)
    local t = map[src]
    if t and (nowSec() - t) < seconds then return true end
    return false
end

-- ---------------------------------------------------------------------------
-- Menu snapshot -> client
-- ---------------------------------------------------------------------------
local function pushMenu(src)
    local cid = Bridge.GetCitizenId(src)
    local m = getMembership(cid)
    local data = { enabled = enabled(), types = Config.Types }
    if m then
        local roster = rosterOf(m.business_id)
        local today = dayKey()
        local dayIncome = (m.day_key == today) and (m.day_npc_income or 0) or 0
        data.business = {
            id = m.business_id,
            name = m.business_name,
            biz_type = m.biz_type,
            role = m.role,
            roleName = Config.RoleName[m.role] or '?',
            balance = m.account_balance or 0,
            supply = m.supply_units or 0,
            clockedIn = m.clocked_in == 1,
            dayIncome = dayIncome,
            dailyCap = Config.DailyNpcIncome,
            roster = roster,
        }
        data.cfg = {
            stockUnitCost = Config.StockUnitCost,
            servePayout = Config.ServePayout,
            maxSupply = Config.MaxSupplyUnits,
            maxWage = Config.MaxWage,
        }
    else
        data.cfg = { registrationCost = Config.RegistrationCost }
    end
    TriggerClientEvent('palm6_business:menuData', src, data)
end

-- ---------------------------------------------------------------------------
-- Operations
-- ---------------------------------------------------------------------------

local function opRegister(src, rawName, typeKey)
    if not enabled() then return end
    local cid = Bridge.GetCitizenId(src)
    if not cid then return end
    if getMembership(cid) then
        return notify(src, 'Business', 'You already belong to a business.', 'error')
    end
    local name = sanitizeName(rawName)
    if not name then
        return notify(src, 'Business', ('Name must be %d-%d letters/digits.'):format(Config.NameMinLen, Config.NameMaxLen), 'error')
    end
    local ti = typeInfo(typeKey)
    if not ti then return notify(src, 'Business', 'Unknown business type.', 'error') end
    if MySQL.scalar.await('SELECT id FROM palm6_businesses WHERE name = ?', { name }) then
        return notify(src, 'Business', 'That business name is taken.', 'error')
    end
    -- Charge-before-create: the registration fee is a clean-money SINK.
    if not Bridge.ChargeBank(src, Config.RegistrationCost, 'business-register') then
        return notify(src, 'Business', ('You need $%d in the bank to register.'):format(Config.RegistrationCost), 'error')
    end
    local id
    local okIns = pcall(function()
        id = MySQL.insert.await(
            'INSERT INTO palm6_businesses (owner_cid, name, biz_type, account_balance, supply_units, day_key, day_npc_income) VALUES (?,?,?,0,0,?,0)',
            { cid, name, typeKey, dayKey() })
    end)
    if not okIns or not id then
        Bridge.CreditBankByCitizenId(cid, Config.RegistrationCost, 'business-register-refund')
        return notify(src, 'Business', 'Could not register (name may have just been taken). Refunded.', 'error')
    end
    local okMem = pcall(function()
        MySQL.insert.await(
            'INSERT INTO palm6_business_members (citizenid, business_id, role, wage, clocked_in, name) VALUES (?,?,?,0,1,?)',
            { cid, id, Config.Role.Owner, Bridge.GetPlayerName(src) })
    end)
    if not okMem then
        MySQL.update.await('DELETE FROM palm6_businesses WHERE id = ?', { id })
        Bridge.CreditBankByCitizenId(cid, Config.RegistrationCost, 'business-register-refund')
        return notify(src, 'Business', 'Could not register. Refunded.', 'error')
    end
    insertLedger(id, cid, 'register', 0, 0, ('Registered %s (fee $%d)'):format(ti.label, Config.RegistrationCost))
    notify(src, 'Business', ('%s is registered. Open /%s to run it.'):format(name, Config.Command), 'success')
    pushMenu(src)
end

local function opDeposit(src, amount)
    if not enabled() then return end
    local cid = Bridge.GetCitizenId(src)
    local m = getMembership(cid)
    if not m or m.role < Config.Role.Owner then return notify(src, 'Business', 'Only the owner can move the account.', 'error') end
    amount = clampInt(amount, Config.MinAmount, Config.MaxPerAction)
    if not amount or amount < Config.MinAmount then return notify(src, 'Business', 'Invalid amount.', 'error') end
    if not Bridge.ChargeBank(src, amount, 'business-deposit') then
        return notify(src, 'Business', 'Not enough in your bank.', 'error')
    end
    local bal = creditAccount(m.business_id, amount, cid, 'deposit', 'Owner deposit')
    notify(src, 'Business', ('Deposited $%d. Account: $%d.'):format(amount, bal), 'success')
    pushMenu(src)
end

local function opWithdraw(src, amount)
    if not enabled() then return end
    local cid = Bridge.GetCitizenId(src)
    local m = getMembership(cid)
    if not m or m.role < Config.Role.Owner then return notify(src, 'Business', 'Only the owner can move the account.', 'error') end
    amount = clampInt(amount, Config.MinAmount, Config.MaxPerAction)
    if not amount or amount < Config.MinAmount then return notify(src, 'Business', 'Invalid amount.', 'error') end
    local bal = debitAccount(m.business_id, amount)
    if not bal then return notify(src, 'Business', 'The business account cannot cover that.', 'error') end
    if not Bridge.CreditBankByCitizenId(cid, amount, 'business-withdraw') then
        -- credit failed: put it back so nothing is lost.
        creditAccount(m.business_id, amount, cid, 'withdraw-refund', 'Withdraw failed, reversed')
        return notify(src, 'Business', 'Payout failed, reversed. Try again.', 'error')
    end
    insertLedger(m.business_id, cid, 'withdraw', -amount, bal, 'Owner withdraw')
    notify(src, 'Business', ('Withdrew $%d. Account: $%d.'):format(amount, bal), 'success')
    pushMenu(src)
end

local function opBuyStock(src, qty)
    if not enabled() then return end
    local cid = Bridge.GetCitizenId(src)
    local m = getMembership(cid)
    if not m or m.role < Config.Role.Owner then return notify(src, 'Business', 'Only the owner buys supply.', 'error') end
    qty = clampInt(qty, 1, Config.StockMaxPerBuy)
    if not qty or qty < 1 then return notify(src, 'Business', 'Invalid quantity.', 'error') end
    local room = Config.MaxSupplyUnits - (m.supply_units or 0)
    if room <= 0 then return notify(src, 'Business', 'Supply storage is full.', 'error') end
    if qty > room then qty = room end
    local cost = qty * Config.StockUnitCost
    if not Bridge.ChargeBank(src, cost, 'business-stock') then
        return notify(src, 'Business', ('You need $%d for %d supply.'):format(cost, qty), 'error')
    end
    local aff = MySQL.update.await(
        'UPDATE palm6_businesses SET supply_units = supply_units + ? WHERE id = ? AND supply_units + ? <= ?',
        { qty, m.business_id, qty, Config.MaxSupplyUnits })
    if aff ~= 1 then
        Bridge.CreditBankByCitizenId(cid, cost, 'business-stock-refund')
        return notify(src, 'Business', 'Storage filled up. Refunded.', 'error')
    end
    local bal = MySQL.scalar.await('SELECT account_balance FROM palm6_businesses WHERE id = ?', { m.business_id }) or 0
    insertLedger(m.business_id, cid, 'stock', 0, bal, ('Bought %dx supply ($%d)'):format(qty, cost))
    notify(src, 'Business', ('Bought %d supply for $%d.'):format(qty, cost), 'success')
    pushMenu(src)
end

-- NPC walk-in serve — the ONE faucet. Bounded by: clocked-in worker + supply
-- (cost basis) + per-worker cooldown + per-business daily cap. The client
-- skill-check is UX (active play); the money gates below are the real controls.
local function opServe(src)
    if not enabled() then return end
    local cid = Bridge.GetCitizenId(src)
    local m = getMembership(cid)
    if not m then return notify(src, 'Business', 'You do not work anywhere.', 'error') end
    if m.clocked_in ~= 1 then return notify(src, 'Business', 'Clock in first.', 'error') end
    if Config.NpcRequiresSupply and (m.supply_units or 0) < 1 then
        return notify(src, 'Business', 'No supply to serve with.', 'error')
    end
    if (nowSec() - (m.last_serve_at or 0)) < Config.ServeCooldownSec then
        return notify(src, 'Business', 'Serving too fast — wait a moment.', 'error')
    end
    local today = dayKey()
    local dayIncome = (m.day_key == today) and (m.day_npc_income or 0) or 0
    if dayIncome + Config.ServePayout > Config.DailyNpcIncome then
        return notify(src, 'Business', 'This business hit its daily walk-in limit.', 'error')
    end
    -- Atomic: consume 1 supply + credit payout + bump today's income, all guarded
    -- on supply>=1 AND the daily cap (WHERE reads the pre-update row). affected=0
    -- means a race lost the supply or the cap; re-read to message.
    local pay, cap = Config.ServePayout, Config.DailyNpcIncome
    local aff = MySQL.update.await([[
        UPDATE palm6_businesses
           SET supply_units = supply_units - 1,
               account_balance = account_balance + ?,
               day_npc_income = IF(day_key = ?, day_npc_income, 0) + ?,
               day_key = ?
         WHERE id = ?
           AND supply_units >= 1
           AND (IF(day_key = ?, day_npc_income, 0) + ?) <= ?
    ]], { pay, today, pay, today, m.business_id, today, pay, cap })
    if aff ~= 1 then
        return notify(src, 'Business', 'Could not serve (out of supply or at the daily limit).', 'error')
    end
    local bal = MySQL.scalar.await('SELECT account_balance FROM palm6_businesses WHERE id = ?', { m.business_id }) or 0
    insertLedger(m.business_id, '__NPC__', 'npc_sale', pay, bal, 'Walk-in customer')
    MySQL.update.await('UPDATE palm6_business_members SET last_serve_at = ? WHERE citizenid = ?', { nowSec(), cid })
    -- No pushMenu here: serving is a rapid, repeated action and reopening the
    -- root context menu each time would interrupt it. The notify confirms the
    -- payout; /business reopens with fresh supply/day figures.
    notify(src, 'Business', ('Served a customer (+$%d).'):format(pay), 'success')
end

local function opClock(src, wantIn)
    if not enabled() then return end
    local cid = Bridge.GetCitizenId(src)
    local m = getMembership(cid)
    if not m then return notify(src, 'Business', 'You do not work anywhere.', 'error') end
    local val = wantIn and 1 or 0
    MySQL.update.await('UPDATE palm6_business_members SET clocked_in = ? WHERE citizenid = ?', { val, cid })
    notify(src, 'Business', val == 1 and 'Clocked in.' or 'Clocked out.', 'inform')
    pushMenu(src)
end

local function opHireNearest(src)
    if not enabled() then return end
    local cid = Bridge.GetCitizenId(src)
    local m = getMembership(cid)
    if not m or m.role < Config.Role.Owner then return notify(src, 'Business', 'Only the owner can hire.', 'error') end
    if onCooldown(hireCd, src, Config.HireCooldownSec) then return notify(src, 'Business', 'Slow down.', 'error') end
    local count = MySQL.scalar.await('SELECT COUNT(*) FROM palm6_business_members WHERE business_id = ?', { m.business_id }) or 0
    if count >= (Config.MaxEmployees + 1) then return notify(src, 'Business', 'Your roster is full.', 'error') end
    local myC = Bridge.GetCoords(src)
    if not myC then return end
    local bestSrc, bestDist
    for _, sid in ipairs(Bridge.GetOnlinePlayers()) do
        if sid ~= src then
            local theirCid = Bridge.GetCitizenId(sid)
            if theirCid and not getMembership(theirCid) then
                local c = Bridge.GetCoords(sid)
                if c then
                    local d = Bridge.Distance(myC, c)
                    if d <= Config.HireRadius and (not bestDist or d < bestDist) then
                        bestSrc, bestDist = sid, d
                    end
                end
            end
        end
    end
    if not bestSrc then return notify(src, 'Business', 'No unaffiliated person nearby.', 'error') end
    hireCd[src] = nowSec()
    pendingHire[bestSrc] = { businessId = m.business_id, businessName = m.business_name, ownerCid = cid, expiresAt = nowSec() + Config.HireExpirySec }
    TriggerClientEvent('palm6_business:hirePrompt', bestSrc, { businessName = m.business_name })
    notify(src, 'Business', 'Offer sent.', 'inform')
end

local function opAcceptHire(src)
    if not enabled() then return end
    local p = pendingHire[src]
    pendingHire[src] = nil
    if not p or nowSec() > p.expiresAt then return notify(src, 'Business', 'That offer expired.', 'error') end
    local cid = Bridge.GetCitizenId(src)
    if not cid then return end
    if getMembership(cid) then return notify(src, 'Business', 'You already belong to a business.', 'error') end
    if not getBusinessById(p.businessId) then return notify(src, 'Business', 'That business no longer exists.', 'error') end
    local count = MySQL.scalar.await('SELECT COUNT(*) FROM palm6_business_members WHERE business_id = ?', { p.businessId }) or 0
    if count >= (Config.MaxEmployees + 1) then return notify(src, 'Business', 'That roster filled up.', 'error') end
    local ok = pcall(function()
        MySQL.insert.await(
            'INSERT INTO palm6_business_members (citizenid, business_id, role, wage, clocked_in, name) VALUES (?,?,?,0,0,?)',
            { cid, p.businessId, Config.Role.Employee, Bridge.GetPlayerName(src) })
    end)
    if not ok then return notify(src, 'Business', 'Could not join.', 'error') end
    notify(src, 'Business', ('You joined %s.'):format(p.businessName), 'success')
    local ownerSrc = Bridge.GetSourceByCitizenId(p.ownerCid)
    if ownerSrc then notify(ownerSrc, 'Business', ('%s joined the team.'):format(Bridge.GetPlayerName(src)), 'success') end
end

local function opFire(src, targetCid)
    if not enabled() then return end
    local cid = Bridge.GetCitizenId(src)
    local m = getMembership(cid)
    if not m or m.role < Config.Role.Owner then return notify(src, 'Business', 'Only the owner can fire.', 'error') end
    if type(targetCid) ~= 'string' or targetCid == '' or targetCid == cid then return end
    local aff = MySQL.update.await(
        'DELETE FROM palm6_business_members WHERE citizenid = ? AND business_id = ? AND role < ?',
        { targetCid, m.business_id, Config.Role.Owner })
    if aff ~= 1 then return notify(src, 'Business', 'Not on your roster.', 'error') end
    notify(src, 'Business', 'Removed from the roster.', 'inform')
    local ts = Bridge.GetSourceByCitizenId(targetCid)
    if ts then notify(ts, 'Business', ('You were let go from %s.'):format(m.business_name), 'inform') end
    pushMenu(src)
end

local function opSetWage(src, targetCid, amount)
    if not enabled() then return end
    local cid = Bridge.GetCitizenId(src)
    local m = getMembership(cid)
    if not m or m.role < Config.Role.Owner then return notify(src, 'Business', 'Only the owner sets wages.', 'error') end
    if type(targetCid) ~= 'string' or targetCid == '' then return end
    amount = clampInt(amount, 0, Config.MaxWage)
    if amount == nil then return notify(src, 'Business', 'Invalid wage.', 'error') end
    local aff = MySQL.update.await(
        'UPDATE palm6_business_members SET wage = ? WHERE citizenid = ? AND business_id = ? AND role < ?',
        { amount, targetCid, m.business_id, Config.Role.Owner })
    if aff ~= 1 then return notify(src, 'Business', 'Not on your roster.', 'error') end
    notify(src, 'Business', ('Wage set to $%d/run.'):format(amount), 'success')
    pushMenu(src)
end

-- Pay each clocked-in employee (wage>0) from the account, capped at the live
-- balance — the atomic debit means payroll can NEVER overdraw. Stops when funds
-- run out; nothing is minted.
local function opPayroll(src)
    if not enabled() then return end
    local cid = Bridge.GetCitizenId(src)
    local m = getMembership(cid)
    if not m or m.role < Config.Role.Owner then return notify(src, 'Business', 'Only the owner runs payroll.', 'error') end
    local emps = MySQL.query.await(
        'SELECT citizenid, wage, name FROM palm6_business_members WHERE business_id = ? AND role < ? AND wage > 0 AND clocked_in = 1',
        { m.business_id, Config.Role.Owner }) or {}
    if #emps == 0 then return notify(src, 'Business', 'No clocked-in employees with a wage.', 'error') end
    local paid, total, ranDry = 0, 0, false
    for _, e in ipairs(emps) do
        local bal = debitAccount(m.business_id, e.wage)
        if not bal then ranDry = true break end
        if not Bridge.CreditBankByCitizenId(e.citizenid, e.wage, 'business-payroll') then
            creditAccount(m.business_id, e.wage, cid, 'payroll-refund', 'Payroll credit failed, reversed')
        else
            insertLedger(m.business_id, e.citizenid, 'payroll', -e.wage, bal, ('Wage to %s'):format(e.name or e.citizenid))
            paid = paid + 1
            total = total + e.wage
            local es = Bridge.GetSourceByCitizenId(e.citizenid)
            if es then notify(es, 'Business', ('Payday: +$%d from %s.'):format(e.wage, m.business_name), 'success') end
        end
    end
    notify(src, 'Business', ('Paid %d for $%d%s.'):format(paid, total, ranDry and ' (account ran out)' or ''), ranDry and 'error' or 'success')
    pushMenu(src)
end

local function opChargeNearest(src, amount, memo)
    if not enabled() then return end
    local cid = Bridge.GetCitizenId(src)
    local m = getMembership(cid)
    if not m then return notify(src, 'Business', 'You do not work anywhere.', 'error') end
    if onCooldown(chargeCd, src, Config.ChargeCooldownSec) then return notify(src, 'Business', 'Slow down.', 'error') end
    amount = clampInt(amount, Config.MinAmount, Config.ChargeMax)
    if not amount or amount < Config.MinAmount then return notify(src, 'Business', 'Invalid amount.', 'error') end
    memo = (type(memo) == 'string' and memo ~= '') and memo:sub(1, 64) or 'Sale'
    memo = memo:gsub("[^%w %&'%-%.,]", '')
    local myC = Bridge.GetCoords(src)
    if not myC then return end
    local bestSrc, bestDist
    for _, sid in ipairs(Bridge.GetOnlinePlayers()) do
        if sid ~= src then
            local c = Bridge.GetCoords(sid)
            if c then
                local d = Bridge.Distance(myC, c)
                if d <= Config.ChargeRadius and (not bestDist or d < bestDist) then bestSrc, bestDist = sid, d end
            end
        end
    end
    if not bestSrc then return notify(src, 'Business', 'No customer nearby.', 'error') end
    chargeCd[src] = nowSec()
    pendingCharge[bestSrc] = { businessId = m.business_id, businessName = m.business_name, cashierCid = cid, amount = amount, memo = memo, expiresAt = nowSec() + Config.ChargeExpirySec }
    TriggerClientEvent('palm6_business:chargePrompt', bestSrc, { businessName = m.business_name, amount = amount, memo = memo })
    notify(src, 'Business', 'Charge sent to the customer.', 'inform')
end

local function opAcceptCharge(src)
    if not enabled() then return end
    local p = pendingCharge[src]
    pendingCharge[src] = nil
    if not p or nowSec() > p.expiresAt then return notify(src, 'Business', 'That charge expired.', 'error') end
    if not getBusinessById(p.businessId) then return notify(src, 'Business', 'That business no longer exists.', 'error') end
    local customerCid = Bridge.GetCitizenId(src)
    if not customerCid then return end
    -- Charge-before-credit: pull the customer's bank first.
    if not Bridge.ChargeBank(src, p.amount, 'business-charge') then
        local cs = Bridge.GetSourceByCitizenId(p.cashierCid)
        if cs then notify(cs, 'Business', 'Customer could not pay.', 'error') end
        return notify(src, 'Business', 'You could not cover that charge.', 'error')
    end
    creditAccount(p.businessId, p.amount, customerCid, 'charge', p.memo)
    notify(src, 'Business', ('Paid $%d to %s.'):format(p.amount, p.businessName), 'success')
    local cs = Bridge.GetSourceByCitizenId(p.cashierCid)
    if cs then notify(cs, 'Business', ('Collected $%d from a customer.'):format(p.amount), 'success') end
end

local function opRename(src, rawName)
    if not enabled() then return end
    local cid = Bridge.GetCitizenId(src)
    local m = getMembership(cid)
    if not m or m.role < Config.Role.Owner then return notify(src, 'Business', 'Only the owner can rename.', 'error') end
    local name = sanitizeName(rawName)
    if not name then return notify(src, 'Business', 'Invalid name.', 'error') end
    if MySQL.scalar.await('SELECT id FROM palm6_businesses WHERE name = ? AND id <> ?', { name, m.business_id }) then
        return notify(src, 'Business', 'That name is taken.', 'error')
    end
    MySQL.update.await('UPDATE palm6_businesses SET name = ? WHERE id = ?', { name, m.business_id })
    notify(src, 'Business', ('Renamed to %s.'):format(name), 'success')
    pushMenu(src)
end

local function opResign(src)
    if not enabled() then return end
    local cid = Bridge.GetCitizenId(src)
    local m = getMembership(cid)
    if not m then return end
    if m.role >= Config.Role.Owner then
        return notify(src, 'Business', 'An owner cannot resign — transfer or close is coming later.', 'error')
    end
    MySQL.update.await('DELETE FROM palm6_business_members WHERE citizenid = ? AND business_id = ? AND role < ?', { cid, m.business_id, Config.Role.Owner })
    notify(src, 'Business', ('You left %s.'):format(m.business_name), 'inform')
    pushMenu(src)
end

local function opViewLedger(src)
    if not enabled() then return end
    local cid = Bridge.GetCitizenId(src)
    local m = getMembership(cid)
    if not m then return end
    local rows = MySQL.query.await(
        'SELECT action, amount, balance_after, memo, created_at FROM palm6_business_ledger WHERE business_id = ? ORDER BY id DESC LIMIT 15',
        { m.business_id }) or {}
    TriggerClientEvent('palm6_business:ledgerData', src, { name = m.business_name, rows = rows })
end

-- ---------------------------------------------------------------------------
-- Net events (guarded by palm6_eventguard — ensure order in custom.cfg).
-- ---------------------------------------------------------------------------
RegisterNetEvent('palm6_business:openMenu',   function() pushMenu(source) end)
RegisterNetEvent('palm6_business:register',   function(name, typeKey) opRegister(source, name, typeKey) end)
RegisterNetEvent('palm6_business:deposit',    function(amt) opDeposit(source, amt) end)
RegisterNetEvent('palm6_business:withdraw',   function(amt) opWithdraw(source, amt) end)
RegisterNetEvent('palm6_business:buyStock',   function(qty) opBuyStock(source, qty) end)
RegisterNetEvent('palm6_business:serve',      function() opServe(source) end)
RegisterNetEvent('palm6_business:clock',      function(wantIn) opClock(source, wantIn == true) end)
RegisterNetEvent('palm6_business:hireNearest',function() opHireNearest(source) end)
RegisterNetEvent('palm6_business:acceptHire', function() opAcceptHire(source) end)
RegisterNetEvent('palm6_business:fire',       function(cid) opFire(source, cid) end)
RegisterNetEvent('palm6_business:setWage',    function(cid, amt) opSetWage(source, cid, amt) end)
RegisterNetEvent('palm6_business:runPayroll', function() opPayroll(source) end)
RegisterNetEvent('palm6_business:chargeNearest', function(amt, memo) opChargeNearest(source, amt, memo) end)
RegisterNetEvent('palm6_business:acceptCharge',  function() opAcceptCharge(source) end)
RegisterNetEvent('palm6_business:viewLedger', function() opViewLedger(source) end)
RegisterNetEvent('palm6_business:rename',     function(name) opRename(source, name) end)
RegisterNetEvent('palm6_business:resign',     function() opResign(source) end)

AddEventHandler('playerDropped', function()
    local s = source
    pendingHire[s] = nil
    pendingCharge[s] = nil
    hireCd[s] = nil
    chargeCd[s] = nil
end)

-- ---------------------------------------------------------------------------
-- Command
-- ---------------------------------------------------------------------------
local function cmd(source)
    if not enabled() then
        return notify(source, 'Business', 'Businesses are not open yet.', 'error')
    end
    pushMenu(source)
end
Bridge.RegisterCommand(Config.Command, function(source) cmd(source) end)
if Config.CommandAlias and Config.CommandAlias ~= '' then
    Bridge.RegisterCommand(Config.CommandAlias, function(source) cmd(source) end)
end

-- ---------------------------------------------------------------------------
-- Exports (server-only) — seams for palm6_protection (Phase 1) + any future POS.
-- ---------------------------------------------------------------------------

-- Summary of the caller-cid's business, or nil.
exports('GetBusinessOf', function(citizenid)
    local m = getMembership(citizenid)
    if not m then return nil end
    return {
        id = m.business_id, name = m.business_name, biz_type = m.biz_type,
        role = m.role, balance = m.account_balance or 0, ownerCid = m.owner_cid,
    }
end)

-- Generic revenue seam: charge an ONLINE payer's bank into a business account.
-- Always player -> business (never mints). Returns true on success.
exports('Charge', function(businessId, payerCid, amount, memo)
    if not enabled() then return false end
    amount = sanitizeInt(amount)
    if not amount or amount < 1 then return false end
    if not getBusinessById(businessId) then return false end
    local psrc = Bridge.GetSourceByCitizenId(payerCid)
    if not psrc then return false end
    if not Bridge.ChargeBank(psrc, amount, 'business-charge-export') then return false end
    creditAccount(businessId, amount, payerCid, 'charge', (type(memo) == 'string' and memo:sub(1, 64)) or 'Charge')
    return true
end)

exports('GetAccountBalance', function(businessId)
    return MySQL.scalar.await('SELECT account_balance FROM palm6_businesses WHERE id = ?', { businessId }) or 0
end)

CreateThread(function()
    if enabled() then
        print('[palm6_business] ENABLED — player-owned businesses live.')
    else
        print('[palm6_business] loaded DARK (Config.Enabled=false) — prod-inert.')
    end
end)
