-- ============================================================================
-- gtarp_robbery/bridge/cl_game.lua
--
-- Game adapter (client). The ONLY file in this resource that calls GTA
-- natives or ox_lib UI. client/main.lua calls Game.* only, so the proximity /
-- hold-up / dispatch logic ports to GTA VI by rewriting THIS FILE.
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

-- Is the local player currently holding any weapon (not unarmed)?
function Game.IsArmed()
    return IsPedArmed(PlayerPedId(), 7)  -- flag 7 = melee | gun | thrown
end

-- Run a cancellable progress bar for `ms`. Returns true if completed. Moving
-- away or dying cancels it (the hold-up is broken).
function Game.ProgressBar(label, ms)
    return lib.progressBar({
        duration = ms,
        label = label,
        canCancel = true,
        disable = { move = true, car = true, combat = true },
    })
end

-- Create a temporary dispatch blip that pulses a route for `durationMs`, then
-- removes itself. Used by police clients receiving a robbery alert.
function Game.TempBlip(coords, sprite, colour, scale, label, durationMs)
    local b = AddBlipForCoord(coords.x, coords.y, coords.z)
    SetBlipSprite(b, sprite or 161)
    SetBlipColour(b, colour or 1)
    SetBlipScale(b, scale or 1.2)
    SetBlipAsShortRange(b, false)
    SetBlipRoute(b, true)
    BeginTextCommandSetBlipName('STRING')
    AddTextComponentString(label or 'Dispatch')
    EndTextCommandSetBlipName(b)
    SetTimeout(durationMs or 90000, function()
        if DoesBlipExist(b) then RemoveBlip(b) end
    end)
end

-- Notify the local player.
function Game.Notify(opts)
    lib.notify(opts)
end
