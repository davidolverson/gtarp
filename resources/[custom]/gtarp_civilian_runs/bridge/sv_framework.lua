-- ============================================================================
-- gtarp_civilian_runs/bridge/sv_framework.lua
--
-- Framework adapter (server). The ONLY file in this resource that touches
-- qbx_core (money, job data) or server-side natives. The dispatch-run
-- rules (job gate, proximity, timing, payout) live in server/main.lua and
-- call Bridge.* only. To port to GTA VI, rewrite THIS FILE.
-- See docs/GTA6-READINESS.md (Section 3, the bridge pattern).
-- ============================================================================

Bridge = {}

local function getPlayer(src)
    local ok, p = pcall(function() return exports.qbx_core:GetPlayer(src) end)
    return ok and p or nil
end

-- Stable per-character id, or nil.
function Bridge.GetCitizenId(src)
    local p = getPlayer(src)
    if not p or not p.PlayerData then return nil end
    return p.PlayerData.citizenid
end

-- { name, onduty } for the source's current job, or nil.
function Bridge.GetJob(src)
    local p = getPlayer(src)
    local job = p and p.PlayerData and p.PlayerData.job
    if not job then return nil end
    return { name = job.name, onduty = job.onduty == true }
end

-- Credit `amount` to the source's bank. Returns true if applied.
function Bridge.CreditBank(src, amount, reason)
    local p = getPlayer(src)
    if not p or not p.Functions then return false end
    p.Functions.AddMoney('bank', amount, reason)
    return true
end

-- Notify a player.
function Bridge.Notify(src, title, msg, t)
    TriggerClientEvent('ox_lib:notify', src, {
        title = title, description = msg, type = t or 'inform',
    })
end

-- Current coords of a player's ped as {x,y,z}, or nil.
function Bridge.GetCoords(src)
    local ped = GetPlayerPed(src)
    if not ped or ped == 0 then return nil end
    local c = GetEntityCoords(ped)
    return { x = c.x, y = c.y, z = c.z }
end

-- Distance in metres between two coord tables (accepts vector3 too).
function Bridge.Distance(a, b)
    return #(vector3(a.x, a.y, a.z) - vector3(b.x, b.y, b.z))
end

-- The full curated civilian-jobs catalog published by
-- qbx_civilian_jobs_overrides (Config.Jobs there) — this is the ONLY place
-- we read that export.
function Bridge.GetCivilianJobs()
    local ok, jobs = pcall(function()
        return exports.qbx_civilian_jobs_overrides:GetJobs()
    end)
    return (ok and jobs) or {}
end
