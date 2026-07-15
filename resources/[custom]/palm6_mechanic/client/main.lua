-- ============================================================================
-- palm6_mechanic/client/main.lua
--
-- Pure logic. Calls Game.* (bridge/cl_game.lua) for all native access.
-- No direct natives / ox_lib here (§6 gate). Server is authoritative on the
-- job gate, cooldown, and payment — this loop is an opportunistic prompt.
-- ============================================================================

local function isDamaged(veh)
    local h = Game.GetVehicleHealth(veh)
    return h.engine < Config.EngineHealthThreshold or h.body < Config.BodyHealthThreshold
end

CreateThread(function()
    while true do
        local coords = Game.GetPlayerCoords()
        local veh = Game.GetClosestVehicle(coords, Config.InteractRadius)
        local wait = 750

        if veh and isDamaged(veh) then
            wait = 0
            Game.ShowHelpThisFrame(('Press ~INPUT_PICKUP~ to repair this vehicle ($%d, invoiced to nearest player)'):format(Config.RepairCost))
            if Game.InteractPressed() then
                TriggerServerEvent('palm6_mechanic:start', Game.GetVehicleNetId(veh))
            end
        end

        Wait(wait)
    end
end)

RegisterNetEvent('palm6_mechanic:begin', function(vehNetId)
    local ok = Game.ProgressBar('Repairing vehicle...', Config.ProgressMs)
    if ok then
        TriggerServerEvent('palm6_mechanic:complete', vehNetId)
    else
        TriggerServerEvent('palm6_mechanic:cancel', vehNetId)
    end
end)

RegisterNetEvent('palm6_mechanic:applyRepair', function(vehNetId)
    local veh = Game.GetVehicleFromNetId(vehNetId)
    if veh then Game.RepairVehicle(veh) end
end)

-- Self-serve kit use: the server already consumed the item, so here we just
-- apply the effect to the nearest vehicle (or warn if there isn't one).
RegisterNetEvent('palm6_mechanic:useKit', function(kind)
    local veh = Game.GetClosestVehicle(Game.GetPlayerCoords(), (Config.Kits and Config.Kits.Radius) or 5.0)
    if not veh or veh == 0 then
        Game.Notify({ title = 'Vehicle Kit', description = 'No vehicle close enough to work on.', type = 'error' })
        return
    end
    if kind == 'tire' then
        Game.FixTires(veh)
        Game.Notify({ title = 'Tire Pack', description = 'Fitted a fresh set of tyres.', type = 'success' })
    else
        Game.RepairVehicle(veh)
        Game.Notify({ title = 'Repair Kit', description = 'Patched the vehicle up.', type = 'success' })
    end
end)

-- The server offered a repair invoice. Ask the customer to accept before any
-- charge; only a positive dialog fires the accept back to the server.
RegisterNetEvent('palm6_mechanic:confirmInvoice', function(_mechSrc, amount)
    if Game.ConfirmDialog('Repair Invoice',
        ('A mechanic wants to charge $%d to repair your vehicle. Accept?'):format(amount)) then
        TriggerServerEvent('palm6_mechanic:acceptInvoice')
    end
end)
