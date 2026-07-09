-- ============================================================================
-- gtarp_ransom/server/main.lua
--
-- Pure logic. Calls Bridge.* (bridge/sv_framework.lua) for all framework /
-- native access. No direct framework / native calls here (§6 gate).
--
-- The recipe's `qbx_police`/`qbx_radialmenu` already ship a raw "Kidnap"/
-- "Take Hostage" physical mechanic (drag a restrained citizen into a
-- vehicle trunk) — zero economy, zero paper trail. This resource listens
-- to that same net event (`police:server:KidnapPlayer`) and hangs a ransom
-- ledger + felony record off it. It never re-implements the restrain/trunk
-- mechanic itself.
--
-- Client-trust note: `police:server:KidnapPlayer` is a globally addressable
-- net event already registered by qbx_police. Registering a SECOND handler
-- here (below) does not run "after" or "gated by" the recipe's own handler
-- — FiveM fires every registered handler independently. A modified client
-- could TriggerServerEvent this event directly with a fabricated victim id,
-- so this handler re-derives validity itself (both players real and online,
-- genuinely restrained per Bridge.IsRestrained, genuinely close per
-- Bridge.Distance) rather than trusting "the event fired" — the same
-- lesson gtarp_courier's payout exploit and gtarp_mdt's spoofable-source
-- bug taught this session.
-- ============================================================================

local lastAction = {}    -- [src] = { [key] = ts } — chat-command spam guard
local lastKidnapBy = {}  -- [kidnapperCid] = { victimCid, victimName, ts } — validated kidnap, pending a demand

local function now() return os.time() end

local function dbg(msg)
    if Config.Debug then print('[gtarp_ransom] ' .. msg) end
end

local function rl(src, key, window)
    lastAction[src] = lastAction[src] or {}
    local t = now()
    if (lastAction[src][key] or 0) + window > t then return false end
    lastAction[src][key] = t
    return true
end

local function atDropPoint(src)
    local c = Bridge.GetCoords(src)
    if not c then return false end
    return Bridge.Distance(c, Config.DropPoint.coords) <= Config.DropPoint.radius
end

local function activeCaseById(id)
    local row
    pcall(function()
        row = MySQL.single.await(
            "SELECT * FROM gtarp_ransom_cases WHERE id = ? AND status = 'active'", { id })
    end)
    return row
end

local function activeCaseForVictim(victimCid)
    local row
    pcall(function()
        row = MySQL.single.await(
            "SELECT id FROM gtarp_ransom_cases WHERE victim_citizenid = ? AND status = 'active'", { victimCid })
    end)
    return row
end

-- ---------------------------------------------------------------------------
-- Kidnap validation — re-derives the whole event independently of the
-- recipe's own handler (see module header). Records the pairing in memory
-- so /demandransom can be gated on a real, recent, server-verified event.
-- ---------------------------------------------------------------------------
RegisterNetEvent('police:server:KidnapPlayer', function(kidnapedSrc)
    local src = source
    kidnapedSrc = tonumber(kidnapedSrc)
    if not kidnapedSrc or kidnapedSrc == src then return end

    local kidnapperCid = Bridge.GetCitizenId(src)
    local victimCid = Bridge.GetCitizenId(kidnapedSrc)
    if not kidnapperCid or not victimCid then return end

    if not Bridge.IsRestrained(kidnapedSrc) then return end

    local a, b = Bridge.GetCoords(src), Bridge.GetCoords(kidnapedSrc)
    if not a or not b or Bridge.Distance(a, b) > 5.0 then return end

    lastKidnapBy[kidnapperCid] = {
        victimCid = victimCid,
        victimName = Bridge.GetPlayerName(kidnapedSrc),
        ts = now(),
    }
    dbg(('validated kidnap: %s took %s'):format(kidnapperCid, victimCid))
end)

-- ---------------------------------------------------------------------------
-- /demandransom <amount> <instructions...> — only valid against a citizen
-- this same source was just server-verified to have kidnapped.
-- ---------------------------------------------------------------------------
local function cmdDemandRansom(src, args)
    if src == 0 then return end
    if not rl(src, 'demandransom', Config.Ransom.PostCooldownSec) then return end
    local kidnapperCid = Bridge.GetCitizenId(src)
    if not kidnapperCid then return end

    local R = Config.Ransom
    local amount = math.floor(tonumber(args[1]) or 0)
    local instructions = table.concat(args, ' ', 2):gsub('^%s+', ''):gsub('%s+$', '')

    if amount < R.MinAmount or amount > R.MaxAmount
        or #instructions < R.InstructionsMin or #instructions > R.InstructionsMax then
        Bridge.Notify(src, 'Ransom',
            ('Usage: /demandransom [$%d-%d] [instructions %d-%d chars]')
            :format(R.MinAmount, R.MaxAmount, R.InstructionsMin, R.InstructionsMax), 'error')
        return
    end

    local pending = lastKidnapBy[kidnapperCid]
    if not pending or (pending.ts + R.DemandWindowSec) < now() then
        Bridge.Notify(src, 'Ransom', 'You have not just kidnapped anyone.', 'error')
        return
    end

    if activeCaseForVictim(pending.victimCid) then
        Bridge.Notify(src, 'Ransom', 'There is already an active ransom on that person.', 'error')
        return
    end

    -- Consume the pending kidnap so a second /demandransom can't open a
    -- second case off the same physical kidnap.
    lastKidnapBy[kidnapperCid] = nil

    local kidnapperName = Bridge.GetPlayerName(src)
    local ok, caseId = pcall(function()
        return MySQL.insert.await([[
            INSERT INTO gtarp_ransom_cases
                (kidnapper_citizenid, kidnapper_name, victim_citizenid, victim_name, amount, instructions, expires_at)
            VALUES (?, ?, ?, ?, ?, ?, NOW() + INTERVAL ? MINUTE)
        ]], { kidnapperCid, kidnapperName, pending.victimCid, pending.victimName, amount, instructions, R.TimeoutMinutes })
    end)
    if not ok or not caseId then
        Bridge.Notify(src, 'Ransom', 'Could not open a ransom case — try again.', 'error')
        return
    end

    local evidenceCaseId
    if Bridge.ResourceStarted('gtarp_evidence') then
        pcall(function()
            evidenceCaseId = exports.gtarp_evidence:EnsureCase(nil, 'Kidnapping — ransom demand', kidnapperCid)
            if evidenceCaseId then
                exports.gtarp_evidence:AppendEntry(evidenceCaseId, 'ransom_demand', {
                    ransom_case_id = caseId, amount = amount, instructions = instructions,
                    victim_citizenid = pending.victimCid,
                }, 'gtarp_ransom')
                exports.gtarp_evidence:LinkSuspect(evidenceCaseId, kidnapperCid, nil)
            end
        end)
    end
    if evidenceCaseId then
        pcall(function()
            MySQL.update.await('UPDATE gtarp_ransom_cases SET evidence_case_id = ? WHERE id = ?',
                { evidenceCaseId, caseId })
        end)
    end

    Bridge.Notify(src, 'Ransom', ('Ransom #%d demanded: $%d.'):format(caseId, amount), 'success')
    local victimSrc = Bridge.GetSourceByCitizenId(pending.victimCid)
    if victimSrc then
        Bridge.Notify(victimSrc, 'Ransom',
            ('A $%d ransom has been demanded for your release: "%s"'):format(amount, instructions), 'error')
    end
    dbg(('case #%d: %s demands $%d for %s'):format(caseId, kidnapperCid, amount, pending.victimCid))
end

-- ---------------------------------------------------------------------------
-- Close a case (paid or expired). Always escalates to an mdt warrant —
-- kidnapping is a felony regardless of whether the ransom was ever paid.
-- Server-authoritative: caller passes only the row already fetched under a
-- guarded UPDATE, never client input.
-- ---------------------------------------------------------------------------
local function issueWarrantForCase(row)
    if not Bridge.ResourceStarted('gtarp_mdt') then return end
    pcall(function()
        exports.gtarp_mdt:IssueWarrant(row.kidnapper_citizenid,
            ('kidnapping — ransom case #%d (%s)'):format(row.id, row.victim_name),
            'Anonymous Tip')
    end)
end

local function closeCaseEvidence(row, kind, payload)
    if not row.evidence_case_id or not Bridge.ResourceStarted('gtarp_evidence') then return end
    pcall(function()
        exports.gtarp_evidence:AppendEntry(row.evidence_case_id, kind, payload, 'gtarp_ransom')
    end)
end

-- ---------------------------------------------------------------------------
-- /payransom <caseId> — anyone can pay, from the drop point, in full.
-- Guarded UPDATE ... WHERE status='active' so a race between two payers (or
-- a payer and the expiry sweep) can only land once.
-- ---------------------------------------------------------------------------
local function cmdPayRansom(src, args)
    if src == 0 then return end
    if not rl(src, 'payransom', Config.Ransom.PayCooldownSec) then return end
    local payerCid = Bridge.GetCitizenId(src)
    if not payerCid then return end

    local id = tonumber(args[1])
    if not id then
        Bridge.Notify(src, 'Ransom', 'Usage: /payransom [case #]', 'error')
        return
    end

    if not atDropPoint(src) then
        Bridge.Notify(src, 'Ransom', ('You need to be at %s.'):format(Config.DropPoint.label), 'error')
        return
    end

    local row = activeCaseById(id)
    if not row then
        Bridge.Notify(src, 'Ransom', 'No active ransom with that number.', 'error')
        return
    end

    local amount = tonumber(row.amount) or 0
    if not Bridge.ChargeBank(src, amount, 'ransom-payment') then
        Bridge.Notify(src, 'Ransom', ('You need $%d in the bank.'):format(amount), 'error')
        return
    end

    -- Mark paid BEFORE crediting the kidnapper — the guarded WHERE stops a
    -- second payer (or the expiry sweep firing concurrently) from also
    -- landing on the same case. A lost race refunds the payer in full.
    local marked = false
    pcall(function()
        marked = MySQL.update.await(
            "UPDATE gtarp_ransom_cases SET status = 'paid', paid_by_citizenid = ?, resolved_at = NOW() WHERE id = ? AND status = 'active'",
            { payerCid, id }) == 1
    end)
    if not marked then
        Bridge.CreditBankByCitizenId(payerCid, amount, 'ransom-payment-refund')
        Bridge.Notify(src, 'Ransom', 'That ransom was already resolved — refunded.', 'error')
        return
    end

    Bridge.CreditBankByCitizenId(row.kidnapper_citizenid, amount, 'ransom-payout')
    closeCaseEvidence(row, 'ransom_paid', { amount = amount, payer_citizenid = payerCid })
    issueWarrantForCase(row)

    Bridge.Notify(src, 'Ransom', ('Ransom #%d paid — $%d.'):format(id, amount), 'success')
    local kidnapperSrc = Bridge.GetSourceByCitizenId(row.kidnapper_citizenid)
    if kidnapperSrc then
        Bridge.Notify(kidnapperSrc, 'Ransom', ('Ransom #%d was paid — $%d landed in your bank.'):format(id, amount), 'success')
    end
    local victimSrc = Bridge.GetSourceByCitizenId(row.victim_citizenid)
    if victimSrc then
        Bridge.Notify(victimSrc, 'Ransom', 'Your ransom has been paid.', 'success')
    end
    dbg(('case #%d paid by %s ($%d)'):format(id, payerCid, amount))
end

-- ---------------------------------------------------------------------------
-- Expiry sweep — unpaid past due closes 'expired'. No refund owed (nobody
-- paid), but still escalates to a warrant: the kidnapping happened either way.
-- ---------------------------------------------------------------------------
local function sweepExpired()
    local due = {}
    pcall(function()
        due = MySQL.query.await(
            "SELECT * FROM gtarp_ransom_cases WHERE status = 'active' AND expires_at <= NOW()") or {}
    end)
    for _, row in ipairs(due) do
        local marked = false
        pcall(function()
            marked = MySQL.update.await(
                "UPDATE gtarp_ransom_cases SET status = 'expired', resolved_at = NOW() WHERE id = ? AND status = 'active'",
                { row.id }) == 1
        end)
        if marked then
            closeCaseEvidence(row, 'ransom_expired', {})
            issueWarrantForCase(row)
            dbg(('case #%d expired unpaid'):format(row.id))
        end
    end
end

CreateThread(function()
    while true do
        Wait(Config.Ransom.SweepSec * 1000)
        sweepExpired()
    end
end)

-- ---------------------------------------------------------------------------
-- Commands + boot
-- ---------------------------------------------------------------------------
Bridge.RegisterCommand('demandransom', function(source, args) cmdDemandRansom(source, args) end)
Bridge.RegisterCommand('payransom', function(source, args) cmdPayRansom(source, args) end)

AddEventHandler('onResourceStart', function(resource)
    if resource ~= GetCurrentResourceName() then return end
    local activeN, totalAmount = 0, 0
    pcall(function()
        local r = MySQL.single.await(
            "SELECT COUNT(*) AS n, COALESCE(SUM(amount), 0) AS total FROM gtarp_ransom_cases WHERE status = 'active'")
        activeN = r and tonumber(r.n) or 0
        totalAmount = r and tonumber(r.total) or 0
    end)
    print(('[gtarp_ransom] ledger open — %d active case(s) ($%d demanded); mdt escalation %s')
        :format(activeN, totalAmount, Bridge.ResourceStarted('gtarp_mdt') and 'ONLINE' or 'offline'))
end)

---Case counts for devtest and future consumers.
exports('GetSummary', function()
    local out = { activeCases = 0, totalDemanded = 0 }
    pcall(function()
        local r = MySQL.single.await(
            "SELECT COUNT(*) AS n, COALESCE(SUM(amount), 0) AS total FROM gtarp_ransom_cases WHERE status = 'active'")
        out.activeCases = r and tonumber(r.n) or 0
        out.totalDemanded = r and tonumber(r.total) or 0
    end)
    return out
end)
