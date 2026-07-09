-- ============================================================================
-- gtarp_onboarding/client/main.lua
--
-- Pure logic. Calls Game.* (bridge/cl_game.lua) for all native access.
-- No direct natives / ox_lib here (§6 gate).
--
-- The server is authoritative on "has this citizen ever accepted the
-- rules" — this file never decides that itself, it just reports the load
-- and reacts to whatever the server tells it to show.
-- ============================================================================

Game.OnPlayerLoaded(function()
    TriggerServerEvent('gtarp_onboarding:checkStatus')
end)

-- Server decided this citizen has never accepted the rules. No decline
-- path (Game.ShowMandatoryDialog has no cancel button) — the player must
-- acknowledge before this call returns, then we report it back.
RegisterNetEvent('gtarp_onboarding:promptRules', function()
    Game.ShowMandatoryDialog(Config.Rules.header, Config.Rules.content)
    TriggerServerEvent('gtarp_onboarding:acceptRules')
end)

-- Server confirmed the accept landed (first time only) — show the tour.
RegisterNetEvent('gtarp_onboarding:showTour', function()
    Game.ShowMandatoryDialog(Config.Tour.header, Config.Tour.content)
end)

-- /rules — read-only, any time after onboarding, no accept round-trip.
RegisterNetEvent('gtarp_onboarding:showRulesReadOnly', function()
    Game.ShowMandatoryDialog(Config.Rules.header, Config.Rules.content)
end)
