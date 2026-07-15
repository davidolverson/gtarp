-- ============================================================================
-- palm6_courier/client/main.lua
--
-- Manages the on-route blip + arrival detection for an accepted delivery.
-- Pure logic: all GTA natives (blips, coords, waypoints, notify) go through
-- Game.* (bridge/cl_game.lua) so this file is engine-agnostic. To port to
-- GTA VI, rewrite the bridge, not this file. See docs/GTA6-READINESS.md.
--
-- Posting / listing is done via the server-side /courier command and the
-- palm6_courier:post net event.
-- ============================================================================

local activeId = nil
local activeBlip = nil
local activePickup = nil
local activeDropoff = nil
local phase = nil          -- 'pickup' | 'dropoff'

local function clearActive()
    Game.RemoveBlip(activeBlip)
    activeBlip, activeId, activePickup, activeDropoff, phase = nil, nil, nil, nil, nil
end

RegisterNetEvent('palm6_courier:onAccepted', function(payload)
    clearActive()
    activeId = payload.id
    activePickup = payload.pickup
    activeDropoff = payload.dropoff
    -- Route to the PICKUP first; the dropoff blip appears after the server
    -- confirms the package was collected (palm6_courier:onPickedUp).
    if activePickup then
        phase = 'pickup'
        activeBlip = Game.CreateRouteBlip(activePickup, (payload.label or 'Package') .. ' (pickup)',
            Config.PickupBlipColor or 3)
        Game.Notify({ title = 'Courier',
            description = ('Delivery #%d accepted. Collect the package at the pickup.'):format(payload.id),
            type = 'success' })
    else
        -- Legacy fallback (no pickup coords): behave as before.
        phase = 'dropoff'
        activeBlip = Game.CreateRouteBlip(activeDropoff, payload.label, Config.DeliveryBlipColor or 5)
        Game.Notify({ title = 'Courier',
            description = ('Delivery #%d accepted. Follow the GPS to the dropoff.'):format(payload.id),
            type = 'success' })
    end
end)

RegisterNetEvent('palm6_courier:onPickedUp', function(payload)
    if payload.id ~= activeId then return end
    Game.RemoveBlip(activeBlip)
    activeDropoff = payload.dropoff or activeDropoff
    phase = 'dropoff'
    activeBlip = Game.CreateRouteBlip(activeDropoff, (payload.label or 'Package') .. ' (dropoff)',
        Config.DeliveryBlipColor or 5)
    Game.Notify({ title = 'Courier',
        description = 'Package collected. Follow the GPS to the dropoff.', type = 'success' })
end)

CreateThread(function()
    while true do
        if activeId and phase == 'pickup' and activePickup then
            if Game.DistanceBetween(Game.GetPlayerCoords(), activePickup) <= (Config.DeliveryRadiusMeters or 8.0) then
                TriggerServerEvent('palm6_courier:pickup', activeId)
                Wait(2000)  -- debounce until the server flips us to 'dropoff'
            else
                Wait(1500)
            end
        elseif activeId and phase == 'dropoff' and activeDropoff then
            if Game.DistanceBetween(Game.GetPlayerCoords(), activeDropoff) <= (Config.DeliveryRadiusMeters or 8.0) then
                local id = activeId
                clearActive()
                TriggerServerEvent('palm6_courier:complete', id)
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
    TriggerServerEvent('palm6_courier:post', {
        bounty = bounty,
        pickup = pickup,
        dropoff = dropoff,
        label = table.concat(args, ' ', 2):sub(1, 60),
    })
end, false)
