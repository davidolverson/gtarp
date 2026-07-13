-- ============================================================================
-- gtarp_market/bridge/cl_game.lua
--
-- Game adapter (client). The ONLY file in this resource that calls GTA natives
-- or ox_lib UI. client/main.lua calls Game.* only, so the exchange blip +
-- proximity-prompt logic ports to GTA VI by rewriting THIS FILE.
-- See docs/GTA6-READINESS.md (Section 3, the bridge pattern).
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

-- Create a map blip at a coord. Returns the handle.
function Game.CreateBlip(coords, sprite, colour, scale, label)
    local b = AddBlipForCoord(coords.x, coords.y, coords.z)
    SetBlipSprite(b, sprite or 1)
    SetBlipColour(b, colour or 0)
    SetBlipScale(b, scale or 0.8)
    SetBlipAsShortRange(b, true)
    BeginTextCommandSetBlipName('STRING')
    AddTextComponentString(label or 'Exchange')
    EndTextCommandSetBlipName(b)
    return b
end

-- Spawn a static, frozen, invincible attendant ped at a coord (the refinery
-- worker). Model may be a hash (backtick literal) or a name string. Returns the
-- ped handle, or nil if the model never loaded.
function Game.CreatePed(model, coords, heading)
    RequestModel(model)
    local tries = 0
    while not HasModelLoaded(model) and tries < 100 do
        tries = tries + 1
        Wait(10)
    end
    if not HasModelLoaded(model) then return nil end
    local ped = CreatePed(4, model, coords.x, coords.y, coords.z - 1.0, heading or 0.0, false, true)
    FreezeEntityPosition(ped, true)
    SetEntityInvincible(ped, true)
    SetBlockingOfNonTemporaryEvents(ped, true)
    SetModelAsNoLongerNeeded(model)
    return ped
end
