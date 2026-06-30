-- ============================================================================
-- gtarp_courier/client/main.lua
--
-- Manages the on-route blip + arrival detection for an accepted delivery.
-- Pure logic: all GTA natives (blips, coords, waypoints, notify) go through
-- Game.* (bridge/cl_game.lua) so this file is engine-agnostic. To port to
-- GTA VI, rewrite the bridge, not this file. See docs/GTA6-READINESS.md.
--
-- Posting / listing is done via the server-side /courier command and the
-- gtarp_courier:post net event.
-- ============================================================================

local activeId = nil
local activeBlip = nil
local activeDropoff = nil

local function clearActive()
    Game.RemoveBlip(activeBlip)
    activeBlip, activeId, activeDropoff = nil, nil, nil
end

RegisterNetEvent('gtarp_courier:onAccepted', function(payload)
    clearActive()
    activeId = payload.id
    activeDropoff = payload.dropoff
    activeBlip = Game.CreateRouteBlip(payload.dropoff, payload.label, Config.DeliveryBlipColor or 5)

    Game.Notify({
        title = 'Courier',
        description = ('Delivery #%d accepted. Follow the GPS to the dropoff.'):format(payload.id),
        type = 'success',
    })
end)

CreateThread(function()
    while true do
        if activeId and activeDropoff then
            local d = Game.DistanceBetween(Game.GetPlayerCoords(), activeDropoff)
            if d <= (Config.DeliveryRadiusMeters or 8.0) then
                local id = activeId
                clearActive()
                TriggerServerEvent('gtarp_courier:complete', id)
            end
            Wait(1500)
        else
            Wait(2500)
        end
    end
end)

-- Simple chat helper to post a delivery from the player's current position
-- to a marked waypoint. Server-side validation handles bounds / escrow.
RegisterCommand('courierpost', function(_, args)
    local bounty = tonumber(args[1])
    if not bounty then
        Game.Notify({ title = 'Courier', description = 'Usage: /courierpost <bounty>', type = 'error' })
        return
    end

    local dropoff = Game.GetWaypointCoords()
    if not dropoff then
        Game.Notify({ title = 'Courier', description = 'Set a map waypoint for the dropoff first.', type = 'error' })
        return
    end
    local pickup = Game.GetPlayerCoords()
    TriggerServerEvent('gtarp_courier:post', {
        bounty = bounty,
        pickup = pickup,
        dropoff = dropoff,
        label = table.concat(args, ' ', 2):sub(1, 60),
    })
end, false)
