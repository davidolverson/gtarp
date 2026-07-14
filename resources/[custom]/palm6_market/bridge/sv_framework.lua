-- ============================================================================
-- palm6_market/bridge/sv_framework.lua
--
-- Framework adapter (server). The ONLY file in this resource that calls
-- qbx_core / ox_inventory exports or server-side game natives. server/main.lua
-- calls Bridge.* only, so its logic (the price engine + sell rules + our own
-- palm6_market_* SQL) ports to GTA VI by rewriting THIS FILE.
-- See docs/GTA6-READINESS.md (Section 3, the bridge pattern).
--
-- Item / cash / coords helpers are the exact shapes used by palm6_grind; the
-- Reply-to-panel helper is the shape used by palm6_help / palm6_economy.
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

-- Notify a player.
function Bridge.Notify(src, title, msg, t)
    TriggerClientEvent('ox_lib:notify', src, {
        title = title, description = msg, type = t or 'inform',
    })
end

-- How many of `item` the player holds. ox_inventory's documented count query.
function Bridge.CountItem(src, item)
    local ok, n = pcall(function() return exports.ox_inventory:Search(src, 'count', item) end)
    return (ok and tonumber(n)) or 0
end

-- Remove `count` of `item`. Returns true if removed.
function Bridge.RemoveItem(src, item, count)
    local ok, removed = pcall(function()
        return exports.ox_inventory:RemoveItem(src, item, count or 1)
    end)
    return ok and removed and true or false
end

-- Grant `count` of `item` to the player. Returns true if fully added. Used by
-- the refining tier (grant refined AFTER the raws are consumed).
function Bridge.AddItem(src, item, count)
    local ok, added = pcall(function()
        return exports.ox_inventory:AddItem(src, item, count or 1)
    end)
    return ok and added and true or false
end

-- Is `item` a registered ox_inventory item def? Boot presence-check so the
-- refinery self-disables loudly if a refined item was never added to
-- ox_inventory_overrides/data/items.lua (mirrors palm6_drugs).
function Bridge.HasItemDef(item)
    local ok, defs = pcall(function() return exports.ox_inventory:Items() end)
    return ok and defs and defs[item] ~= nil or false
end

-- Pay the player `amount` in cash. Returns true if applied.
function Bridge.AddCash(src, amount, reason)
    local p = getPlayer(src)
    if not p or not p.Functions then return false end
    p.Functions.AddMoney('cash', amount, reason)
    return true
end

-- Current coords of a player's ped as {x,y,z}, or nil. Anti-abuse proximity.
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

-- Reply to a command invoker: the console gets server prints, a player gets a
-- single branded palm6_ui panel instead of several lines dumped into chat.
function Bridge.Reply(src, lines)
    if src == 0 then
        for _, l in ipairs(lines) do print('[palm6_market] ' .. tostring(l)) end
        return
    end
    local c = Config.Panel.color
    TriggerClientEvent('palm6_ui:show', src, {
        tag = Config.Panel.tag, color = { c[1], c[2], c[3] }, lines = lines,
    })
end

-- Register a console/chat command (chat-visible false: no suggestion clutter).
function Bridge.RegisterCommand(name, handler)
    RegisterCommand(name, handler, false)
end
