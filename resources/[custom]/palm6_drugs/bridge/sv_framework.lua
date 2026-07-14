-- ============================================================================
-- palm6_drugs/bridge/sv_framework.lua
--
-- Framework adapter (server). The ONLY file in this resource that calls
-- qbx_core / ox_inventory / qbx_police exports or server-side game natives.
-- server/main.lua holds the grow / mix / sell logic (and its own portable
-- drugs_* SQL) and calls Bridge.* only, so a port to GTA VI is a rewrite of
-- THIS FILE. See docs/GTA6-READINESS.md §3 (the bridge pattern).
-- ============================================================================

Bridge = {}

local function getPlayer(src)
    local ok, p = pcall(function() return exports.qbx_core:GetPlayer(src) end)
    return ok and p or nil
end

-- ---------------------------------------------------------------------------
-- Identity
-- ---------------------------------------------------------------------------

-- Stable per-character id, or nil.
function Bridge.GetCitizenId(src)
    local p = getPlayer(src)
    return p and p.PlayerData and p.PlayerData.citizenid or nil
end

-- RP display name for a source (producer attribution / evidence).
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

-- List of server ids of on-duty police (fallback dispatch fan-out).
local function onDutyPolice()
    local out = {}
    for _, sid in ipairs(GetPlayers()) do
        sid = tonumber(sid)
        local p = getPlayer(sid)
        local job = p and p.PlayerData and p.PlayerData.job
        if job and job.name == 'police' and job.onduty then
            out[#out + 1] = sid
        end
    end
    return out
end

-- ---------------------------------------------------------------------------
-- Inventory. black_money is a plain count-based item (count == dollars), so
-- paying dirty cash is just AddItem of the dirty item — no bank/cash call.
-- Finished products ride metadata; helpers below expose slots + metadata so
-- the logic layer can price from the REAL item, never from client input.
-- ---------------------------------------------------------------------------

-- Presence check: can ox_inventory resolve this item name? Used at boot to
-- self-disable loudly if a required item isn't registered.
function Bridge.ItemExists(name)
    local ok, item = pcall(function() return exports.ox_inventory:Items(name) end)
    return ok and item ~= nil
end

-- How many of `item` the player holds (all slots, count-summed).
function Bridge.CountItem(src, item)
    local ok, n = pcall(function() return exports.ox_inventory:Search(src, 'count', item) end)
    return (ok and tonumber(n)) or 0
end

-- Does the player hold at least `count` (default 1) of `item`?
function Bridge.HasItem(src, item, count)
    return Bridge.CountItem(src, item) >= (count or 1)
end

-- Add `count` of `item` (metadata optional). Returns true only if ox reports
-- it fit — the logic layer credits nothing it didn't actually grant.
function Bridge.GiveItem(src, item, count, metadata)
    local ok, added = pcall(function()
        return exports.ox_inventory:AddItem(src, item, count or 1, metadata)
    end)
    return ok and added and true or false
end

-- Remove `count` of `item` (any slots). Returns true only if ox reports the
-- removal succeeded — the logic layer pays nothing it didn't actually take.
function Bridge.RemoveItem(src, item, count)
    local ok, removed = pcall(function()
        return exports.ox_inventory:RemoveItem(src, item, count or 1)
    end)
    return ok and removed and true or false
end

-- Remove `count` of `item` from a SPECIFIC slot (the base stack the player
-- picked to mix / sell). Returns true if removed.
function Bridge.RemoveItemFromSlot(src, item, count, slot)
    local ok, removed = pcall(function()
        return exports.ox_inventory:RemoveItem(src, item, count or 1, nil, slot)
    end)
    return ok and removed and true or false
end

-- All slots holding `name`, as { { slot, count, metadata = {...} }, ... }.
function Bridge.ListItemSlots(src, name)
    local ok, slots = pcall(function()
        return exports.ox_inventory:GetSlotsWithItem(src, name)
    end)
    local out = {}
    if ok and type(slots) == 'table' then
        for _, s in ipairs(slots) do
            out[#out + 1] = {
                slot = s.slot,
                count = tonumber(s.count) or 1,
                metadata = s.metadata or {},
            }
        end
    end
    return out
end

-- The metadata + count of one specific slot of `name`, or nil. Re-read at the
-- moment of the action so a stale client slot index can't misprice a sale.
function Bridge.GetSlot(src, name, slot)
    for _, s in ipairs(Bridge.ListItemSlots(src, name)) do
        if s.slot == slot then return s end
    end
    return nil
end

-- Can the player carry `count` of `name` right now (weight + slots)?
function Bridge.CanCarry(src, name, count)
    local ok, can = pcall(function()
        return exports.ox_inventory:CanCarryItem(src, name, count or 1)
    end)
    return ok and can and true or false
end

-- ---------------------------------------------------------------------------
-- Police alerting (heat outcome). Reuses the exact cornerselling/laundering
-- contract: police:server:policeAlert derives the alert/blip coords from arg 3
-- (the suspect's source) server-side. Falls back to a direct dispatch fan-out
-- to on-duty police when qbx_police isn't running.
-- ---------------------------------------------------------------------------
function Bridge.PoliceAlert(src, text)
    if GetResourceState('qbx_police') == 'started' then
        local ok = pcall(function()
            TriggerEvent('police:server:policeAlert', text, nil, src)
        end)
        if ok then return end
    end
    local ped = GetPlayerPed(src)
    local c = ped and ped ~= 0 and GetEntityCoords(ped) or nil
    if not c then return end
    for _, sid in ipairs(onDutyPolice()) do
        TriggerClientEvent('palm6_drugs:dispatch', sid, {
            coords = { x = c.x, y = c.y, z = c.z }, label = text,
        })
    end
end

-- ---------------------------------------------------------------------------
-- Presence / world
-- ---------------------------------------------------------------------------

-- Caller's ped position as {x,y,z}, or nil. Server-side anti-abuse proximity —
-- never trust a client-supplied position.
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

-- Notify a player (src 0 = server console).
function Bridge.Notify(src, title, msg, t)
    if src == 0 then
        print(('[palm6_drugs] %s: %s'):format(title, msg))
        return
    end
    TriggerClientEvent('ox_lib:notify', src, {
        title = title, description = msg, type = t or 'inform',
    })
end

function Bridge.ResourceStarted(name)
    return GetResourceState(name) == 'started'
end
