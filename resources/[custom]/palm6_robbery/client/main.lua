-- ============================================================================
-- palm6_robbery/client/main.lua
--
-- Pure logic: ATM proximity prompts, the hold-up progress bar, and rendering
-- dispatch alerts (police only — the server decides who receives them). All
-- natives + ox_lib UI go through Game.* (bridge/cl_game.lua).
-- ============================================================================

-- Nearest robbable ATM within range, or nil.
local function nearest()
    local me = Game.GetPlayerCoords()
    local best, bestD = nil, Config.InteractRadius

    for i, loc in ipairs(Config.ATMs.locations) do
        local d = Game.DistanceBetween(me, loc.coords)
        if d <= bestD then
            best = { index = i, loc = loc }
            bestD = d
        end
    end
    return best
end

local function tryRob(n)
    if Config.RequireWeapon and not Game.IsArmed() then
        Game.Notify({ title = 'Robbery', description = 'You need a weapon drawn for this.', type = 'error' })
        return
    end
    TriggerServerEvent('palm6_robbery:start', n.index)
end

RegisterNetEvent('palm6_robbery:begin', function(data)
    if Game.ProgressBar('Cracking the ATM…', (data.hold or 8) * 1000) then
        TriggerServerEvent('palm6_robbery:complete', data.index)
    else
        TriggerServerEvent('palm6_robbery:cancel')
    end
end)

RegisterNetEvent('palm6_robbery:dispatch', function(d)
    Game.TempBlip(d.coords, d.sprite, d.colour, d.scale, d.label, (d.duration or 90) * 1000)
    Game.Notify({ title = '911 Dispatch', description = d.label, type = 'inform' })
end)

CreateThread(function()
    while true do
        local wait = 800
        local n = nearest()
        if n then
            wait = 0
            Game.ShowHelpThisFrame('Press ~INPUT_PICKUP~ to rob the ATM')
            if Game.InteractPressed() then tryRob(n) end
        end
        Wait(wait)
    end
end)
