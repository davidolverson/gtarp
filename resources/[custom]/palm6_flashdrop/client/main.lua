-- ============================================================================
-- palm6_flashdrop/client/main.lua
--
-- Pure logic. Calls Game.* (bridge/cl_game.lua) for all native access.
-- No direct natives here (§6 gate). The server is authoritative on every
-- gate — stock, serials, prices, distances, timers; this file is prompts,
-- blips, menus, and the checkout progress flow.
--
-- Perf: zero unconditional per-frame loops. Static interactions are
-- event-driven target zones (or 16m-gated marker points without ox_target);
-- drop-site dressing exists only between reveal and close.
-- ============================================================================

-- Dynamic drop-site state (reveal -> closed).
local dyn = { blip = nil, prop = nil, zone = nil }

-- Static world state (whole session).
local static = { handles = {}, peds = {}, blips = {} }

local function cleanupDynamic()
    Game.RemoveBlip(dyn.blip)
    Game.RemoveInteraction(dyn.zone)
    Game.DeleteProp(dyn.prop)
    dyn = { blip = nil, prop = nil, zone = nil }
end

-- ---------------------------------------------------------------------------
-- Drop-day stage flow
-- ---------------------------------------------------------------------------
local function buildDropSite(payload)
    cleanupDynamic()  -- idempotent for late-join sync + broadcast overlap
    dyn.blip = Game.CreateDropBlip(payload.coords, ('Flash Drop: %s'):format(payload.catalogLabel))
    if Config.DropProp.enabled then
        dyn.prop = Game.SpawnProp(Config.DropProp.model, payload.coords, Config.DropProp.zOffset)
    end
    dyn.zone = Game.CreateInteraction('drop_table', payload.coords,
        ('Claim %s ($%d)'):format(payload.catalogLabel, payload.retail),
        'fas fa-shoe-prints',
        function() TriggerServerEvent('palm6_flashdrop:startCheckout') end)
end

RegisterNetEvent('palm6_flashdrop:stage', function(payload)
    if not payload or not payload.stage then return end

    if payload.stage == 'hint' then
        Game.Announce('👟 FLASH DROP INCOMING',
            ('%s — %d pairs at $%d. Doors in ~%d min.\n"%s"')
            :format(payload.catalogLabel, payload.cap, payload.retail, payload.minutes or 0, payload.riddle or ''),
            'inform')
    elseif payload.stage == 'reveal' then
        buildDropSite(payload)
        local msg = ('%s at %s — %ds until doors.'):format(payload.catalogLabel, payload.locationLabel, payload.seconds or 0)
        if payload.turfCallout then msg = msg .. ' ' .. payload.turfCallout end
        Game.Announce('📍 DROP LOCATION LEAKED', msg, 'warning')
    elseif payload.stage == 'live' then
        if not dyn.zone then buildDropSite(payload) end  -- late join straight into live
        Game.Announce('🔥 DOORS OPEN',
            ('%s is live at %s. One per person. Watch your back walking out.')
            :format(payload.catalogLabel, payload.locationLabel), 'success')
    elseif payload.stage == 'closed' then
        cleanupDynamic()
    end
end)

-- The 8 exposed seconds. Cancel (or getting shot off the bar) frees the
-- reservation for the next person in line.
RegisterNetEvent('palm6_flashdrop:beginCheckout', function(seconds)
    if Game.ProgressBar('Checking out — do not get robbed', (seconds or 8) * 1000) then
        TriggerServerEvent('palm6_flashdrop:finishCheckout')
    else
        TriggerServerEvent('palm6_flashdrop:cancelCheckout')
        Game.Notify({ title = 'Flash Drop', description = 'You stepped out of line.', type = 'error' })
    end
end)

-- ---------------------------------------------------------------------------
-- Consignment / fence / bench menus (data arrives from the server; menus
-- only ever display it — every selection is re-validated server-side)
-- ---------------------------------------------------------------------------
local function openConsignMain()
    Game.OpenMenu('flashdrop_consign', 'SoleWorth Consignment', {
        { title = 'Browse the shelf', description = 'Serialized pairs, verified authentic', icon = 'fas fa-shoe-prints',
          onSelect = function() TriggerServerEvent('palm6_flashdrop:consign:browse') end },
        { title = 'Consign a pair', description = ('House keeps %d%% of the sale'):format(math.floor(Config.Consignment.FeePct * 100)), icon = 'fas fa-tags',
          onSelect = function() TriggerServerEvent('palm6_flashdrop:consign:pairs', 'sell') end },
        { title = 'My listings', description = 'Reprice by cancel + relist', icon = 'fas fa-list',
          onSelect = function() TriggerServerEvent('palm6_flashdrop:consign:myListings') end },
        { title = ('Legit check ($%d)'):format(Config.LegitCheck.Fee), description = 'Registry verdict + provenance tape', icon = 'fas fa-magnifying-glass',
          onSelect = function() TriggerServerEvent('palm6_flashdrop:consign:pairs', 'legit') end },
        { title = 'Report a pair stolen', description = 'Flags the serial dirty forever', icon = 'fas fa-triangle-exclamation',
          onSelect = function() TriggerServerEvent('palm6_flashdrop:reportMenu') end },
    })
end

local menuBuilders = {}

function menuBuilders.browse(data)
    if #data == 0 then
        Game.Notify({ title = 'SoleWorth', description = 'Shelf is empty. Come back after a drop.', type = 'inform' })
        return
    end
    local options = {}
    for _, l in ipairs(data) do
        options[#options + 1] = {
            title = ('%s [%s]'):format(l.label, l.serial),
            description = ('$%d — consigned by %s'):format(l.price, l.seller),
            icon = 'fas fa-shoe-prints',
            onSelect = function() TriggerServerEvent('palm6_flashdrop:consign:buy', l.id) end,
        }
    end
    Game.OpenMenu('flashdrop_browse', 'The Shelf', options)
end

function menuBuilders.sellPairs(data)
    if #data == 0 then
        Game.Notify({ title = 'SoleWorth', description = 'You are not holding any pairs.', type = 'inform' })
        return
    end
    local options = {}
    for _, p in ipairs(data) do
        options[#options + 1] = {
            title = ('%s [%s]'):format(p.label, p.serial),
            description = 'Set an asking price',
            icon = 'fas fa-tags',
            onSelect = function()
                local price = Game.InputNumber('Consign ' .. p.serial, 'Asking price ($)',
                    Config.Consignment.MinPrice, 1000000, nil)
                if price then TriggerServerEvent('palm6_flashdrop:consign:list', p.uid, price) end
            end,
        }
    end
    Game.OpenMenu('flashdrop_sell', 'Consign a Pair', options)
end

function menuBuilders.legitPairs(data)
    if #data == 0 then
        Game.Notify({ title = 'SoleWorth', description = 'Nothing to check — pockets are empty.', type = 'inform' })
        return
    end
    local options = {}
    for _, p in ipairs(data) do
        options[#options + 1] = {
            title = ('%s [%s]'):format(p.label, p.serial),
            description = ('Check authenticity ($%d)'):format(Config.LegitCheck.Fee),
            icon = 'fas fa-magnifying-glass',
            onSelect = function() TriggerServerEvent('palm6_flashdrop:legit:start', p.uid) end,
        }
    end
    Game.OpenMenu('flashdrop_legit', 'Legit Check', options)
end

function menuBuilders.myListings(data)
    if #data == 0 then
        Game.Notify({ title = 'SoleWorth', description = 'You have nothing on the shelf.', type = 'inform' })
        return
    end
    local options = {}
    for _, l in ipairs(data) do
        options[#options + 1] = {
            title = ('%s [%s] — $%d'):format(l.label, l.serial, l.price),
            description = 'Select to pull this listing',
            icon = 'fas fa-rotate-left',
            onSelect = function() TriggerServerEvent('palm6_flashdrop:consign:cancel', l.id) end,
        }
    end
    Game.OpenMenu('flashdrop_mylistings', 'My Listings', options)
end

function menuBuilders.report(data)
    if #data == 0 then
        Game.Notify({ title = 'SoleWorth', description = 'The registry shows nothing of yours missing.', type = 'inform' })
        return
    end
    local options = {}
    for _, p in ipairs(data) do
        options[#options + 1] = {
            title = ('%s [%s]'):format(p.label, p.serial),
            description = 'Report stolen — flags the serial DIRTY, permanently',
            icon = 'fas fa-triangle-exclamation',
            onSelect = function() TriggerServerEvent('palm6_flashdrop:reportStolen', p.uid) end,
        }
    end
    Game.OpenMenu('flashdrop_report', 'Report Stolen', options)
end

function menuBuilders.fence(data)
    if #data == 0 then
        Game.Notify({ title = 'Fence', description = '"You got nothing I want."', type = 'inform' })
        return
    end
    local options = {}
    for _, p in ipairs(data) do
        options[#options + 1] = {
            title = ('%s [%s] — $%d'):format(p.label, p.serial, p.offer),
            description = p.remark,
            icon = 'fas fa-hand-holding-dollar',
            onSelect = function() TriggerServerEvent('palm6_flashdrop:fence:sell', p.uid) end,
        }
    end
    Game.OpenMenu('flashdrop_fence', 'The Fence', options)
end

function menuBuilders.craft(data)
    if #data == 0 then
        Game.Notify({ title = 'Workbench', description = 'No drops have hit the street yet — nothing to copy.', type = 'inform' })
        return
    end
    local options = {}
    for _, d in ipairs(data) do
        options[#options + 1] = {
            title = d.label,
            description = ('Fake it for $%d — street value $%d if nobody checks'):format(Config.Counterfeit.CraftCost, d.retail),
            icon = 'fas fa-hammer',
            onSelect = function() TriggerServerEvent('palm6_flashdrop:craft:start', d.dropId) end,
        }
    end
    Game.OpenMenu('flashdrop_craft', 'Counterfeit Bench', options)
end

RegisterNetEvent('palm6_flashdrop:menuData', function(kind, data)
    local builder = menuBuilders[kind]
    if builder then builder(data or {}) end
end)

RegisterNetEvent('palm6_flashdrop:beginCraft', function(seconds, label)
    if Game.ProgressBar(('Faking a pair of %s'):format(label or 'sneakers'), (seconds or 12) * 1000) then
        TriggerServerEvent('palm6_flashdrop:craft:finish')
    else
        TriggerServerEvent('palm6_flashdrop:craft:cancel')
    end
end)

RegisterNetEvent('palm6_flashdrop:beginLegit', function(uid)
    local passed = Game.SkillCheck(Config.LegitCheck.Difficulty)
    TriggerServerEvent('palm6_flashdrop:legit:finish', uid, passed)
end)

RegisterNetEvent('palm6_flashdrop:report', function(title, content)
    Game.ShowReport(title, content)
end)

-- ---------------------------------------------------------------------------
-- Static world setup / teardown
-- ---------------------------------------------------------------------------
CreateThread(function()
    Wait(1000)

    -- SoleWorth consignment
    static.peds[#static.peds + 1] =
        Game.SpawnPed(Config.Consignment.PedModel, Config.Consignment.Coords, Config.Consignment.PedHeading)
    if Config.Consignment.Blip.enabled then
        static.blips[#static.blips + 1] =
            Game.CreateShopBlip(Config.Consignment.Coords, Config.Consignment.Blip)
    end
    static.handles[#static.handles + 1] = Game.CreateInteraction(
        'consign', Config.Consignment.Coords, 'Talk to the consignor', 'fas fa-store', openConsignMain)

    -- The fence
    static.peds[#static.peds + 1] =
        Game.SpawnPed(Config.Fence.PedModel, Config.Fence.Coords, Config.Fence.PedHeading)
    if Config.Fence.Blip and Config.Fence.Blip.enabled then
        static.blips[#static.blips + 1] = Game.CreateShopBlip(Config.Fence.Coords, Config.Fence.Blip)
    end
    static.handles[#static.handles + 1] = Game.CreateInteraction(
        'fence', Config.Fence.Coords, 'See the fence', 'fas fa-user-secret',
        function() TriggerServerEvent('palm6_flashdrop:fence:menu') end)

    -- Counterfeit bench
    static.handles[#static.handles + 1] = Game.CreateInteraction(
        'bench', Config.Counterfeit.Coords, 'Use the workbench', 'fas fa-hammer',
        function() TriggerServerEvent('palm6_flashdrop:craft:menu') end)

    -- Catch up on any drop already in flight.
    TriggerServerEvent('palm6_flashdrop:requestSync')
end)

AddEventHandler('onResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() then return end
    cleanupDynamic()
    for _, h in ipairs(static.handles) do Game.RemoveInteraction(h) end
    for _, p in ipairs(static.peds) do Game.DeletePed(p) end
    for _, b in ipairs(static.blips) do Game.RemoveBlip(b) end
end)
