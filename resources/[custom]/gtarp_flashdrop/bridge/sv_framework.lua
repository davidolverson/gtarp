-- ============================================================================
-- gtarp_flashdrop/bridge/sv_framework.lua
--
-- Framework adapter (server). The ONLY file in this resource that touches
-- qbx_core (identity, money), ox_inventory (item registration, metadata
-- items, per-slot removal), ox_lib notifications, or server-side game
-- natives. The drop lifecycle, serial registry, consignment/fence/legit
-- rules all live in server/main.lua and call Bridge.* only. To port to
-- GTA VI, rewrite THIS FILE. See docs/GTA6-READINESS.md (Section 3).
-- ============================================================================

Bridge = {}

-- Resolve the framework player object for a server source, or nil.
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
    if not p or not p.PlayerData then return nil end
    return p.PlayerData.citizenid
end

-- RP display name for a source (drop tape / listings attribution).
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

-- ---------------------------------------------------------------------------
-- Money. Drop-table and fence business is cash; consignment sellers get
-- paid to bank so payouts survive them being offline.
-- ---------------------------------------------------------------------------

-- Cash on hand for an online source (0 if not loaded). Used to refuse a
-- checkout reservation the claimant could never pay for.
function Bridge.GetCashBalance(src)
    local p = getPlayer(src)
    if not p or not p.PlayerData or not p.PlayerData.money then return 0 end
    return p.PlayerData.money.cash or 0
end

-- Debit `amount` cash from the source. Returns true on success (affordability
-- checked by the framework's RemoveMoney).
function Bridge.ChargeCash(src, amount, reason)
    local p = getPlayer(src)
    if not p or not p.Functions then return false end
    if (p.PlayerData.money and p.PlayerData.money.cash or 0) < amount then return false end
    return p.Functions.RemoveMoney('cash', amount, reason) and true or false
end

-- Pay the source `amount` in cash. Returns true if applied.
function Bridge.AddCash(src, amount, reason)
    local p = getPlayer(src)
    if not p or not p.Functions then return false end
    p.Functions.AddMoney('cash', amount, reason)
    return true
end

-- Credit `amount` to a character's bank by citizenid. Online: framework
-- money API. Offline: direct write against the qbx players.money JSON so a
-- consignment payout is never lost. This is the only place that JSON shape
-- is known (same pattern as gtarp_courier).
function Bridge.CreditBankByCitizenId(citizenid, amount, reason)
    for _, src in ipairs(GetPlayers()) do
        src = tonumber(src)
        local p = getPlayer(src)
        if p and p.PlayerData.citizenid == citizenid then
            p.Functions.AddMoney('bank', amount, reason)
            return true
        end
    end
    MySQL.update.await(
        "UPDATE players SET money = JSON_SET(money, '$.bank', CAST(JSON_EXTRACT(money,'$.bank') AS UNSIGNED) + ?) WHERE citizenid = ?",
        { amount, citizenid }
    )
    return true
end

-- ---------------------------------------------------------------------------
-- Inventory (ox_inventory). Serialized pairs are ONE base item with per-pair
-- metadata: { uid, serial, label, description }. `uid` is the opaque registry
-- key — identical in shape on real and fake pairs, so nothing in the client
-- inventory betrays a counterfeit.
-- ---------------------------------------------------------------------------

-- Ensure our base item is known to ox_inventory. IMPORTANT: cross-resource
-- Lua export return values are msgpack-serialized, so the table returned by
-- exports.ox_inventory:Items() is a COPY — writing into it does NOT reach
-- ox_inventory's own ItemList. The item must be registered declaratively
-- (ox_inventory_overrides/data/items.lua ExtraItems ships it). This function
-- is therefore a PRESENCE CHECK: it attempts the legacy runtime merge as a
-- best effort, then trusts only a fresh per-name lookup. Returns true only
-- when ox_inventory can actually resolve the item (i.e. AddItem will work).
function Bridge.RegisterItem(name, def)
    local function lookup()
        local ok, item = pcall(function() return exports.ox_inventory:Items(name) end)
        return ok and item ~= nil
    end

    if lookup() then return true end  -- registered declaratively; done

    -- Best-effort runtime merge for setups where the export exposes a live
    -- table. Never trusted — verified by the fresh lookup below.
    pcall(function()
        local items = exports.ox_inventory:Items()
        if type(items) == 'table' and not items[name] then
            items[name] = { label = def.label, weight = def.weight, stack = def.stack }
        end
    end)

    if lookup() then return true end

    print(('^1[gtarp_flashdrop] FATAL: item %q is NOT registered with ox_inventory. '
        .. 'Runtime item merge cannot reach ox_inventory (export tables are copies). '
        .. 'Add it declaratively — ox_inventory_overrides/data/items.lua ExtraItems '
        .. 'or ox_inventory/data/items.lua — and restart. Drops and the counterfeit '
        .. 'bench are disabled until then.^0'):format(name))
    return false
end

-- Give one serialized pair. Returns true if it fit in the inventory.
function Bridge.GivePair(src, item, metadata)
    local ok, added = pcall(function()
        return exports.ox_inventory:AddItem(src, item, 1, metadata)
    end)
    return ok and added and true or false
end

-- All pairs in a player's inventory as { {uid=..., slot=...}, ... }.
function Bridge.ListPairs(src, item)
    local ok, slots = pcall(function()
        return exports.ox_inventory:GetSlotsWithItem(src, item)
    end)
    local out = {}
    if ok and type(slots) == 'table' then
        for _, s in ipairs(slots) do
            local uid = s.metadata and s.metadata.uid
            if uid then out[#out + 1] = { uid = uid, slot = s.slot } end
        end
    end
    return out
end

-- Does the player hold the pair with this uid? Returns its slot, or nil.
function Bridge.FindPairSlot(src, item, uid)
    for _, pair in ipairs(Bridge.ListPairs(src, item)) do
        if pair.uid == uid then return pair.slot end
    end
    return nil
end

-- Remove the pair sitting in `slot`. Returns true if removed.
function Bridge.RemovePairBySlot(src, item, slot)
    local ok, removed = pcall(function()
        return exports.ox_inventory:RemoveItem(src, item, 1, nil, slot)
    end)
    return ok and removed and true or false
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

-- Connected player count (scheduler's MinPlayers gate).
function Bridge.PlayerCount()
    return #GetPlayers()
end

-- ---------------------------------------------------------------------------
-- Notifications
-- ---------------------------------------------------------------------------

-- Notify one player (src 0 = server console).
function Bridge.Notify(src, title, msg, t)
    if src == 0 then
        print(('[gtarp_flashdrop] %s: %s'):format(title, msg))
        return
    end
    TriggerClientEvent('ox_lib:notify', src, {
        title = title, description = msg, type = t or 'inform',
    })
end

-- Notify everyone (drop hype broadcasts).
function Bridge.NotifyAll(title, msg, t)
    TriggerClientEvent('ox_lib:notify', -1, {
        title = title, description = msg, type = t or 'inform',
        duration = 10000,
    })
end
