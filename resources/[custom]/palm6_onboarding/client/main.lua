-- ============================================================================
-- palm6_onboarding/client/main.lua
--
-- Pure logic. Calls Game.* (bridge/cl_game.lua) for all native access.
-- No direct natives / ox_lib here (§6 gate).
--
-- The server is authoritative on "has this citizen ever accepted the
-- rules" — this file never decides that itself, it just reports the load
-- and reacts to whatever the server tells it to show.
-- ============================================================================

-- The mandatory rules prompt is driven server-side by Bridge.OnPlayerLoaded, so
-- this client call is only the belt-and-suspenders restart path. Fire it a beat
-- after load: during the join/connect race the server drops it as
-- "palm6_onboarding:checkStatus was not safe for net". The wait lets the session
-- settle; the fresh-join prompt is unaffected (it comes from the server hook).
Game.OnPlayerLoaded(function()
    CreateThread(function()
        Wait(2000)
        TriggerServerEvent('palm6_onboarding:checkStatus')
    end)
end)

-- Server decided this citizen has never accepted the rules. No decline
-- path (Game.ShowMandatoryDialog has no cancel button) — the player must
-- acknowledge before this call returns, then we report it back.
RegisterNetEvent('palm6_onboarding:promptRules', function()
    Game.ShowMandatoryDialog(Config.Rules.header, Config.Rules.content)
    TriggerServerEvent('palm6_onboarding:acceptRules')
end)

-- Server confirmed the accept landed (first time only) — show the tour.
RegisterNetEvent('palm6_onboarding:showTour', function()
    Game.ShowMandatoryDialog(Config.Tour.header, Config.Tour.content)
end)

-- /rules — read-only, any time after onboarding, no accept round-trip.
RegisterNetEvent('palm6_onboarding:showRulesReadOnly', function()
    Game.ShowMandatoryDialog(Config.Rules.header, Config.Rules.content)
end)
