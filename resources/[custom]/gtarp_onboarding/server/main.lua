-- ============================================================================
-- gtarp_onboarding/server/main.lua
--
-- Pure logic. Calls Bridge.* (bridge/sv_framework.lua) for all framework /
-- native access. No direct framework / native calls here (§6 gate).
--
-- First-ever character load: prompt the mandatory rules dialog, record
-- server-side acceptance, grant a one-time starter cash amount, log to
-- gtarp_staff, then show a short tour. Every later load is a no-op (the
-- `gtarp_onboarding` row already exists) except /rules, which just
-- re-displays the text — it never re-triggers the accept flow.
--
-- Client-trust note: `gtarp_onboarding:acceptRules` is a client-addressable
-- net event. It is NOT trusted as proof the dialog was actually shown or
-- accepted — the guard that matters is server-side: UNIQUE(citizenid) on
-- gtarp_onboarding means the starter-cash grant can only ever land once
-- per citizen no matter how many times (or how fast) the event fires,
-- replayed or otherwise. Same idiom as every other guarded-write feature
-- this session (gtarp_ransom's payout guard, gtarp_pumpcoin's mint-ticker
-- fix, gtarp_courier's escrow guard).
-- ============================================================================

local lastAccept = {} -- [src] = ts — accept-event rate limit

local function now() return os.time() end

local function alreadyOnboarded(citizenid)
    local row
    pcall(function()
        row = MySQL.single.await(
            'SELECT id FROM gtarp_onboarding WHERE citizenid = ?', { citizenid })
    end)
    return row ~= nil
end

-- ---------------------------------------------------------------------------
-- First load (or reconnect) — server decides whether the mandatory prompt
-- is owed. Nothing here is client-trusted: the DB row is the source of truth.
-- ---------------------------------------------------------------------------
Bridge.OnPlayerLoaded(function(src)
    local cid = Bridge.GetCitizenId(src)
    if not cid then return end
    if alreadyOnboarded(cid) then return end
    TriggerClientEvent('gtarp_onboarding:promptRules', src)
end)

-- Client also explicitly asks on load (belt-and-suspenders — if the client
-- resource restarted after the player was already in the world, the
-- Bridge.OnPlayerLoaded event won't refire, but this will).
RegisterNetEvent('gtarp_onboarding:checkStatus', function()
    local src = source
    local cid = Bridge.GetCitizenId(src)
    if not cid then return end
    if alreadyOnboarded(cid) then return end
    TriggerClientEvent('gtarp_onboarding:promptRules', src)
end)

-- ---------------------------------------------------------------------------
-- Accept — guarded INSERT is the entire safety story here (see header).
-- ---------------------------------------------------------------------------
RegisterNetEvent('gtarp_onboarding:acceptRules', function()
    local src = source
    local cid = Bridge.GetCitizenId(src)
    if not cid then return end

    local t = now()
    if (lastAccept[src] or 0) + Config.AcceptCooldownSec > t then return end
    lastAccept[src] = t

    local inserted = pcall(function()
        MySQL.insert.await(
            'INSERT INTO gtarp_onboarding (citizenid) VALUES (?)', { cid })
    end)
    if not inserted then
        -- UNIQUE(citizenid) rejected it — already onboarded (a race, or a
        -- replayed event from a modified client). Nothing left to grant.
        return
    end

    if Config.StarterCash.enabled then
        Bridge.CreditBank(src, Config.StarterCash.amount, Config.StarterCash.reason)
        pcall(function()
            MySQL.update.await(
                'UPDATE gtarp_onboarding SET starter_cash_granted = 1 WHERE citizenid = ?',
                { cid })
        end)
    end

    if Bridge.ResourceStarted('gtarp_staff') then
        pcall(function()
            exports.gtarp_staff:Log('onboarding_rules_accepted', src, nil, cid)
        end)
    end

    TriggerClientEvent('gtarp_onboarding:showTour', src)
end)

-- ---------------------------------------------------------------------------
-- /rules — read-only, any time, does not touch the DB or re-trigger accept.
-- ---------------------------------------------------------------------------
Bridge.RegisterCommand('rules', function(source)
    if source == 0 then return end
    TriggerClientEvent('gtarp_onboarding:showRulesReadOnly', source)
end)

AddEventHandler('onResourceStart', function(resource)
    if resource ~= GetCurrentResourceName() then return end
    local total = 0
    pcall(function()
        local r = MySQL.single.await('SELECT COUNT(*) AS n FROM gtarp_onboarding')
        total = r and tonumber(r.n) or 0
    end)
    print(('[gtarp_onboarding] online — %d citizen(s) onboarded all-time'):format(total))
end)

---Onboarded-citizen count for devtest and future consumers.
exports('GetSummary', function()
    local out = { totalAccepted = 0 }
    pcall(function()
        local r = MySQL.single.await('SELECT COUNT(*) AS n FROM gtarp_onboarding')
        out.totalAccepted = r and tonumber(r.n) or 0
    end)
    return out
end)
