-- ============================================================================
-- server_base/bridge/cl_game.lua
--
-- Framework + game adapter (client). The ONLY file in this resource that
-- knows the framework's player-loaded event name or calls ox_lib notify.
--
-- Core logic (client/main.lua) calls Game.* and nothing else. To port to
-- GTA VI, rewrite THIS FILE against the new framework's loaded event and the
-- new notification API. The welcome decision stays in the logic.
--
-- See docs/GTA6-READINESS.md (Section 3, the bridge pattern).
-- ============================================================================

Game = {}

-- Register a callback fired once the player's character is loaded and in the
-- world. Hides the framework's loaded-event name.
--
-- qbx_core fires QBCore:Client:OnPlayerLoaded only AFTER the player has
-- actively selected a character in the multichar UI and that character has
-- spawned (verified in qbx_core client/character.lua), so the welcome shown
-- by the logic never fires before selection completes.
function Game.OnPlayerLoaded(handler)
    RegisterNetEvent('QBCore:Client:OnPlayerLoaded', handler)
end

-- Notify the local player.
function Game.Notify(opts)
    lib.notify(opts)
end
