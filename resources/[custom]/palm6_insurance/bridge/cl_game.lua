-- ============================================================================
-- palm6_insurance/bridge/cl_game.lua
--
-- Game adapter (client). The ONLY file in this resource that calls GTA
-- natives. client/main.lua calls Game.* only, so its logic ports to GTA VI
-- by rewriting THIS FILE.
-- See docs/GTA6-READINESS.md (Section 3, the bridge pattern).
-- ============================================================================

Game = {}

-- Permanent map blip.
function Game.AddBlip(coords, opts)
    local blip = AddBlipForCoord(coords.x, coords.y, coords.z)
    SetBlipSprite(blip, opts.sprite)
    SetBlipColour(blip, opts.color)
    SetBlipScale(blip, opts.scale)
    SetBlipAsShortRange(blip, true)
    BeginTextCommandSetBlipName('STRING')
    AddTextComponentSubstringPlayerName(opts.label)
    EndTextCommandSetBlipName(blip)
    return blip
end
