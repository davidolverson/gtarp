-- ============================================================================
-- gtarp_civilian_runs/client/main.lua
--
-- Pure logic. Calls Game.* (bridge/cl_game.lua) for all native access.
-- No direct natives / ox_lib here (§6 gate). Server is authoritative on the
-- job/duty gate, proximity, cooldown, and payout — this is UI + prompts.
-- ============================================================================

local jobsData = {}
local currentBlip = nil
local onRun = false

local function requestSync()
    TriggerServerEvent('gtarp_civilian_runs:requestSync')
end

RegisterNetEvent('gtarp_civilian_runs:syncJobs', function(data)
    jobsData = data or {}
end)

Game.OnPlayerLoaded(requestSync)
CreateThread(requestSync)  -- covers resource restarts while already in-game

CreateThread(function()
    while true do
        local wait = 750
        if not onRun then
            local coords = Game.GetPlayerCoords()
            for jobName, job in pairs(jobsData) do
                local npc = job.starter_npc
                if npc and Game.DistanceBetween(coords, npc.coords) <= (Config.InteractRadius + (npc.radius or 1.5)) then
                    wait = 0
                    Game.ShowHelpThisFrame(('Press ~INPUT_PICKUP~ for %s dispatch'):format(job.label))
                    if Game.InteractPressed() then
                        local options = {}
                        for i, run in ipairs(job.runs) do
                            options[#options + 1] = {
                                title = run.route,
                                description = ('$%d — %ds cooldown'):format(run.payout, run.cooldown_seconds),
                                runIndex = i,
                            }
                        end
                        Game.OpenRunMenu(jobName, options)
                    end
                end
            end
        end
        Wait(wait)
    end
end)

RegisterNetEvent('gtarp_civilian_runs:clientStart', function(data)
    TriggerServerEvent('gtarp_civilian_runs:requestStart', data.jobName, data.runIndex)
end)

RegisterNetEvent('gtarp_civilian_runs:beginRun', function(payload)
    onRun = true
    currentBlip = Game.SetWaypointBlip(payload.dest, payload.label)
    Game.Notify({ title = 'Dispatch', description = 'Head to the marker.', type = 'inform' })

    CreateThread(function()
        local elapsedMs = 0
        local limitMs = payload.timeLimitSeconds * 1000
        local arrived = false

        while elapsedMs < limitMs do
            Wait(500)
            elapsedMs = elapsedMs + 500
            if Game.DistanceBetween(Game.GetPlayerCoords(), payload.dest) <= Config.ArrivalRadius then
                arrived = true
                break
            end
        end

        Game.RemoveBlip(currentBlip)
        currentBlip = nil
        onRun = false

        if arrived then
            TriggerServerEvent('gtarp_civilian_runs:arrived')
        else
            TriggerServerEvent('gtarp_civilian_runs:cancel')
            Game.Notify({ title = 'Dispatch', description = 'You ran out of time.', type = 'error' })
        end
    end)
end)
