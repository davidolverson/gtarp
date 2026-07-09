-- ============================================================================
-- gtarp_loanshark/server/main.lua
--
-- Pure logic. Calls Bridge.* for all framework / inventory / mdt / native
-- access. No direct framework / native calls here (§6 gate).
--
-- The shark: /borrow dirty cash (black_money) up to a cap, owe principal plus
-- flat interest by a deadline, /repay in clean bank money at the shark. A sweep
-- defaults overdue loans → gtarp_mdt:IssueWarrant (which gtarp_bounty then
-- auto-posts as a contract). One open loan per citizen; you can't re-borrow
-- while wanted. Nothing here trusts a client-supplied amount, position, or item.
-- ============================================================================

local lastAction  = {}   -- [src] = ts of last command (spam guard)
local borrowLock  = {}   -- [citizenid] = true while a borrow is in flight
local repayLock   = {}   -- [citizenid] = true while a repay is in flight
local enabled     = false

local function now() return os.time() end

local function dbg(msg)
    if Config.Debug then print('[gtarp_loanshark] ' .. msg) end
end

local function atShark(src)
    local c = Bridge.GetCoords(src)
    if not c then return false end
    return Bridge.Distance(c, Config.Shark.coords) <= Config.Shark.radius
end

-- ---------------------------------------------------------------------------
-- Default sweep — overdue open loans become defaulted + a warrant. Guarded
-- status transition (WHERE status='open') so it's mutually exclusive with a
-- repay that settles the same loan: whichever flips 'open' first wins.
-- ---------------------------------------------------------------------------
local function runDefaultSweep()
    local due = {}
    pcall(function()
        due = MySQL.query.await(
            "SELECT id, citizenid, owed, repaid FROM gtarp_loanshark_loans WHERE status = 'open' AND due_at < NOW()") or {}
    end)
    for _, loan in ipairs(due) do
        local applied = false
        pcall(function()
            local aff = MySQL.update.await(
                "UPDATE gtarp_loanshark_loans SET status = 'defaulted', closed_at = NOW() WHERE id = ? AND status = 'open'",
                { loan.id })
            applied = (tonumber(aff) or 0) > 0
        end)
        if applied then
            local remaining = tonumber(loan.owed) - tonumber(loan.repaid)
            local reason = ('%s ($%d unpaid)'):format(Config.DefaultWarrantReason, remaining)
            local wid = Bridge.IssueWarrant(loan.citizenid, reason, Config.DefaultOfficerLabel)
            if wid then
                pcall(function()
                    MySQL.update.await("UPDATE gtarp_loanshark_loans SET warrant_id = ? WHERE id = ?", { wid, loan.id })
                end)
            end
            local sid = Bridge.GetSourceByCitizenId(loan.citizenid)
            if sid then
                Bridge.Notify(sid, 'Loan Shark',
                    'You missed your payment. The shark put word out — you\'re wanted now.', 'error')
            end
            print(('[gtarp_loanshark] loan %d defaulted (cid %s, $%d unpaid) — warrant %s'):format(
                loan.id, loan.citizenid, remaining, tostring(wid)))
        end
    end
end

-- ---------------------------------------------------------------------------
-- /borrow <amount>
-- ---------------------------------------------------------------------------
local function cmdBorrow(src, args)
    if src == 0 then return end
    if not enabled then Bridge.Notify(src, 'Loan Shark', 'The shark isn\'t around.', 'error'); return end
    local t = now()
    if (lastAction[src] or 0) + Config.CooldownSec > t then
        Bridge.Notify(src, 'Loan Shark', 'Hold on.', 'error'); return
    end
    lastAction[src] = t

    local amount = tonumber(args[1])
    if not amount or amount ~= math.floor(amount) then
        Bridge.Notify(src, 'Loan Shark', 'Usage: /borrow [amount]', 'error'); return
    end
    if amount < Config.MinPrincipal or amount > Config.MaxPrincipal then
        Bridge.Notify(src, 'Loan Shark', ('The shark lends $%d to $%d.'):format(Config.MinPrincipal, Config.MaxPrincipal), 'error')
        return
    end
    local cid = Bridge.GetCitizenId(src)
    if not cid then return end
    if not atShark(src) then
        Bridge.Notify(src, 'Loan Shark', ('You need to find %s.'):format(Config.Shark.label), 'error'); return
    end
    if Bridge.HasActiveWarrant(cid) then
        Bridge.Notify(src, 'Loan Shark', "Square things with the law first — the shark won't touch a wanted man.", 'error')
        return
    end
    if borrowLock[cid] then Bridge.Notify(src, 'Loan Shark', 'One thing at a time.', 'error'); return end
    borrowLock[cid] = true

    local existing
    pcall(function()
        existing = MySQL.single.await(
            "SELECT id FROM gtarp_loanshark_loans WHERE citizenid = ? AND status = 'open' LIMIT 1", { cid })
    end)
    if existing then
        borrowLock[cid] = nil
        Bridge.Notify(src, 'Loan Shark', 'You already owe the shark. Clear that first.', 'error'); return
    end

    local owed = math.floor(amount * (1 + Config.InterestBps / 10000))
    local loanId
    local ok = pcall(function()
        loanId = MySQL.insert.await(
            "INSERT INTO gtarp_loanshark_loans (citizenid, principal, owed, due_at) VALUES (?, ?, ?, NOW() + INTERVAL ? SECOND)",
            { cid, amount, owed, Config.TermSec })
    end)
    if not ok or not loanId then
        borrowLock[cid] = nil
        Bridge.Notify(src, 'Loan Shark', 'The shark isn\'t lending right now.', 'error'); return
    end
    -- Hand over the dirty principal; if it can't be given, cancel the loan so
    -- the borrower never owes for cash they didn't receive.
    if not Bridge.GiveDirty(src, Config.DirtyItem, amount) then
        pcall(function() MySQL.update.await("DELETE FROM gtarp_loanshark_loans WHERE id = ?", { loanId }) end)
        borrowLock[cid] = nil
        Bridge.Notify(src, 'Loan Shark', 'Couldn\'t hand over the cash — loan cancelled.', 'error'); return
    end

    borrowLock[cid] = nil
    Bridge.Notify(src, 'Loan Shark',
        ('Borrowed $%d dirty. You owe $%d clean within %dh — miss it and you\'re a marked man.'):format(
            amount, owed, math.floor(Config.TermSec / 3600)), 'success')
    dbg(('%s borrowed $%d (owes $%d)'):format(cid, amount, owed))
end

-- ---------------------------------------------------------------------------
-- /repay <amount|all>
-- ---------------------------------------------------------------------------
local function cmdRepay(src, args)
    if src == 0 then return end
    local t = now()
    if (lastAction[src] or 0) + Config.CooldownSec > t then
        Bridge.Notify(src, 'Loan Shark', 'Hold on.', 'error'); return
    end
    lastAction[src] = t

    local cid = Bridge.GetCitizenId(src)
    if not cid then return end
    if not atShark(src) then
        Bridge.Notify(src, 'Loan Shark', ('Bring it to %s.'):format(Config.Shark.label), 'error'); return
    end
    if repayLock[cid] then Bridge.Notify(src, 'Loan Shark', 'One thing at a time.', 'error'); return end
    repayLock[cid] = true

    local loan
    pcall(function()
        loan = MySQL.single.await(
            "SELECT id, owed, repaid FROM gtarp_loanshark_loans WHERE citizenid = ? AND status = 'open' LIMIT 1", { cid })
    end)
    if not loan then
        repayLock[cid] = nil
        Bridge.Notify(src, 'Loan Shark', 'You don\'t owe the shark anything.', 'inform'); return
    end

    local remaining = tonumber(loan.owed) - tonumber(loan.repaid)
    local pay
    if args[1] == 'all' or args[1] == nil then
        pay = remaining
    else
        pay = tonumber(args[1])
    end
    if not pay or pay ~= math.floor(pay) or pay <= 0 then
        repayLock[cid] = nil
        Bridge.Notify(src, 'Loan Shark', 'Usage: /repay [amount|all]', 'error'); return
    end
    if pay > remaining then pay = remaining end

    if not Bridge.TakeBank(src, pay, 'loanshark-repay') then
        repayLock[cid] = nil
        Bridge.Notify(src, 'Loan Shark', 'Not enough clean money in the bank.', 'error'); return
    end

    local newRepaid = tonumber(loan.repaid) + pay
    local settled = newRepaid >= tonumber(loan.owed)
    local aff = 0
    pcall(function()
        if settled then
            aff = MySQL.update.await(
                "UPDATE gtarp_loanshark_loans SET repaid = ?, status = 'repaid', closed_at = NOW() WHERE id = ? AND status = 'open'",
                { newRepaid, loan.id })
        else
            aff = MySQL.update.await(
                "UPDATE gtarp_loanshark_loans SET repaid = ? WHERE id = ? AND status = 'open'",
                { newRepaid, loan.id })
        end
    end)
    if (tonumber(aff) or 0) < 1 then
        -- The loan flipped out of 'open' under us (the sweep just defaulted it).
        -- Hand the payment back — a defaulted debt is settled with the law, not
        -- the shark (only a booking clears the warrant).
        Bridge.GiveBank(src, pay, 'loanshark-repay-refund')
        repayLock[cid] = nil
        Bridge.Notify(src, 'Loan Shark', 'That debt just went to collections — your payment was returned.', 'error')
        return
    end

    repayLock[cid] = nil
    if settled then
        Bridge.Notify(src, 'Loan Shark', 'Debt cleared. We\'re square.', 'success')
    else
        Bridge.Notify(src, 'Loan Shark', ('Paid $%d — $%d still on the book.'):format(pay, remaining - pay), 'success')
    end
    dbg(('%s repaid $%d (settled=%s)'):format(cid, pay, tostring(settled)))
end

-- ---------------------------------------------------------------------------
-- /loaninfo — your current debt + countdown.
-- ---------------------------------------------------------------------------
local function cmdLoanInfo(src)
    if src == 0 then return end
    local cid = Bridge.GetCitizenId(src)
    if not cid then return end
    local loan
    pcall(function()
        loan = MySQL.single.await(
            "SELECT owed, repaid, TIMESTAMPDIFF(SECOND, NOW(), due_at) AS secs FROM gtarp_loanshark_loans WHERE citizenid = ? AND status = 'open' LIMIT 1",
            { cid })
    end)
    if loan then
        local remaining = tonumber(loan.owed) - tonumber(loan.repaid)
        local secs = tonumber(loan.secs) or 0
        local when = secs > 0 and ('%dh%02dm left'):format(math.floor(secs / 3600), math.floor((secs % 3600) / 60)) or 'OVERDUE'
        Bridge.Notify(src, 'Loan Shark', ('You owe $%d clean · %s'):format(remaining, when), 'inform')
        return
    end
    local defaulted
    pcall(function()
        defaulted = MySQL.single.await(
            "SELECT id FROM gtarp_loanshark_loans WHERE citizenid = ? AND status = 'defaulted' AND warrant_id IS NOT NULL LIMIT 1",
            { cid })
    end)
    if defaulted then
        Bridge.Notify(src, 'Loan Shark', 'You defaulted on the shark — that debt is with the law now.', 'inform')
    else
        Bridge.Notify(src, 'Loan Shark', 'You owe the shark nothing.', 'inform')
    end
end

-- ---------------------------------------------------------------------------
-- Commands, sweep, boot
-- ---------------------------------------------------------------------------
Bridge.RegisterCommand('borrow', function(source, args) cmdBorrow(source, args) end)
Bridge.RegisterCommand('repay', function(source, args) cmdRepay(source, args) end)
Bridge.RegisterCommand('loaninfo', function(source) cmdLoanInfo(source) end)

CreateThread(function()
    while true do
        Wait(Config.DefaultSweepSec * 1000)
        if enabled then runDefaultSweep() end
    end
end)

AddEventHandler('onResourceStart', function(resource)
    if resource ~= GetCurrentResourceName() then return end
    if not Bridge.ItemExists(Config.DirtyItem) then
        print(('^1[gtarp_loanshark] FATAL: loan item "%s" is not registered in ox_inventory — '
            .. 'shark disabled (nothing to lend).^0'):format(Config.DirtyItem))
        return
    end
    enabled = true
    local open, defaulted = 0, 0
    pcall(function()
        local r = MySQL.single.await(
            "SELECT SUM(status='open') AS o, SUM(status='defaulted') AS d FROM gtarp_loanshark_loans")
        open = r and tonumber(r.o) or 0
        defaulted = r and tonumber(r.d) or 0
    end)
    print(('[gtarp_loanshark] shark open — %d loan(s) outstanding, %d defaulted; warrants %s, %d%% interest'):format(
        open, defaulted, Bridge.ResourceStarted('gtarp_mdt') and 'via gtarp_mdt' or 'OFFLINE (no gtarp_mdt)',
        math.floor(Config.InterestBps / 100)))
end)

--- Totals for devtest and future consumers.
exports('GetSummary', function()
    local out = { open = 0, repaid = 0, defaulted = 0, lentTotal = 0 }
    pcall(function()
        local r = MySQL.single.await(
            "SELECT SUM(status='open') AS o, SUM(status='repaid') AS r, SUM(status='defaulted') AS d, COALESCE(SUM(principal),0) AS p FROM gtarp_loanshark_loans")
        if r then
            out.open = tonumber(r.o) or 0
            out.repaid = tonumber(r.r) or 0
            out.defaulted = tonumber(r.d) or 0
            out.lentTotal = tonumber(r.p) or 0
        end
    end)
    return out
end)
