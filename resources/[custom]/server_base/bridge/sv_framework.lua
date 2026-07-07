-- ============================================================================
-- server_base/bridge/sv_framework.lua
--
-- Framework + game adapter (server). The ONLY file in this resource that
-- touches player identifiers, peds, entity coords/heading, or the chat
-- output event.
--
-- Core logic (server/main.lua) calls Bridge.* and nothing else, so the
-- startup banner, the connect logger, /serverinfo, and the /coords command
-- shell stay engine-agnostic. To port to GTA VI, rewrite THIS FILE against
-- the new identity API and the new entity natives.
--
-- See docs/GTA6-READINESS.md (Section 3, the bridge pattern).
-- ============================================================================

Bridge = {}

-- All identifiers for a server source as an index-iterable list.
function Bridge.GetIdentifiers(src)
    local list = GetPlayerIdentifiers(src) or {}
    local out = {}
    for i = 1, #list do out[i] = list[i] end
    return out
end

-- Current coords + heading of a player's ped as {x,y,z,w}, or nil if the
-- player has no ped. Used by /coords.
function Bridge.GetCoordsAndHeading(target)
    local ped = GetPlayerPed(target)
    if not ped or ped == 0 then return nil end
    local c = GetEntityCoords(ped)
    return { x = c.x, y = c.y, z = c.z, w = GetEntityHeading(ped) }
end

-- Print a chat line to a single player.
function Bridge.ChatToPlayer(src, author, msg)
    TriggerClientEvent('chat:addMessage', src, {
        args = { author, msg },
    })
end
