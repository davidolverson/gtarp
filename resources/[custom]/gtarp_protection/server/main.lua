-- ============================================================================
-- gtarp_protection/server/main.lua
--
-- Pure logic. Calls Bridge.* for all framework / inventory / turf / native
-- access. No direct framework / native calls here (§6 gate).
--
-- The racket: a gang member standing at a business inside a turf zone THEIR
-- gang controls runs /shakedown to collect protection money (paid DIRTY, in
-- black_money). Each business is "paid up" for Config.CollectIntervalSec after
-- a collection, gang-agnostic. Turf control is read live from gtarp_turf — lose
-- the zone, lose the income. Nothing here trusts a client-supplied gang, zone,
-- position, or item.
-- ============================================================================

local lastAction  = {}   -- [src] = ts of last /shakedown (spam guard)
local collectLock = {}   -- [business_id] = true while a shakedown is in flight

math.randomseed(os.time())

local function now() return os.time() end

local function dbg(msg)
    if Config.Debug then print('[gtarp_protection] ' .. msg) end
end

-- The business the caller is standing at (within its radius), or nil.
local function businessAt(src)
    local c = Bridge.GetCoords(src)
    if not c then return nil end
    for _, b in ipairs(Config.Businesses) do
        if Bridge.Distance(c, b.coords) <= b.radius then return b end
    end
    return nil
end

-- Seconds remaining before a business can be collected again, or 0 if ready.
local function cooldownRemaining(businessId)
    local newestAge
    pcall(function()
        local r = MySQL.single.await(
            "SELECT TIMESTAMPDIFF(SECOND, MAX(created_at), NOW()) AS age FROM gtarp_protection_collections WHERE business_id = ?",
            { businessId })
        newestAge = r and r.age or nil
    end)
    if newestAge == nil then return 0 end          -- never collected
    local rem = Config.CollectIntervalSec - tonumber(newestAge)
    return rem > 0 and rem or 0
end

-- Open/append an extortion case for a reported shakedown (gtarp_evidence v2
-- frozen exports only). Returns the case id or nil.
local function fileEvidence(cid, business, amount)
    if not Bridge.ResourceStarted('gtarp_evidence') then return nil end
    local caseId
    pcall(function()
        local incidentKey = ('%s%s-%d'):format(
            Config.Evidence.IncidentKeyPrefix, business.id, math.floor(now() / 300))
        caseId = exports.gtarp_evidence:EnsureCase(incidentKey, Config.Evidence.CaseTitle, 'gtarp_protection')
        if caseId then
            exports.gtarp_evidence:AppendEntry(caseId, 'extortion', {
                business = business.label, zone = business.zone, amount = amount,
            }, 'gtarp_protection')
            exports.gtarp_evidence:LinkSuspect(caseId, cid, nil)
        end
    end)
    return caseId
end

-- ---------------------------------------------------------------------------
-- /shakedown — collect protection at a business your gang's turf controls.
-- ---------------------------------------------------------------------------
local function cmdShakedown(src)
    if src == 0 then return end
    local t = now()
    -- Atomic check-and-set before any yield (rl() idiom).
    if (lastAction[src] or 0) + Config.CooldownSec > t then
        Bridge.Notify(src, 'Protection', 'Give it a second.', 'error')
        return
    end
    lastAction[src] = t

    local gang = Bridge.GetGang(src)
    if not gang then
        Bridge.Notify(src, 'Protection', "You're not in a crew.", 'error')
        return
    end
    local cid = Bridge.GetCitizenId(src)
    if not cid then return end

    local business = businessAt(src)
    if not business then
        Bridge.Notify(src, 'Protection', 'No business here to lean on.', 'error')
        return
    end

    local owner = Bridge.GetZoneOwner(business.zone)
    if owner ~= gang.name then
        Bridge.Notify(src, 'Protection', ("%s isn't your crew's block."):format(business.label), 'error')
        return
    end

    if collectLock[business.id] then
        Bridge.Notify(src, 'Protection', 'Someone from your crew is already working this place.', 'error')
        return
    end
    collectLock[business.id] = true

    local rem = cooldownRemaining(business.id)
    if rem > 0 then
        collectLock[business.id] = nil
        Bridge.Notify(src, 'Protection', ('%s already paid up — back in ~%dm.'):format(business.label, math.ceil(rem / 60)), 'error')
        return
    end

    local amount = math.random(Config.PayoutMin, Config.PayoutMax)
    if not Bridge.GiveItem(src, Config.Payout, amount) then
        collectLock[business.id] = nil
        Bridge.Notify(src, 'Protection', "Couldn't take the cash right now — try again.", 'error')
        return
    end

    local flagged = math.random() < Config.ReportChance
    local caseId
    if flagged then
        Bridge.PoliceAlert(src, 'Suspected extortion in progress')
        caseId = fileEvidence(cid, business, amount)
    end

    pcall(function()
        MySQL.insert.await(
            [[INSERT INTO gtarp_protection_collections
                (gang, business_id, zone_id, citizenid, amount, flagged, evidence_case_id)
              VALUES (?, ?, ?, ?, ?, ?, ?)]],
            { gang.name, business.id, business.zone, cid, amount, flagged and 1 or 0, caseId })
    end)

    collectLock[business.id] = nil
    Bridge.Notify(src, 'Protection',
        ('Shook down %s for $%d (dirty). Get it washed.'):format(business.label, amount), 'success')
    dbg(('%s (%s) shook %s for $%d, flagged=%s'):format(cid, gang.name, business.id, amount, tostring(flagged)))
end

-- ---------------------------------------------------------------------------
-- /rackets — read-only: businesses your crew controls + which are ready.
-- ---------------------------------------------------------------------------
local function cmdRackets(src)
    if src == 0 then return end
    local gang = Bridge.GetGang(src)
    if not gang then
        Bridge.Notify(src, 'Protection', "You're not in a crew.", 'error')
        return
    end
    local ready, cooling, held = 0, 0, 0
    for _, b in ipairs(Config.Businesses) do
        if Bridge.GetZoneOwner(b.zone) == gang.name then
            held = held + 1
            if cooldownRemaining(b.id) > 0 then cooling = cooling + 1 else ready = ready + 1 end
        end
    end
    if held == 0 then
        Bridge.Notify(src, 'Protection', "Your crew doesn't run any blocks with businesses right now.", 'inform')
        return
    end
    Bridge.Notify(src, 'Protection',
        ('%s controls %d business block(s): %d ready to collect, %d paid up.'):format(gang.label, held, ready, cooling), 'inform')
end

-- ---------------------------------------------------------------------------
-- Commands + boot
-- ---------------------------------------------------------------------------
Bridge.RegisterCommand('shakedown', function(source) cmdShakedown(source) end)
Bridge.RegisterCommand('rackets', function(source) cmdRackets(source) end)

AddEventHandler('onResourceStart', function(resource)
    if resource ~= GetCurrentResourceName() then return end
    if not Bridge.ItemExists(Config.Payout) then
        print(('^1[gtarp_protection] FATAL: payout item "%s" is not registered in ox_inventory — '
            .. 'protection racket disabled.^0'):format(Config.Payout))
        return
    end
    local turf = Bridge.ResourceStarted('gtarp_turf')
    local total, collected = 0, 0
    pcall(function()
        local r = MySQL.single.await(
            'SELECT COUNT(*) AS c, COALESCE(SUM(amount),0) AS s FROM gtarp_protection_collections')
        total = r and tonumber(r.c) or 0
        collected = r and tonumber(r.s) or 0
    end)
    print(('[gtarp_protection] racket open — %d business(es), %d shakedown(s) all-time ($%d); turf link %s'):format(
        #Config.Businesses, total, collected, turf and 'ONLINE' or 'OFFLINE (no owners → nothing collectable)'))
end)

--- Totals for devtest and future consumers.
exports('GetSummary', function()
    local out = { businesses = #Config.Businesses, shakedowns = 0, totalCollected = 0, flagged = 0 }
    pcall(function()
        local r = MySQL.single.await(
            'SELECT COUNT(*) AS c, COALESCE(SUM(amount),0) AS s, COALESCE(SUM(flagged),0) AS f FROM gtarp_protection_collections')
        if r then
            out.shakedowns = tonumber(r.c) or 0
            out.totalCollected = tonumber(r.s) or 0
            out.flagged = tonumber(r.f) or 0
        end
    end)
    return out
end)
