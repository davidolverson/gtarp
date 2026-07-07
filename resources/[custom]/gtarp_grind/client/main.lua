-- ============================================================================
-- gtarp_grind/client/main.lua
--
-- Pure logic: sell-point blips, spot/sell proximity prompts, and the gather
-- progress bar. All natives + ox_lib UI go through Game.* (bridge/cl_game.lua).
-- To port to GTA VI, rewrite the bridge, not this file. See docs/GTA6-READINESS.
-- ============================================================================

-- ---------------------------------------------------------------------------
-- sell-point blips
-- ---------------------------------------------------------------------------
CreateThread(function()
    local b = Config.SellBlip
    for _, act in pairs(Config.Activities) do
        if act.sell and act.sell.coords then
            Game.CreateBlip(act.sell.coords, b.sprite, b.colour, b.scale, act.sell.label)
        end
    end
end)

-- ---------------------------------------------------------------------------
-- nearest interactable: a gather spot or a sell point, whichever is closest
-- and within range. Returns a descriptor or nil.
-- ---------------------------------------------------------------------------
local function nearest()
    local me = Game.GetPlayerCoords()
    local best, bestD = nil, Config.InteractRadius
    for key, act in pairs(Config.Activities) do
        -- gather spots
        for i, spot in ipairs(act.spots) do
            local d = Game.DistanceBetween(me, spot)
            if d <= bestD then
                best = { kind = 'gather', key = key, spot = i, act = act }
                bestD = d
            end
        end
        -- sell point
        if act.sell and act.sell.coords then
            local d = Game.DistanceBetween(me, act.sell.coords)
            if d <= bestD then
                best = { kind = 'sell', key = key, act = act }
                bestD = d
            end
        end
    end
    return best
end

local function promptFor(n)
    if n.kind == 'gather' then
        return ('Press ~INPUT_PICKUP~ to %s'):format(n.act.label:lower())
    else
        return ('Press ~INPUT_PICKUP~ to sell to %s'):format(n.act.sell.label)
    end
end

local function act(n)
    if n.kind == 'gather' then
        if Game.ProgressBar(n.act.verb, (n.act.gather_seconds or 6) * 1000) then
            TriggerServerEvent('gtarp_grind:gather', n.key, n.spot)
        end
    else
        TriggerServerEvent('gtarp_grind:sell', n.key)
    end
end

CreateThread(function()
    while true do
        local wait = 800
        local n = nearest()
        if n then
            wait = 0
            Game.ShowHelpThisFrame(promptFor(n))
            if Game.InteractPressed() then act(n) end
        end
        Wait(wait)
    end
end)
