-- ============================================================================
-- palm6_yard/bridge/sv_framework.lua
--
-- Framework adapter (server). The ONLY file in this resource that calls
-- qbx_core / ox_inventory / xt-prison / palm6_mdt exports, the jailTime
-- statebag, or server-side game natives. server/main.lua holds the labor /
-- commissary / bail LOGIC (and its own portable palm6_yard_* SQL) and calls
-- Bridge.* only, so a port to GTA VI is a rewrite of THIS FILE. See
-- docs/GTA6-READINESS.md §3 (the bridge pattern).
--
-- Item / cash / coords / warrant helpers are the exact shapes used by
-- palm6_market / palm6_loanshark / palm6_drugs.
-- ============================================================================

Bridge = {}

local function getPlayer(src)
    local ok, p = pcall(function() return exports.qbx_core:GetPlayer(src) end)
    return ok and p or nil
end

-- ---------------------------------------------------------------------------
-- Identity
-- ---------------------------------------------------------------------------

-- Stable per-character id, or nil.
function Bridge.GetCitizenId(src)
    local p = getPlayer(src)
    return p and p.PlayerData and p.PlayerData.citizenid or nil
end

-- ---------------------------------------------------------------------------
-- Cash / bank. qbx RemoveMoney returns false (and removes nothing) when the
-- account can't cover it, so it doubles as the funds check — no read-then-remove
-- race. Every path is pcall-wrapped so a framework throw can't unwind the caller
-- and leak an in-flight lock / half-applied payment.
-- ---------------------------------------------------------------------------

-- Take `amount` from an account ('cash'|'bank'). Returns true only if applied.
function Bridge.RemoveMoney(src, account, amount, reason)
    local p = getPlayer(src)
    if not p or not p.Functions then return false end
    local ok, res = pcall(function() return p.Functions.RemoveMoney(account, amount, reason) end)
    return ok and res == true
end

-- Give `amount` to an account. Used for labor pay and refund ladders.
function Bridge.AddMoney(src, account, amount, reason)
    local p = getPlayer(src)
    if not p or not p.Functions then return false end
    local ok = pcall(function() p.Functions.AddMoney(account, amount, reason) end)
    return ok and true or false
end

-- ---------------------------------------------------------------------------
-- Inventory
-- ---------------------------------------------------------------------------

-- Presence check: can ox_inventory resolve this item name? Boot self-disable.
function Bridge.ItemExists(name)
    local ok, item = pcall(function() return exports.ox_inventory:Items(name) end)
    return ok and item ~= nil
end

-- Can the player carry `count` of `name` right now (weight + slots)?
function Bridge.CanCarry(src, name, count)
    local ok, can = pcall(function()
        return exports.ox_inventory:CanCarryItem(src, name, count or 1)
    end)
    return ok and can and true or false
end

-- Add `count` of `item`. Returns true only if ox reports it fit — the logic
-- layer credits nothing it did not actually grant.
function Bridge.AddItem(src, item, count)
    local ok, added = pcall(function()
        return exports.ox_inventory:AddItem(src, item, count or 1)
    end)
    return ok and added and true or false
end

-- ---------------------------------------------------------------------------
-- Jail (xt-prison, Qbox path). jailTime lives on the player statebag in MINUTES;
-- persistence rides on qbx player metadata `injail` (xt-prison's qbx bridge sets
-- both statebag + SetMetaData('injail', time) inside SetJailTime, and qbx_core
-- saves metadata), NOT a standalone table. Verified in xt-prison/bridge/server/
-- qbx.lua setJailTime(). So SetJailMinutes() below already persists the shave.
-- ---------------------------------------------------------------------------

-- Remaining sentence in MINUTES for a jailed player (0 if free). Server truth:
-- the statebag is server-readable even though xt-prison decrements it client-
-- side, and qbx restores it from `injail` metadata on relog.
function Bridge.GetJailMinutes(src)
    local st = Player(src) and Player(src).state or nil
    local m = st and st.jailTime or 0
    m = tonumber(m) or 0
    if m < 0 then return 0 end
    return math.floor(m)
end

-- Set the remaining sentence (minutes) via xt-prison's export. It updates the
-- statebag + the 'injail' metadata and blocks until the statebag reflects the
-- new value, so on return the change is live. Returns true on success.
function Bridge.SetJailMinutes(src, minutes)
    minutes = math.floor(tonumber(minutes) or 0)
    if minutes < 0 then minutes = 0 end
    local ok, res = pcall(function() return exports['xt-prison']:SetJailTime(src, minutes) end)
    return ok and res ~= false
end

-- Persistence hook — intentionally a NO-OP on the Qbox path. SetJailMinutes()
-- (above) calls xt-prison's SetJailTime, which sets SetMetaData('injail', time);
-- qbx_core persists player metadata and restores jail from `injail` on relog, so
-- the SHAVED value is already durable the moment SetJailMinutes returns. There is
-- NO standalone xt_prison table in the Qbox bridge to write (verified in
-- xt-prison/bridge/server/qbx.lua) — writing one would be a silent failing query.
-- Kept as a named seam so the labor/bail handlers read intentionally and a future
-- non-Qbox framework can add its own persistence here without touching logic.
function Bridge.PersistJailMinutes(citizenid, minutes)
    return true
end

-- Return the player's confiscated inventory on release (bail). xt-prison's
-- returnItems handler BANS if jailTime > 0, so callers MUST SetJailMinutes(0)
-- first. Fired as the resource's own net event so it runs with the player's
-- source; called synchronously from within the postBail net handler where the
-- ambient source is still that player.
function Bridge.ReturnPrisonItems(src)
    pcall(function() TriggerEvent('xt-prison:server:returnItems') end)
end

-- ---------------------------------------------------------------------------
-- Warrants (palm6_mdt). Soft cross-calls — nil / false if mdt is absent, never
-- throws. IssueWarrant returns a warrant id, or nil if the citizen is already
-- wanted (idempotent) or the reason is out of bounds.
-- ---------------------------------------------------------------------------
function Bridge.IssueWarrant(citizenid, reason, officerLabel)
    if GetResourceState('palm6_mdt') ~= 'started' then return nil end
    local ok, id = pcall(function()
        return exports.palm6_mdt:IssueWarrant(citizenid, reason, officerLabel)
    end)
    return (ok and id) or nil
end

-- ---------------------------------------------------------------------------
-- Presence / world / notify
-- ---------------------------------------------------------------------------

-- Caller's ped position as {x,y,z}, or nil. Server-side anti-abuse proximity.
function Bridge.GetCoords(src)
    local ped = GetPlayerPed(src)
    if not ped or ped == 0 then return nil end
    local c = GetEntityCoords(ped)
    return { x = c.x, y = c.y, z = c.z }
end

-- Distance in metres between two coord tables (accepts vector3 too).
function Bridge.Distance(a, b)
    return #(vector3(a.x, a.y, a.z) - vector3(b.x, b.y, b.z))
end

-- Notify a player (src 0 = server console).
function Bridge.Notify(src, title, msg, t)
    if src == 0 then
        print(('[palm6_yard] %s: %s'):format(title, msg))
        return
    end
    TriggerClientEvent('ox_lib:notify', src, {
        title = title, description = msg, type = t or 'inform',
    })
end

-- Is a resource started? Boot gate for the xt-prison dependency.
function Bridge.ResourceStarted(name)
    return GetResourceState(name) == 'started'
end
