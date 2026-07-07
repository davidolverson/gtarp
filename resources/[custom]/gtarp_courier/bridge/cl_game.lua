-- ============================================================================
-- gtarp_courier/bridge/cl_game.lua
--
-- Game adapter (client). The ONLY file in this resource that calls GTA V
-- natives (blips, coords, peds, waypoints) or ox_lib notify.
--
-- Core logic (client/main.lua) calls Game.* and nothing else. To port this
-- resource to GTA VI, rewrite THIS FILE against the new natives. The
-- arrival detection, the post helper, and the accept handler are untouched.
--
-- See docs/GTA6-READINESS.md (Section 3, the bridge pattern).
-- ============================================================================

Game = {}

-- Player position as a plain {x,y,z} table.
function Game.GetPlayerCoords()
    local p = GetEntityCoords(PlayerPedId())
    return { x = p.x, y = p.y, z = p.z }
end

-- The player's current map waypoint as {x,y,z}, or nil if none is set.
function Game.GetWaypointCoords()
    local wp = GetFirstBlipInfoId(8)
    if not DoesBlipExist(wp) then return nil end
    local d = GetBlipInfoIdCoord(wp)
    return { x = d.x, y = d.y, z = d.z }
end

-- Distance in metres between two {x,y,z} tables.
function Game.DistanceBetween(a, b)
    return #(vector3(a.x, a.y, a.z) - vector3(b.x, b.y, b.z))
end

-- Create a routed destination blip at {x,y,z}. Returns the blip handle.
function Game.CreateRouteBlip(coords, label, colour)
    local b = AddBlipForCoord(coords.x, coords.y, coords.z)
    SetBlipSprite(b, 1)
    SetBlipColour(b, colour or 5)
    SetBlipScale(b, 0.9)
    SetBlipAsShortRange(b, false)
    SetBlipRoute(b, true)
    BeginTextCommandSetBlipName('STRING')
    AddTextComponentString('Delivery: ' .. tostring(label or 'Package'))
    EndTextCommandSetBlipName(b)
    return b
end

-- Remove a blip handle if it exists.
function Game.RemoveBlip(handle)
    if handle then RemoveBlip(handle) end
end

-- Notify the local player.
function Game.Notify(opts)
    lib.notify(opts)
end
