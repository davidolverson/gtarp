-- ============================================================================
-- gtarp_counterfeit/bridge/sv_framework.lua
--
-- Framework adapter (server). The ONLY file in this resource that touches
-- qbx_core (identity, money, job data, usable items), ox_inventory (items,
-- metadata, slots, transfer hooks), qbx_police (police:server:policeAlert),
-- ox_lib notifications, or server-side game natives. The printer lifecycle,
-- serial registry, provenance chain, heat model, and cascade rules all live
-- in server/main.lua and call Bridge.* only. To port to GTA VI, rewrite
-- THIS FILE. See docs/GTA6-READINESS.md (Section 3, the bridge pattern).
-- ============================================================================

Bridge = {}

-- Resolve the framework player object for a server source, or nil.
local function getPlayer(src)
    local ok, p = pcall(function() return exports.qbx_core:GetPlayer(src) end)
    return ok and p or nil
end

-- ---------------------------------------------------------------------------
-- Identity / job
-- ---------------------------------------------------------------------------

-- Stable per-character id, or nil.
function Bridge.GetCitizenId(src)
    local p = getPlayer(src)
    if not p or not p.PlayerData then return nil end
    return p.PlayerData.citizenid
end

-- RP display name for a source (provenance attribution).
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

-- Is this source an on-duty police officer right now?
function Bridge.IsOnDutyPolice(src)
    local p = getPlayer(src)
    local job = p and p.PlayerData and p.PlayerData.job
    return job ~= nil and job.name == 'police' and job.onduty == true
end

-- Server id currently playing the character `citizenid`, or nil (offline).
function Bridge.GetSourceByCitizenId(citizenid)
    for _, sid in ipairs(GetPlayers()) do
        sid = tonumber(sid)
        local p = getPlayer(sid)
        if p and p.PlayerData and p.PlayerData.citizenid == citizenid then
            return sid
        end
    end
    return nil
end

-- List of server ids of on-duty police.
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
-- Money (the fence is the only payout leg; everything else moves items)
-- ---------------------------------------------------------------------------

-- Pay the source `amount` in cash. Returns true if applied.
function Bridge.AddCash(src, amount, reason)
    local p = getPlayer(src)
    if not p or not p.Functions then return false end
    p.Functions.AddMoney('cash', amount, reason)
    return true
end

-- ---------------------------------------------------------------------------
-- Inventory (ox_inventory)
-- ---------------------------------------------------------------------------

-- Presence check: can ox_inventory resolve this item name? Registration is
-- declarative (ox_inventory_overrides/data/items.lua ExtraItems) — runtime
-- merges do NOT reach ox_inventory (cross-resource export returns are
-- msgpack copies), so this only verifies, never registers. Same boot gate
-- as gtarp_flashdrop.
function Bridge.ItemExists(name)
    local ok, item = pcall(function() return exports.ox_inventory:Items(name) end)
    return ok and item ~= nil
end

-- Register a server-side "use item" callback: fn(src) is called whenever a
-- player uses the item. All validation stays in the logic layer.
function Bridge.OnUseItem(name, fn)
    pcall(function()
        exports.qbx_core:CreateUseableItem(name, function(source)
            fn(source)
        end)
    end)
end

-- Give `count` of an item (metadata optional). Returns true if it all fit.
function Bridge.GiveItem(src, name, count, metadata)
    local ok, added = pcall(function()
        return exports.ox_inventory:AddItem(src, name, count or 1, metadata)
    end)
    return ok and added and true or false
end

-- How many of a plain item the player holds.
function Bridge.CountItem(src, name)
    local ok, n = pcall(function()
        return exports.ox_inventory:Search(src, 'count', name)
    end)
    return ok and (tonumber(n) or 0) or 0
end

-- Remove `count` of a plain item. Returns true if removed.
function Bridge.RemoveItem(src, name, count)
    local ok, removed = pcall(function()
        return exports.ox_inventory:RemoveItem(src, name, count or 1)
    end)
    return ok and removed and true or false
end

-- All items named `name` in a player's inventory, as
-- { { slot = n, metadata = {...} }, ... }.
function Bridge.ListItemSlots(src, name)
    local ok, slots = pcall(function()
        return exports.ox_inventory:GetSlotsWithItem(src, name)
    end)
    local out = {}
    if ok and type(slots) == 'table' then
        for _, s in ipairs(slots) do
            out[#out + 1] = { slot = s.slot, metadata = s.metadata or {} }
        end
    end
    return out
end

-- Can the player carry `count` of `name` right now (weight + slots)?
function Bridge.CanCarry(src, name, count)
    local ok, can = pcall(function()
        return exports.ox_inventory:CanCarryItem(src, name, count or 1)
    end)
    return ok and can and true or false
end

-- Remove the item sitting in `slot`. Returns true if removed.
function Bridge.RemoveItemBySlot(src, name, slot)
    local ok, removed = pcall(function()
        return exports.ox_inventory:RemoveItem(src, name, 1, nil, slot)
    end)
    return ok and removed and true or false
end

-- Observe wad transfers. Registers an ox_inventory 'swapItems' hook filtered
-- to `itemName` and calls fn(info) when a move is approved:
--   info = {
--     serial     = metadata.serial (nil if untagged),
--     fromType   = 'player'|'drop'|'stash'|..., fromId = inventory id,
--     toType     = 'player'|'drop'|'stash'|..., toId   = inventory id,
--     fromCitizenId/fromName, toCitizenId/toName (player ends only),
--   }
-- Observation only — the hook never blocks a move. If the hook API is
-- unavailable (very old ox_inventory), transfers simply go unrecorded and a
-- console warning is printed once at boot.
function Bridge.OnItemMoved(itemName, fn)
    -- Build + deliver one transfer record for a slot travelling
    -- fromType/fromId -> toType/toId.
    local function emit(slotData, fromType, fromId, toType, toId)
        local meta = type(slotData) == 'table' and slotData.metadata or nil
        local info = {
            serial   = meta and meta.serial or nil,
            fromType = fromType,
            fromId   = fromId,
            toType   = toType,
            toId     = toId,
        }
        if fromType == 'player' then
            local s = tonumber(fromId)
            info.fromCitizenId = s and Bridge.GetCitizenId(s) or nil
            info.fromName = s and Bridge.GetPlayerName(s) or nil
        end
        if toType == 'player' then
            local s = tonumber(toId)
            info.toCitizenId = s and Bridge.GetCitizenId(s) or nil
            info.toName = s and Bridge.GetPlayerName(s) or nil
        end
        fn(info)
    end
    local ok = pcall(function()
        exports.ox_inventory:registerHook('swapItems', function(payload)
            -- Never let an observer error block the player's move.
            pcall(function()
                -- Active side: the dragged item goes from -> to.
                emit(payload.fromSlot,
                    payload.fromType, payload.fromInventory,
                    payload.toType, payload.toInventory)
                -- Passive side of a SWAP: when another item is dragged onto
                -- an occupied slot, ox_inventory hands us that occupant as
                -- payload.toSlot (a table; it's a bare slot number on moves
                -- into empty space) and it travels the OPPOSITE way. A wad
                -- swapped-out across inventories still changes hands, so it
                -- must be recorded or the provenance chain silently gaps.
                if type(payload.toSlot) == 'table'
                    and payload.toSlot.metadata
                    and payload.toSlot.metadata.serial
                    and payload.fromInventory ~= payload.toInventory then
                    emit(payload.toSlot,
                        payload.toType, payload.toInventory,
                        payload.fromType, payload.fromInventory)
                end
            end)
        end, {
            itemFilter = { [itemName] = true },
        })
    end)
    if not ok then
        print('^3[gtarp_counterfeit] WARN: ox_inventory hook API unavailable — '
            .. 'player-to-player wad transfers will not be recorded in provenance.^0')
    end
    return ok
end

-- ---------------------------------------------------------------------------
-- Police alerting
-- ---------------------------------------------------------------------------

-- Report the source to police the same way qbx_drugs cornerselling does:
-- TriggerEvent('police:server:policeAlert', text, nil, suspectSrc). On
-- server-side calls qbx_police (and the gtarp_witnesses fan-in hook)
-- derive the alert/blip coords from arg 3, the suspect's source — the
-- same contract gtarp_witnesses' Bridge.PoliceAlert uses. Falls back to
-- our own dispatch broadcast when qbx_police is not running.
function Bridge.PoliceAlert(src, text)
    if GetResourceState('qbx_police') == 'started' then
        local ok = pcall(function()
            TriggerEvent('police:server:policeAlert', text, nil, src)
        end)
        if ok then return end
    end
    -- Fallback: point dispatch to every on-duty officer (gtarp_robbery style).
    local ped = GetPlayerPed(src)
    local c = ped and ped ~= 0 and GetEntityCoords(ped) or nil
    if not c then return end
    for _, sid in ipairs(onDutyPolice()) do
        TriggerClientEvent('gtarp_counterfeit:dispatch', sid, {
            coords = { x = c.x, y = c.y, z = c.z }, label = text,
        })
    end
end

-- Send the VAGUE district heat ping (area circle, not a point) to every
-- on-duty officer. `coords` is already jittered by the logic layer.
function Bridge.PingPoliceArea(coords, radius, label, durationSec)
    for _, sid in ipairs(onDutyPolice()) do
        TriggerClientEvent('gtarp_counterfeit:heatPing', sid, {
            coords = coords, radius = radius, label = label, duration = durationSec,
        })
    end
end

-- ---------------------------------------------------------------------------
-- Presence / world
-- ---------------------------------------------------------------------------

-- Current coords of a player's ped as {x,y,z}, or nil. Server-side
-- anti-abuse proximity — never trust the client's claimed position.
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

-- Monotonic server clock in milliseconds (command rate limiting).
function Bridge.NowMs()
    return GetGameTimer()
end

-- Is a sibling resource running? (soft-dependency probes)
function Bridge.ResourceStarted(name)
    return GetResourceState(name) == 'started'
end

-- Server-owned networked world prop (OneSync) for a placed printer.
-- Cosmetic — returns an entity handle or nil; every interaction works off
-- coords, never off this entity.
function Bridge.SpawnWorldProp(model, coords, heading)
    local ok, ent = pcall(function()
        local e = CreateObjectNoOffset(joaat(model), coords.x, coords.y, coords.z, true, true, false)
        if e and e ~= 0 then
            SetEntityHeading(e, heading or 0.0)
            FreezeEntityPosition(e, true)
        end
        return e
    end)
    return ok and ent and ent ~= 0 and ent or nil
end

function Bridge.DeleteWorldProp(ent)
    if not ent then return end
    pcall(function()
        if DoesEntityExist(ent) then DeleteEntity(ent) end
    end)
end

-- ---------------------------------------------------------------------------
-- Notifications
-- ---------------------------------------------------------------------------

-- Notify one player (src 0 = server console).
function Bridge.Notify(src, title, msg, t)
    if src == 0 then
        print(('[gtarp_counterfeit] %s: %s'):format(title, msg))
        return
    end
    TriggerClientEvent('ox_lib:notify', src, {
        title = title, description = msg, type = t or 'inform',
    })
end
