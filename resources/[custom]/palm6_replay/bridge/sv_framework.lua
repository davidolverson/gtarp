-- ============================================================================
-- palm6_replay/bridge/sv_framework.lua
--
-- Framework adapter (server). The ONLY file in this resource that touches
-- qbx_core (identity/job), ox_inventory (optional scanner item), server-side
-- natives (ped coords), or engine plumbing (weapon-damage game event). The
-- black-box rules — capture radius, frame validation, caps, access gates —
-- live in server/main.lua and call Bridge.* only. To port to GTA VI,
-- rewrite THIS FILE. See docs/GTA6-READINESS.md (Section 3).
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

-- Display name for a source, for participant attribution in scene rows.
function Bridge.GetPlayerName(src)
    local p = getPlayer(src)
    if p and p.PlayerData and p.PlayerData.charinfo then
        local ci = p.PlayerData.charinfo
        local name = ('%s %s'):format(ci.firstname or '', ci.lastname or '')
        name = name:gsub('^%s+', ''):gsub('%s+$', '')
        if #name > 0 then return name end
    end
    return GetPlayerName(src) or ('player %d'):format(src)
end

-- Is this source an on-duty member of one of `jobs` (list of job names)?
-- `requireDuty=false` skips the duty check.
function Bridge.HasJob(src, jobs, requireDuty)
    local p = getPlayer(src)
    local job = p and p.PlayerData and p.PlayerData.job
    if not job then return false end
    for _, name in ipairs(jobs or {}) do
        if job.name == name then
            return (not requireDuty) or job.onduty == true
        end
    end
    return false
end

-- Does the player carry at least one of `item` (ox_inventory)? Fails open
-- to false if the inventory export is unavailable.
function Bridge.HasItem(src, item)
    local ok, count = pcall(function()
        return exports.ox_inventory:GetItemCount(src, item)
    end)
    return ok and (count or 0) > 0
end

-- Notify a player.
function Bridge.Notify(src, title, msg, t)
    TriggerClientEvent('ox_lib:notify', src, {
        title = title, description = msg, type = t or 'inform',
    })
end

-- Current coords of a player's ped as {x,y,z}, or nil. This is the server's
-- OWN read of position — incident logic never trusts client-claimed coords.
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

-- All connected server ids, as numbers.
function Bridge.GetPlayers()
    local out = {}
    for _, s in ipairs(GetPlayers()) do
        out[#out + 1] = tonumber(s)
    end
    return out
end

-- Fire `cb(attackerSrc)` whenever the server sees weapon damage dealt by a
-- player (the engine's weaponDamageEvent). Higher-trust than our own net
-- events, but STILL a networked game event a modified client can emit — so
-- server/main.lua treats it like every other per-source trigger: flag-only,
-- shared per-source cooldown, global cap, attributed. Engine plumbing, so it
-- lives in the bridge; the decision to flag a scene stays in server/main.lua.
function Bridge.OnWeaponDamage(cb)
    AddEventHandler('weaponDamageEvent', function(sender, _data)
        local src = tonumber(sender)
        if src and src > 0 then cb(src) end
    end)
end

-- Fire `cb(victimSrc)` when a player dies/goes down. baseevents ships with
-- the cfx server base; its death reports are client-originated, which is why
-- server/main.lua treats this trigger as flag-only (never pay/grant/charge).
function Bridge.OnPlayerDowned(cb)
    RegisterNetEvent('baseevents:onPlayerDied', function()
        cb(source)
    end)
    RegisterNetEvent('baseevents:onPlayerKilled', function()
        cb(source)
    end)
end

-- Subscribe to another resource's client->server net event (e.g.
-- palm6_robbery:start) purely as an incident signal. Registering the same
-- net event name in a second resource adds a second handler — the owning
-- resource is untouched. `cb(src, ...)` receives the original args.
function Bridge.OnForeignNetEvent(eventName, cb)
    RegisterNetEvent(eventName, function(...)
        cb(source, ...)
    end)
end
