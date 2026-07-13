-- ============================================================================
-- gtarp_turf/client/main.lua
--
-- Pure logic. Calls Game.* (bridge/cl_game.lua) for all native access.
-- No direct natives / ox_lib here (§6 gate). Server is authoritative on the
-- gang gate, proximity, and ownership flip — this is UI + prompts + blips.
-- ============================================================================

local zones = {}
local blips = {}

local function requestSync()
    TriggerServerEvent('gtarp_turf:requestSync')
end

local function refreshBlips()
    for _, b in pairs(blips) do Game.RemoveBlip(b) end
    blips = {}
    for id, z in pairs(zones) do
        local colour = z.owner_gang and Config.ClaimedColour or Config.UnclaimedColour
        local label = z.owner_gang and ('%s (%s)'):format(z.label, z.owner_gang) or ('%s (unclaimed)'):format(z.label)
        blips[id] = Game.SetZoneBlip(z.coords, label, colour, Config.BlipSprite, Config.BlipScale)
    end
end

-- Request the sync a beat after load. Firing it during the join/connect race
-- (the instant OnPlayerLoaded fires, or immediately on client resource start)
-- reaches the server before the client is marked net-safe, so the server drops
-- it as "gtarp_turf:requestSync was not safe for net" and the blips do not sync.
-- The short wait lets the session settle. Covers both a fresh join (OnPlayerLoaded)
-- and a resource restart while already in-game (the standalone thread).
local function requestSyncSoon()
    CreateThread(function()
        Wait(2000)
        requestSync()
    end)
end

Game.OnPlayerLoaded(requestSyncSoon)
requestSyncSoon()  -- covers resource restarts while already in-game

RegisterNetEvent('gtarp_turf:syncZones', function(data)
    zones = data or {}
    refreshBlips()
end)

CreateThread(function()
    while true do
        local wait = 750
        local coords = Game.GetPlayerCoords()
        for id, z in pairs(zones) do
            if Game.DistanceBetween(coords, z.coords) <= Config.InteractRadius then
                wait = 0
                Game.ShowHelpThisFrame(('Press ~INPUT_PICKUP~ to tag %s for your gang'):format(z.label))
                if Game.InteractPressed() then
                    TriggerServerEvent('gtarp_turf:requestTag', id)
                end
            end
        end
        Wait(wait)
    end
end)

RegisterNetEvent('gtarp_turf:begin', function(payload)
    local ok = Game.ProgressBar('Tagging ' .. payload.label .. '...', Config.TagProgressMs)
    if ok then
        TriggerServerEvent('gtarp_turf:complete', payload.zoneId)
    else
        TriggerServerEvent('gtarp_turf:cancel', payload.zoneId)
    end
end)

RegisterNetEvent('gtarp_turf:showLog', function(content)
    Game.ShowLogDialog('Turf Standings', content)
end)
