-- ============================================================================
-- gtarp_robbery/client/main.lua
--
-- Pure logic: register/ATM proximity prompts, the hold-up progress bar, and
-- rendering dispatch alerts (police only — the server decides who receives
-- them). All natives + ox_lib UI go through Game.* (bridge/cl_game.lua).
-- ============================================================================

-- Nearest robbable target (store register or ATM) within range, or nil.
local function nearest()
    local me = Game.GetPlayerCoords()
    local best, bestD = nil, Config.InteractRadius

    local function scan(kind, cfg)
        for i, loc in ipairs(cfg.locations) do
            local d = Game.DistanceBetween(me, loc.coords)
            if d <= bestD then
                best = { kind = kind, index = i, loc = loc }
                bestD = d
            end
        end
    end
    scan('store', Config.Stores)
    scan('atm', Config.ATMs)
    return best
end

local function tryRob(n)
    if Config.RequireWeapon and not Game.IsArmed() then
        Game.Notify({ title = 'Robbery', description = 'You need a weapon drawn for this.', type = 'error' })
        return
    end
    TriggerServerEvent('gtarp_robbery:start', n.kind, n.index)
end

RegisterNetEvent('gtarp_robbery:begin', function(data)
    local label = data.kind == 'store' and 'Emptying the register…' or 'Cracking the ATM…'
    if Game.ProgressBar(label, (data.hold or 8) * 1000) then
        TriggerServerEvent('gtarp_robbery:complete', data.kind, data.index)
    else
        TriggerServerEvent('gtarp_robbery:cancel')
    end
end)

RegisterNetEvent('gtarp_robbery:dispatch', function(d)
    Game.TempBlip(d.coords, d.sprite, d.colour, d.scale, d.label, (d.duration or 90) * 1000)
    Game.Notify({ title = '911 Dispatch', description = d.label, type = 'inform' })
end)

CreateThread(function()
    while true do
        local wait = 800
        local n = nearest()
        if n then
            wait = 0
            Game.ShowHelpThisFrame(n.kind == 'store'
                and 'Press ~INPUT_PICKUP~ to rob the register'
                or  'Press ~INPUT_PICKUP~ to rob the ATM')
            if Game.InteractPressed() then tryRob(n) end
        end
        Wait(wait)
    end
end)
