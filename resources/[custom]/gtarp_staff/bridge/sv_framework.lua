-- ============================================================================
-- gtarp_staff/bridge/sv_framework.lua
--
-- Framework + game adapter (server). The ONLY file in this resource that
-- touches player names, identifiers, peds, entity coords/health, the EMS
-- revive event, or ox_lib notifications.
--
-- Core logic (server/main.lua) calls Bridge.* only, so the command set,
-- the audit-log writes (our own table), and the Discord webhook stay
-- engine-agnostic. To port to GTA VI, rewrite THIS FILE against the new
-- identity API and the new entity natives.
--
-- See docs/GTA6-READINESS.md (Section 3, the bridge pattern).
-- ============================================================================

Bridge = {}

-- Display name for a server source.
function Bridge.GetPlayerName(src)
    return GetPlayerName(src)
end

-- The player's license identifier if present, else their first identifier,
-- else nil. Used to label audit-log rows.
function Bridge.GetLicense(src)
    local ids = GetPlayerIdentifiers(src) or {}
    for i = 1, #ids do
        if ids[i]:sub(1, 8) == 'license:' then return ids[i] end
    end
    return ids[1]
end

-- Notify an online player.
function Bridge.NotifyClient(src, title, msg, t)
    TriggerClientEvent('ox_lib:notify', src, {
        title = title, description = msg, type = t or 'inform',
    })
end

-- Current coords of a player's ped as {x,y,z}, or nil if no ped.
function Bridge.GetCoords(src)
    local ped = GetPlayerPed(src)
    if not ped or ped == 0 then return nil end
    local c = GetEntityCoords(ped)
    return { x = c.x, y = c.y, z = c.z }
end

-- Move a player's ped to (x,y,z). Returns true if the ped existed.
function Bridge.SetCoords(src, x, y, z)
    local ped = GetPlayerPed(src)
    if not ped or ped == 0 then return false end
    SetEntityCoords(ped, x, y, z, false, false, false, false)
    return true
end

-- Revive a player (EMS hospital flow).
function Bridge.Revive(target)
    TriggerClientEvent('hospital:client:Revive', target)
end

-- Full-heal a player's ped. Returns true if the ped existed.
function Bridge.Heal(target)
    local ped = GetPlayerPed(target)
    if ped and ped ~= 0 then
        SetEntityHealth(ped, 200)
        return true
    end
    return false
end
