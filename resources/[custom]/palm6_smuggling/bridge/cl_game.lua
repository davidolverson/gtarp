-- ============================================================================
-- palm6_smuggling/bridge/cl_game.lua
--
-- Game adapter (client). The ONLY file in this resource that calls GTA
-- natives / ox_lib UI. client/main.lua calls Game.* only, so it ports to
-- GTA VI by rewriting THIS FILE. Mirrors the fallback-dispatch adapter used
-- by palm6_drugs / palm6_robbery. See docs/GTA6-READINESS.md (Section 3).
-- ============================================================================

Game = {}

-- Short-range flashing dispatch blip, auto-removed after `durationSec`.
function Game.ShowDispatchBlip(coords, label, durationSec)
    local b = AddBlipForCoord(coords.x, coords.y, coords.z)
    SetBlipSprite(b, 51)
    SetBlipColour(b, 1)
    SetBlipScale(b, 1.0)
    SetBlipFlashes(b, true)
    SetBlipAsShortRange(b, false)
    BeginTextCommandSetBlipName('STRING')
    AddTextComponentSubstringPlayerName(label or 'Dispatch')
    EndTextCommandSetBlipName(b)
    SetTimeout(math.max(10, durationSec or 60) * 1000, function()
        if DoesBlipExist(b) then RemoveBlip(b) end
    end)
end

function Game.Notify(opts)
    lib.notify(opts)
end
