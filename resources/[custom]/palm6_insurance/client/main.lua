-- ============================================================================
-- palm6_insurance/client/main.lua
--
-- Pure logic. Calls Game.* (bridge/cl_game.lua) for all native access.
-- No direct natives / ox_lib here (§6 gate).
--
-- Client is presentation-only: the office blip. Both commands are entirely
-- server-side — there is nothing here for a modified client to abuse.
-- ============================================================================

CreateThread(function()
    Game.AddBlip(Config.Office.coords, Config.Office.blip)
end)
