-- ============================================================================
-- gtarp_civilian_runs/server/main.lua
--
-- The playable loop behind qbx_civilian_jobs_overrides' curated `runs`
-- (trucker/taxi/garbage/mechanic on-call): go to the starter NPC, pick a
-- run, drive to a destination, arrive within the time limit, get paid the
-- run's configured payout. That config was validated and exported
-- (GetJobs/GetJob) but nothing ever consumed it — this resource is the
-- consumer. Pure logic — all framework/native access via Bridge.* (§6 gate).
-- ============================================================================

local jobsData  = {}  -- [jobName] = { label, starter_npc, runs }
local cooldowns = {}  -- [src] = { [jobName..':'..runIndex] = unix expiry }
local active    = {}  -- [src] = { jobName, runIndex, dest, deadline, payout }

local function loadJobsData()
    jobsData = {}
    for name, job in pairs(Bridge.GetCivilianJobs()) do
        jobsData[name] = {
            label = job.label,
            starter_npc = job.starter_npc,
            runs = job.runs,
        }
    end
end

local function tierFor(index, list)
    return list[math.min(index, #list)]
end

local function randomDestination(base, tierIndex)
    local d = tierFor(tierIndex, Config.DestDistanceByTier)
    local dist = math.random(d.min, d.max)
    local angle = math.random() * 2 * math.pi
    return {
        x = base.x + math.cos(angle) * dist,
        y = base.y + math.sin(angle) * dist,
        z = base.z,
    }
end

AddEventHandler('onResourceStart', function(resource)
    if resource ~= GetCurrentResourceName() then return end
    loadJobsData()
    local count = 0
    for _ in pairs(jobsData) do count = count + 1 end
    print(('[gtarp_civilian_runs] loaded %d curated job(s) with runs'):format(count))
end)

RegisterNetEvent('gtarp_civilian_runs:requestSync', function()
    TriggerClientEvent('gtarp_civilian_runs:syncJobs', source, jobsData)
end)

RegisterNetEvent('gtarp_civilian_runs:requestStart', function(jobName, runIndex)
    local src = source
    if not Bridge.GetCitizenId(src) then return end
    if active[src] then
        Bridge.Notify(src, 'Dispatch', 'You are already on a run.', 'error'); return
    end

    local job = jobsData[jobName]
    local run = job and job.runs[runIndex]
    if not job or not run then return end

    local playerJob = Bridge.GetJob(src)
    if not playerJob or playerJob.name ~= jobName or not playerJob.onduty then
        Bridge.Notify(src, 'Dispatch', ('You need to be on duty as %s.'):format(job.label), 'error')
        return
    end

    local coords = Bridge.GetCoords(src)
    if not coords or Bridge.Distance(coords, job.starter_npc.coords) >
        (job.starter_npc.radius + Config.InteractRadius + 3.0) then
        Bridge.Notify(src, 'Dispatch', 'You are too far from dispatch.', 'error')
        return
    end

    cooldowns[src] = cooldowns[src] or {}
    local key = jobName .. ':' .. runIndex
    local now = os.time()
    if (cooldowns[src][key] or 0) > now then
        Bridge.Notify(src, 'Dispatch', 'That run is still on cooldown.', 'error')
        return
    end

    -- Reserve immediately so the run can't be double-started.
    cooldowns[src][key] = now + run.cooldown_seconds
    local timeLimit = tierFor(runIndex, Config.TimeLimitByTier)
    local dest = randomDestination(job.starter_npc.coords, runIndex)
    active[src] = { jobName = jobName, runIndex = runIndex, dest = dest,
                     deadline = now + timeLimit, payout = run.payout }

    TriggerClientEvent('gtarp_civilian_runs:beginRun', src,
        { dest = dest, label = run.route, timeLimitSeconds = timeLimit })
end)

RegisterNetEvent('gtarp_civilian_runs:arrived', function()
    local src = source
    local act = active[src]
    if not act then return end

    if os.time() > act.deadline then
        active[src] = nil
        Bridge.Notify(src, 'Dispatch', 'You ran out of time.', 'error')
        return
    end

    local coords = Bridge.GetCoords(src)
    if not coords or Bridge.Distance(coords, act.dest) > (Config.ArrivalRadius + 3.0) then
        return  -- not actually there; ignore (client shouldn't send this)
    end

    active[src] = nil
    Bridge.CreditBank(src, act.payout, 'civilian-run:' .. act.jobName)
    Bridge.Notify(src, 'Dispatch', ('Run complete. Paid $%d.'):format(act.payout), 'success')
end)

RegisterNetEvent('gtarp_civilian_runs:cancel', function()
    active[source] = nil
end)

AddEventHandler('playerDropped', function()
    active[source] = nil
    cooldowns[source] = nil
end)
