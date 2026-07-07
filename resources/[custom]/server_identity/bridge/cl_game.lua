-- ============================================================================
-- server_identity/bridge/cl_game.lua
--
-- Framework + game adapter (client). The ONLY file in this resource that
-- calls Discord-presence natives, the ped/coords/fade/collision spawn
-- natives, the loading-screen shutdown natives, or knows the framework's
-- player-loaded / logged-out event names.
--
-- Core logic (client/main.lua) calls Game.* and nothing else, so the
-- presence-refresh cadence, the one-shot spawn guard, and the spawn-point
-- decision stay engine-agnostic. To port to GTA VI, rewrite THIS FILE
-- against the new natives and the new framework events. NOTE: the spawn
-- coordinates themselves are Tier 3 (live in shared config, re-authored for
-- the new map) — only the placement mechanism lives here.
--
-- See docs/GTA6-READINESS.md (Section 3, the bridge pattern).
-- ============================================================================

Game = {}

-- Apply Discord rich presence (app id + presence line). The decision of
-- whether/when to apply (and what text) stays in the logic.
function Game.ApplyDiscordPresence(appId, presenceText)
    SetDiscordAppId(appId)
    SetRichPresence(presenceText)
end

-- Reposition the already-spawned character to a {x,y,z,w} point behind a
-- screen fade, wait for collision to load, then fade back in and tear down
-- the loading screen. Faithful extraction of the original spawn sequence:
-- qbx_core owns selection + the initial spawn; this only moves the chosen
-- character to the server's canonical spawn point.
function Game.PlaceAtSpawn(point)
    local ped = PlayerPedId()
    if not ped or ped == 0 then return end

    DoScreenFadeOut(250)
    -- Wait(0) yield: blocking until the engine reports the fade is complete.
    while not IsScreenFadedOut() do Wait(0) end

    SetEntityCoords(ped, point.x, point.y, point.z, false, false, false, false)
    SetEntityHeading(ped, point.w)
    FreezeEntityPosition(ped, true)

    local tries = 0
    while not HasCollisionLoadedAroundEntity(ped) and tries < 200 do
        Wait(50)
        tries = tries + 1
    end

    FreezeEntityPosition(ped, false)
    DoScreenFadeIn(500)

    -- server_identity owns the loading screen; tear it down once the selected
    -- character is actually in the world. Idempotent with the manifest's
    -- auto-shutdown.
    ShutdownLoadingScreen()
    ShutdownLoadingScreenNui()
end

-- Register a callback fired once the player's character is loaded and in the
-- world. Hides the framework's loaded-event name.
--
-- The framework — not this resource — owns character selection and the
-- initial spawn. Verified against
-- github.com/Qbox-project/qbx_core/blob/main/client/character.lua:
--   1. Once the session starts, qbx_core calls
--      exports.spawnmanager:setAutoSpawn(false) so the engine does NOT auto-
--      spawn a ped, then runs chooseCharacter(), which presents the multichar
--      UI via lib.showContext('qbx_core_multichar_characters').
--   2. When the player actively picks a slot, qbx_core loads that character
--      (qbx_core:server:loadCharacter) and spawns the ped, and only THEN
--      fires QBCore:Client:OnPlayerLoaded.
function Game.OnPlayerLoaded(handler)
    RegisterNetEvent('QBCore:Client:OnPlayerLoaded', handler)
end

-- Register a callback fired when the player logs out to character select.
-- Hides the framework's logout-event name (verified in qbx_core
-- client/character.lua: 'qbx_core:client:playerLoggedOut').
function Game.OnPlayerLoggedOut(handler)
    AddEventHandler('qbx_core:client:playerLoggedOut', handler)
end
