-- ============================================================================
-- palm6_market/client/main.lua
--
-- Pure logic: the exchange + refinery blips and their proximity "press E"
-- prompts (sell raws / refine raws).
-- All natives / ox_lib UI go through Game.* (bridge/cl_game.lua). To port to
-- GTA VI, rewrite the bridge, not this file. See docs/GTA6-READINESS.
--
-- One E-press at the counter fires palm6_market:sell; the SERVER decides what
-- the player holds, prices it live, and pays — the client sends no amounts,
-- items or prices (nothing here is trusted). /market (the price board) is a
-- server command, so it needs no client code.
-- ============================================================================

CreateThread(function()
    local e = Config.Exchange
    Game.CreateBlip(e.coords, e.blip.sprite, e.blip.colour, e.blip.scale, e.label)
end)

CreateThread(function()
    local e = Config.Exchange
    while true do
        local wait = 800
        local me = Game.GetPlayerCoords()
        if Game.DistanceBetween(me, e.coords) <= Config.InteractRadius then
            wait = 0
            Game.ShowHelpThisFrame('Press ~INPUT_PICKUP~ to sell raw goods at the ' .. e.label)
            if Game.InteractPressed() then
                TriggerServerEvent('palm6_market:sell')
            end
        end
        Wait(wait)
    end
end)

-- ---------------------------------------------------------------------------
-- The refinery (v2): a blip, an optional worker ped, and the "press E to
-- refine" proximity prompt. Same discipline as the exchange threads — the
-- client sends NO args; the server decides what raws convert and grants the
-- refined goods (nothing here is trusted).
-- ---------------------------------------------------------------------------
CreateThread(function()
    local r = Config.RefineStation
    Game.CreateBlip(r.coords, r.blip.sprite, r.blip.colour, r.blip.scale, r.label)
    if r.ped then
        Game.CreatePed(r.ped.model, r.coords, r.ped.heading)
    end
end)

CreateThread(function()
    local r = Config.RefineStation
    while true do
        local wait = 800
        local me = Game.GetPlayerCoords()
        if Game.DistanceBetween(me, r.coords) <= Config.InteractRadius then
            wait = 0
            Game.ShowHelpThisFrame('Press ~INPUT_PICKUP~ to refine raw goods at the ' .. r.label)
            if Game.InteractPressed() then
                TriggerServerEvent('palm6_market:refine')
            end
        end
        Wait(wait)
    end
end)
