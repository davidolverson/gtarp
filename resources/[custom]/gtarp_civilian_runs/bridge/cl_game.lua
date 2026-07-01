-- ============================================================================
-- gtarp_civilian_runs/bridge/cl_game.lua
--
-- Game adapter (client). The ONLY file in this resource that calls GTA
-- natives or ox_lib UI. client/main.lua calls Game.* only, so the
-- run-selection / waypoint / arrival logic ports to GTA VI by rewriting
-- THIS FILE. See docs/GTA6-READINESS.md (Section 3, the bridge pattern).
-- ============================================================================

Game = {}

-- Local player position as {x,y,z}.
function Game.GetPlayerCoords()
    local p = GetEntityCoords(PlayerPedId())
    return { x = p.x, y = p.y, z = p.z }
end

-- Distance in metres between two coord tables (accepts vector3 too).
function Game.DistanceBetween(a, b)
    return #(vector3(a.x, a.y, a.z) - vector3(b.x, b.y, b.z))
end

-- Show a "press ~key~" help prompt for the current frame.
function Game.ShowHelpThisFrame(text)
    BeginTextCommandDisplayHelp('STRING')
    AddTextComponentSubstringPlayerName(text)
    EndTextCommandDisplayHelp(0, false, true, -1)
end

-- Was the interact key (E / INPUT_PICKUP) pressed this frame?
function Game.InteractPressed()
    return IsControlJustReleased(0, 38)
end

-- Open an ox_lib context menu of run choices. `options` is a list of
-- { title, description, runIndex }. Returns nothing — selecting an option
-- fires the given event with runIndex as an argument.
function Game.OpenRunMenu(jobName, options)
    local menuOptions = {}
    for _, o in ipairs(options) do
        menuOptions[#menuOptions + 1] = {
            title = o.title,
            description = o.description,
            disabled = o.disabled,
            event = 'gtarp_civilian_runs:clientStart',
            args = { jobName = jobName, runIndex = o.runIndex },
        }
    end
    lib.registerContext({ id = 'gtarp_civilian_runs_menu', title = 'Available Runs', options = menuOptions })
    lib.showContext('gtarp_civilian_runs_menu')
end

-- Create a route blip at `coords` with `label`. Returns the blip handle.
function Game.SetWaypointBlip(coords, label)
    local b = AddBlipForCoord(coords.x, coords.y, coords.z)
    SetBlipSprite(b, 1)
    SetBlipColour(b, 5)
    SetBlipScale(b, 0.9)
    SetBlipRoute(b, true)
    SetBlipRouteColour(b, 5)
    BeginTextCommandSetBlipName('STRING')
    AddTextComponentString(label or 'Destination')
    EndTextCommandSetBlipName(b)
    return b
end

-- Remove a blip created by SetWaypointBlip.
function Game.RemoveBlip(handle)
    if handle and DoesBlipExist(handle) then RemoveBlip(handle) end
end

-- Notify the local player.
function Game.Notify(opts)
    lib.notify(opts)
end

-- Fire `handler` once the local player's character has finished loading.
function Game.OnPlayerLoaded(handler)
    RegisterNetEvent('QBCore:Client:OnPlayerLoaded', handler)
end
