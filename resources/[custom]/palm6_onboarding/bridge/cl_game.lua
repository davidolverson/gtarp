-- ============================================================================
-- palm6_onboarding/bridge/cl_game.lua
--
-- Game + framework adapter (client). The ONLY file in this resource that
-- calls GTA natives, ox_lib UI, or knows the framework's loaded-event name.
-- client/main.lua calls Game.* only, so its logic ports to GTA VI by
-- rewriting THIS FILE. See docs/GTA6-READINESS.md (Section 3).
-- ============================================================================

Game = {}

-- Register a callback fired once the player's character is loaded and in
-- the world (same qbx_core event server_base/palm6_turf/server_identity
-- already wrap — see their bridge/cl_game.lua for the precedent).
function Game.OnPlayerLoaded(handler)
    RegisterNetEvent('QBCore:Client:OnPlayerLoaded', handler)
end

-- Blocking, no-cancel-button confirm dialog — the only way to close it is
-- to press the (single) confirm button. Returns once the player has done
-- so. Matches the mandatory-acknowledgement shape qbx_core itself uses for
-- its own confirm dialogs (character deletion), just with `cancel = false`
-- so there is no dismiss/decline path.
function Game.ShowMandatoryDialog(header, content)
    lib.alertDialog({
        header = header,
        content = content,
        centered = true,
        cancel = false,
    })
end

-- Notify the local player.
function Game.Notify(opts)
    lib.notify(opts)
end
