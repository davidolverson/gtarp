-- ============================================================================
-- ox_inventory_overrides/client/render.lua
--
-- Server-side `exports.ox_inventory:RegisterShop` (modules/shops/server.lua
-- in v2.47.5) only registers a shop on the server. The client renderer in
-- ox_inventory's modules/shops/client.lua builds its shopTypes table once
-- from `lib.load('data.shops')` and never re-reads it, so our ExtraShops
-- never get blips or interaction surfaces from upstream.
--
-- This script reads the same ExtraShops table (loaded by data/shops.lua as
-- a shared_script before this file runs) and creates the interaction points
-- ourselves, mirroring upstream's renderer:
--   - shops with `locations` get a per-location interaction (ox_target sphere
--     when ox_target is started, else lib.points marker + E prompt)
--   - shops with `targets` get a per-target box zone (ox_target only)
--   - shops with `model` get a model-bound ox_target option
--   - optional `blip` on the shop adds a map blip per location/target
-- Each interaction opens the shop through the canonical client export
-- `exports.ox_inventory:openInventory('shop', { type = key, id = i })`.
-- ============================================================================

if not lib then return end

local function countKeys(t)
    local n = 0
    if type(t) == 'table' then
        for _ in pairs(t) do n = n + 1 end
    end
    return n
end

local shopCount = countKeys(ExtraShops)
if shopCount == 0 then
    print('[ox_inventory_overrides] client: ExtraShops empty; nothing to render')
    return
end

local hasTarget = GetResourceState('ox_target') == 'started'

local createdPoints = {}
local createdBlips  = {}
local createdZones  = {}
local createdModels = {}

local function openShop(shopType, locationId)
    exports.ox_inventory:openInventory('shop', {
        type = shopType,
        id   = locationId,
    })
end

local function makeBlip(coords, blipDef, shopName)
    if type(blipDef) ~= 'table' then return end
    local b = AddBlipForCoord(coords.x, coords.y, coords.z)
    SetBlipSprite(b, blipDef.id or 52)
    SetBlipColour(b, blipDef.colour or 0)
    SetBlipScale(b, blipDef.scale or 0.8)
    SetBlipAsShortRange(b, true)
    BeginTextCommandSetBlipName('STRING')
    AddTextComponentSubstringPlayerName(shopName or 'Shop')
    EndTextCommandSetBlipName(b)
    createdBlips[#createdBlips + 1] = b
end

local function addSphereTarget(shopType, locationId, coords, label, groups)
    local zoneId = exports.ox_target:addSphereZone({
        coords = coords,
        radius = 1.5,
        debug  = false,
        options = {
            {
                name     = ('ox_extra_shop_%s_%d'):format(shopType, locationId),
                icon     = 'fas fa-shopping-basket',
                label    = label,
                groups   = groups,
                onSelect = function() openShop(shopType, locationId) end,
                distance = 2.0,
            },
        },
    })
    createdZones[#createdZones + 1] = zoneId
end

local function addBoxTarget(shopType, locationId, target, label, groups)
    local coords = target.loc or target.coords
    if not coords then return end
    local height = (target.minZ and target.maxZ) and math.abs(target.maxZ - target.minZ) or 1.0
    if height < 0.2 then height = 1.0 end
    local zoneId = exports.ox_target:addBoxZone({
        coords   = coords,
        size     = vec3(target.length or 1.0, target.width or 1.0, height),
        rotation = target.heading or 0.0,
        debug    = false,
        options  = {
            {
                name     = ('ox_extra_shop_%s_%d'):format(shopType, locationId),
                icon     = 'fas fa-shopping-basket',
                label    = label,
                groups   = groups,
                onSelect = function() openShop(shopType, locationId) end,
                distance = target.distance or 2.0,
            },
        },
    })
    createdZones[#createdZones + 1] = zoneId
end

local function addModelTarget(shopType, models, label, groups)
    exports.ox_target:addModel(models, {
        {
            name     = ('ox_extra_shop_%s_model'):format(shopType),
            icon     = 'fas fa-shopping-basket',
            label    = label,
            groups   = groups,
            onSelect = function() openShop(shopType) end,
            distance = 2.0,
        },
    })
    createdModels[#createdModels + 1] = { shopType = shopType, models = models }
end

local function addMarkerPoint(shopType, locationId, coords)
    local point = lib.points.new({
        coords   = coords,
        distance = 16.0,
        invId    = locationId,
        invType  = shopType,
    })

    function point:nearby()
        DrawMarker(
            2,
            self.coords.x, self.coords.y, self.coords.z + 0.5,
            0.0, 0.0, 0.0,
            0.0, 0.0, 0.0,
            0.3, 0.3, 0.3,
            255, 255, 255, 200,
            false, true, 2, false, nil, nil, false
        )
        if self.currentDistance < 1.5 then
            BeginTextCommandDisplayHelp('STRING')
            AddTextComponentSubstringPlayerName('Press ~INPUT_CONTEXT~ to open shop')
            EndTextCommandDisplayHelp(0, false, true, -1)
            if IsControlJustReleased(0, 38) then -- E
                openShop(self.invType, self.invId)
            end
        end
    end

    createdPoints[#createdPoints + 1] = point
end

local function addLocationInteraction(shopType, locationId, coords, label, groups)
    if hasTarget then
        addSphereTarget(shopType, locationId, coords, label, groups)
    else
        addMarkerPoint(shopType, locationId, coords)
    end
end

local function build()
    local rendered = 0
    for shopType, shop in pairs(ExtraShops) do
        local label = ('Open %s'):format(shop.name or shopType)

        if shop.locations then
            for i, coords in ipairs(shop.locations) do
                addLocationInteraction(shopType, i, coords, label, shop.groups)
                makeBlip(coords, shop.blip, shop.name)
            end
            rendered = rendered + 1
        elseif shop.targets then
            if hasTarget then
                for i, target in ipairs(shop.targets) do
                    addBoxTarget(shopType, i, target, label, shop.groups)
                    makeBlip(target.loc or target.coords, shop.blip, shop.name)
                end
                rendered = rendered + 1
            else
                print(('[ox_inventory_overrides] client: shop %s uses targets but ox_target is not started; skipping')
                    :format(shopType))
            end
        elseif shop.model then
            if hasTarget then
                addModelTarget(shopType, shop.model, label, shop.groups)
                rendered = rendered + 1
            else
                print(('[ox_inventory_overrides] client: shop %s uses model targets but ox_target is not started; skipping')
                    :format(shopType))
            end
        else
            print(('[ox_inventory_overrides] client: shop %s has no locations/targets/model; skipping')
                :format(shopType))
        end
    end
    return rendered
end

local function cleanup()
    for _, p in ipairs(createdPoints) do
        if p and p.remove then p:remove() end
    end
    createdPoints = {}
    for _, b in ipairs(createdBlips) do
        if b and DoesBlipExist(b) then RemoveBlip(b) end
    end
    createdBlips = {}
    if hasTarget then
        for _, zid in ipairs(createdZones) do
            if zid then exports.ox_target:removeZone(zid) end
        end
        for _, m in ipairs(createdModels) do
            exports.ox_target:removeModel(m.models, ('ox_extra_shop_%s_model'):format(m.shopType))
        end
    end
    createdZones  = {}
    createdModels = {}
end

AddEventHandler('onResourceStart', function(resource)
    if resource ~= GetCurrentResourceName() then return end
    local n = build()
    print(('[ox_inventory_overrides] client: rendered interactions for %d/%d shops (ox_target=%s)')
        :format(n, shopCount, tostring(hasTarget)))
end)

AddEventHandler('onResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() then return end
    cleanup()
end)
