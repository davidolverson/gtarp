-- ============================================================================
-- palm6_protection/bridge/sv_framework.lua
--
-- Framework adapter (server). The ONLY file in this resource that calls
-- qbx_core / ox_inventory / qbx_police / the palm6_turf cross-read or
-- server-side natives. server/main.lua (the racket logic) calls Bridge.*
-- only, so a port to GTA VI is a rewrite of THIS FILE. See §3.
-- ============================================================================

Bridge = {}

local function getPlayer(src)
    local ok, p = pcall(function() return exports.qbx_core:GetPlayer(src) end)
    return ok and p or nil
end

-- Stable per-character id, or nil.
function Bridge.GetCitizenId(src)
    local p = getPlayer(src)
    return p and p.PlayerData and p.PlayerData.citizenid or nil
end

-- The caller's PLAYER-RUN gang (palm6_gangs), or nil if unaffiliated. Keyed on
-- the player-run gang layer so this matches palm6_turf.owner_gang, which now
-- stores palm6_gangs.name (see palm6_turf/bridge/sv_framework.lua). Soft dep —
-- pcall-guarded so /shakedown degrades gracefully if palm6_gangs is absent.
function Bridge.GetGang(src)
    local cid = Bridge.GetCitizenId(src)
    if not cid then return nil end
    local ok, g = pcall(function() return exports.palm6_gangs:GetGang(cid) end)
    if not ok or not g or not g.name then return nil end
    return { id = g.id, name = g.name, label = g.tag or g.name }
end

-- Which gang controls a turf zone right now, or nil. SOFT cross-read of the
-- palm6_turf table — the established house pattern (palm6_flashdrop/clout/
-- pumpcoin do the same); tolerates palm6_turf being absent/unstarted.
function Bridge.GetZoneOwner(zoneId)
    local ok, gang = pcall(function()
        return MySQL.scalar.await('SELECT owner_gang FROM palm6_turf WHERE zone_id = ?', { zoneId })
    end)
    if ok and gang and gang ~= '' then return gang end
    return nil
end

-- Presence check: can ox_inventory resolve this item name? Boot self-disable.
function Bridge.ItemExists(name)
    local ok, item = pcall(function() return exports.ox_inventory:Items(name) end)
    return ok and item ~= nil
end

-- Pay protection money (black_money, plain count == dollars — dirty by nature).
function Bridge.GiveItem(src, name, count)
    local ok, added = pcall(function()
        return exports.ox_inventory:AddItem(src, name, count)
    end)
    return ok and added and true or false
end

-- On-duty police server ids (fallback dispatch).
local function onDutyPolice()
    local out = {}
    for _, sid in ipairs(GetPlayers()) do
        sid = tonumber(sid)
        local p = getPlayer(sid)
        local job = p and p.PlayerData and p.PlayerData.job
        if job and job.name == 'police' and job.onduty then out[#out + 1] = sid end
    end
    return out
end

-- Report the extortionist to police (cornerselling/counterfeit contract:
-- police:server:policeAlert derives coords from arg 3 server-side). Falls back
-- to a direct dispatch fan-out when qbx_police isn't running.
function Bridge.PoliceAlert(src, text)
    if GetResourceState('qbx_police') == 'started' then
        local ok = pcall(function() TriggerEvent('police:server:policeAlert', text, nil, src) end)
        if ok then return end
    end
    local ped = GetPlayerPed(src)
    local c = ped and ped ~= 0 and GetEntityCoords(ped) or nil
    if not c then return end
    for _, sid in ipairs(onDutyPolice()) do
        TriggerClientEvent('palm6_protection:dispatch', sid, {
            coords = { x = c.x, y = c.y, z = c.z }, label = text,
        })
    end
end

-- Caller's ped position as {x,y,z}, or nil (server-side proximity — never
-- trust a client-supplied coordinate).
function Bridge.GetCoords(src)
    local ped = GetPlayerPed(src)
    if not ped or ped == 0 then return nil end
    local c = GetEntityCoords(ped)
    return { x = c.x, y = c.y, z = c.z }
end

function Bridge.Distance(a, b)
    return #(vector3(a.x, a.y, a.z) - vector3(b.x, b.y, b.z))
end

function Bridge.Notify(src, title, msg, t)
    if src == 0 then
        print(('[palm6_protection] %s: %s'):format(title, msg))
        return
    end
    TriggerClientEvent('ox_lib:notify', src, {
        title = title, description = msg, type = t or 'inform',
    })
end

function Bridge.ResourceStarted(name)
    return GetResourceState(name) == 'started'
end

function Bridge.RegisterCommand(name, handler)
    RegisterCommand(name, handler, false)
end
