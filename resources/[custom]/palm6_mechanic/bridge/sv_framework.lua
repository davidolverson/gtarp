-- ============================================================================
-- palm6_mechanic/bridge/sv_framework.lua
--
-- Framework adapter (server). The ONLY file in this resource that touches
-- qbx_core (money, job data) or server-side natives. The repair-invoice
-- rules (job gate, proximity, cooldown, payment) live in server/main.lua
-- and call Bridge.* only. To port to GTA VI, rewrite THIS FILE.
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

-- Is this source an on-duty mechanic right now?
function Bridge.IsOnDutyMechanic(src)
    local p = getPlayer(src)
    local job = p and p.PlayerData and p.PlayerData.job
    return job ~= nil and job.name == 'mechanic' and job.onduty == true
end

-- Debit `amount` from the source's bank. Returns true on success.
function Bridge.ChargeBank(src, amount, reason)
    local p = getPlayer(src)
    if not p or not p.Functions then return false end
    if (p.PlayerData.money.bank or 0) < amount then return false end
    return p.Functions.RemoveMoney('bank', amount, reason) and true or false
end

-- Credit `amount` to the source's bank. Returns true if applied.
function Bridge.CreditBank(src, amount, reason)
    local p = getPlayer(src)
    if not p or not p.Functions then return false end
    p.Functions.AddMoney('bank', amount, reason)
    return true
end

-- Register an ox_inventory usable-item callback (fires server-side on use).
function Bridge.OnUseItem(name, fn)
    pcall(function()
        exports.qbx_core:CreateUseableItem(name, function(source) fn(source) end)
    end)
end

-- Remove `count` of an item from a player. Returns true if it was removed.
function Bridge.RemoveItem(src, name, count)
    local ok, removed = pcall(function()
        return exports.ox_inventory:RemoveItem(src, name, count or 1)
    end)
    return ok and removed ~= false
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

-- Resolve a networked vehicle entity from its net id, or nil if it no
-- longer exists.
function Bridge.GetVehicleFromNetId(netId)
    if not NetworkDoesNetworkIdExist(netId) then return nil end
    local veh = NetworkGetEntityFromNetworkId(netId)
    if not veh or veh == 0 or not DoesEntityExist(veh) then return nil end
    return veh
end

-- Coords of a vehicle entity as {x,y,z}, or nil.
function Bridge.GetVehicleCoords(veh)
    if not veh or veh == 0 then return nil end
    local c = GetEntityCoords(veh)
    return { x = c.x, y = c.y, z = c.z }
end

-- {engine, body} health for a networked vehicle. Checked server-side so a
-- customer can't be invoiced for "repairing" an undamaged car —
-- GetVehicleEngineHealth/GetVehicleBodyHealth work on any synced vehicle,
-- same as GetEntityCoords above.
function Bridge.GetVehicleHealth(veh)
    return { engine = GetVehicleEngineHealth(veh), body = GetVehicleBodyHealth(veh) }
end

-- Find the nearest player (excluding `excludeSrc`) within `radius` metres
-- of `coords`. Returns the server id, or nil if none are close enough —
-- this is the "customer" a repair gets invoiced to.
function Bridge.NearestOtherPlayer(excludeSrc, coords, radius)
    local best, bestDist = nil, radius
    for _, sid in ipairs(GetPlayers()) do
        sid = tonumber(sid)
        if sid ~= excludeSrc then
            local c = Bridge.GetCoords(sid)
            if c then
                local d = Bridge.Distance(coords, c)
                if d <= bestDist then best, bestDist = sid, d end
            end
        end
    end
    return best
end

-- Display name for a source, for invoice notifications.
function Bridge.GetPlayerName(src)
    local p = getPlayer(src)
    if p and p.PlayerData and p.PlayerData.charinfo then
        local ci = p.PlayerData.charinfo
        return ('%s %s'):format(ci.firstname or '', ci.lastname or ''):gsub('^%s+', ''):gsub('%s+$', '')
    end
    return GetPlayerName(src) or ('player %d'):format(src)
end
