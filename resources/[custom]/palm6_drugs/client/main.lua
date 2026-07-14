-- ============================================================================
-- palm6_drugs/client/main.lua
--
-- Pure logic: the ox_target interactions and ox_lib menus for the grow plots,
-- the mixing station, and the NPC street-buyer. All natives + ox_lib UI go
-- through Game.* (bridge/cl_game.lua). To port to GTA VI, rewrite the bridge,
-- not this file. See docs/GTA6-READINESS.md.
--
-- The server does NOT trust anything sent from here — plot indices, base slot
-- indices, additive names, brand text, and sold quantities are all re-derived
-- or re-validated server-side. Menus only DISPLAY the server's snapshot and
-- REQUEST an action; progress bars are cosmetic.
-- ============================================================================

local handles = {}   -- interaction handles (grow plots, station, buyer, dealer)
local buyerPed = nil
local dealerPed = nil

local function effectsText(effects)
    if type(effects) ~= 'table' or #effects == 0 then return 'No effects' end
    return table.concat(effects, ', ')
end

-- ---------------------------------------------------------------------------
-- GROW — plot menu (state comes from the server)
-- ---------------------------------------------------------------------------
RegisterNetEvent('palm6_drugs:plotMenuData', function(d)
    if not d then return end
    local idx = d.plotIndex

    if d.state == 'empty' then
        if #(d.strains or {}) == 0 then
            Game.Notify({ title = 'Grow', description = 'You have not unlocked any strains to plant yet.', type = 'inform' })
            return
        end
        local options = {}
        for _, strain in ipairs(d.strains) do
            options[#options + 1] = {
                title = strain.label,
                description = 'Plant this strain here',
                icon = 'fas fa-seedling',
                onSelect = function()
                    -- Pick the grow additive (or none), then plant.
                    local addOpts = {
                        {
                            title = 'No additive',
                            description = 'Standard quality',
                            icon = 'fas fa-circle',
                            onSelect = function()
                                if Game.ProgressBar('Planting…', (Config.Grow.plantSeconds or 4) * 1000) then
                                    TriggerServerEvent('palm6_drugs:plant', idx, strain.id)
                                end
                            end,
                        },
                    }
                    for _, ga in ipairs(d.growAdditives or {}) do
                        addOpts[#addOpts + 1] = {
                            title = ('%s (%d)'):format(ga.label, ga.count),
                            description = 'Consumed to change quality / yield / speed',
                            icon = 'fas fa-flask',
                            onSelect = function()
                                if Game.ProgressBar('Planting…', (Config.Grow.plantSeconds or 4) * 1000) then
                                    TriggerServerEvent('palm6_drugs:plant', idx, strain.id, ga.id)
                                end
                            end,
                        }
                    end
                    Game.OpenMenu('palm6_drugs_plant_additive', ('Plant %s'):format(strain.label), addOpts, 'palm6_drugs_plot')
                end,
            }
        end
        Game.OpenMenu('palm6_drugs_plot', 'Empty Plot', options)
        return
    end

    if d.state == 'growing' then
        local options = {
            {
                title = ('%s — growing'):format(d.strainLabel or 'Plant'),
                description = ('Water: %d%% · ready in ~%d min'):format(
                    d.waterPct or 0, math.max(1, math.floor((d.secondsLeft or 0) / 60))),
                icon = 'fas fa-hourglass-half',
                disabled = true,
            },
        }
        if d.owner then
            options[#options + 1] = {
                title = 'Water the plant',
                description = 'Keep it above 0% or quality suffers',
                icon = 'fas fa-droplet',
                onSelect = function()
                    if Game.ProgressBar('Watering…', (Config.Grow.waterSeconds or 3) * 1000) then
                        TriggerServerEvent('palm6_drugs:water', idx)
                    end
                end,
            }
        else
            options[#options + 1] = {
                title = 'Not your plant',
                description = 'Only the grower can tend it',
                icon = 'fas fa-ban',
                disabled = true,
            }
        end
        Game.OpenMenu('palm6_drugs_plot', 'Cannabis Plant', options)
        return
    end

    if d.state == 'ready' then
        local options = {
            {
                title = ('%s — ready'):format(d.strainLabel or 'Plant'),
                icon = 'fas fa-cannabis',
                disabled = true,
            },
        }
        if d.owner then
            options[#options + 1] = {
                title = 'Harvest',
                description = 'Collect the buds',
                icon = 'fas fa-scissors',
                onSelect = function()
                    if Game.ProgressBar('Harvesting…', (Config.Grow.harvestSeconds or 6) * 1000) then
                        TriggerServerEvent('palm6_drugs:harvest', idx)
                    end
                end,
            }
        else
            options[#options + 1] = {
                title = 'Not your plant',
                icon = 'fas fa-ban',
                disabled = true,
            }
        end
        Game.OpenMenu('palm6_drugs_plot', 'Cannabis Plant', options)
    end
end)

-- ---------------------------------------------------------------------------
-- MIX — station menu (bases / additives / saved recipes)
-- ---------------------------------------------------------------------------
RegisterNetEvent('palm6_drugs:mixMenuData', function(d)
    if not d then return end

    if #(d.bases or {}) == 0 then
        Game.Notify({ title = 'Mixing', description = 'You have no buds or product to mix.', type = 'inform' })
        return
    end

    local options = {}
    for _, base in ipairs(d.bases) do
        options[#options + 1] = {
            title = ('%s [%s] x%d'):format(base.label, Config.QualityLabel(base.quality), base.count),
            description = effectsText(base.effects),
            icon = base.kind == 'product' and 'fas fa-box' or 'fas fa-cannabis',
            onSelect = function()
                local sub = {}
                -- Saved recipes first (one-click repeat).
                for _, r in ipairs(d.recipes or {}) do
                    sub[#sub + 1] = {
                        title = ('★ %s'):format(r.brand),
                        description = ('Saved recipe (%s)'):format(r.baseLabel or r.base),
                        icon = 'fas fa-rotate-right',
                        onSelect = function()
                            if Game.ProgressBar('Mixing…', (Config.Mix.seconds or 5) * 1000) then
                                TriggerServerEvent('palm6_drugs:mixRecipe', base.slot, r.id)
                            end
                        end,
                    }
                end
                -- Then each held additive.
                if #(d.additives or {}) == 0 then
                    sub[#sub + 1] = {
                        title = 'No additives on you',
                        description = 'Buy additives to create effects',
                        icon = 'fas fa-ban',
                        disabled = true,
                    }
                end
                for _, add in ipairs(d.additives or {}) do
                    sub[#sub + 1] = {
                        title = ('%s (%d)'):format(add.label, add.count),
                        description = ('Adds: %s'):format(add.effect),
                        icon = 'fas fa-flask',
                        onSelect = function()
                            local brand = Game.InputText('Name your product', 'Brand name',
                                Config.Mix.brandMaxLen, 'e.g. Green Crack Deluxe')
                            if not brand then return end
                            if Game.ProgressBar('Mixing…', (Config.Mix.seconds or 5) * 1000) then
                                TriggerServerEvent('palm6_drugs:mix', base.slot, add.id, brand)
                            end
                        end,
                    }
                end
                Game.OpenMenu('palm6_drugs_mix_additive', 'Add one', sub, 'palm6_drugs_mix_base')
            end,
        }
    end
    Game.OpenMenu('palm6_drugs_mix_base', 'Mixing Station — pick a base', options)
end)

-- ---------------------------------------------------------------------------
-- SELL — the NPC street-buyer
-- ---------------------------------------------------------------------------
RegisterNetEvent('palm6_drugs:sellMenuData', function(d)
    if not d then return end
    if #(d.offers or {}) == 0 then
        Game.Notify({ title = Config.Sell.label, description = 'You have nothing this buyer wants.', type = 'inform' })
        return
    end

    local options = {
        {
            title = ('Buyer will pay up to $%d more today'):format(d.dailyRemaining or 0),
            description = 'Real players usually pay better — this is the quick faucet',
            icon = 'fas fa-sack-dollar',
            disabled = true,
        },
    }
    for _, o in ipairs(d.offers) do
        options[#options + 1] = {
            title = ('Sell %s x%d — $%d'):format(o.label, o.count, o.total),
            description = ('$%d each (%s)'):format(o.unit, Config.QualityLabel(o.quality)),
            icon = 'fas fa-hand-holding-dollar',
            onSelect = function()
                TriggerServerEvent('palm6_drugs:sell', o.slot, o.item)
            end,
        }
    end
    Game.OpenMenu('palm6_drugs_sell', Config.Sell.label, options)
end)

-- ---------------------------------------------------------------------------
-- DRY — the drying rack (state comes from the server; buds dry to Heavenly)
-- ---------------------------------------------------------------------------
RegisterNetEvent('palm6_drugs:dryMenuData', function(d)
    if not d then return end

    local options = {
        {
            title = 'Drying Rack — Heavenly tier',
            description = ('Hang fresh buds ~%d min to dry them to Heavenly (×1.30)'):format(d.dryMinutes or 30),
            icon = 'fas fa-wind',
            disabled = true,
        },
    }

    for _, slot in ipairs(d.slots or {}) do
        if slot.state == 'empty' then
            options[#options + 1] = {
                title = ('Slot %d — empty'):format(slot.index),
                description = 'Hang a stack of fresh buds to dry',
                icon = 'fas fa-plus',
                onSelect = function()
                    local sub = {}
                    for _, b in ipairs(d.freshBuds or {}) do
                        sub[#sub + 1] = {
                            title = ('%s [%s] x%d'):format(b.label, Config.QualityLabel(b.quality), b.count),
                            description = 'Hang this whole stack to dry → Heavenly',
                            icon = 'fas fa-cannabis',
                            onSelect = function()
                                if Game.ProgressBar('Hanging buds…', (Config.Dry.loadSeconds or 4) * 1000) then
                                    TriggerServerEvent('palm6_drugs:dryStart', slot.index, b.slot)
                                end
                            end,
                        }
                    end
                    if #sub == 0 then
                        sub[#sub + 1] = {
                            title = 'No fresh buds on you',
                            description = 'Harvest a plant first — dried buds cannot be re-dried',
                            icon = 'fas fa-ban',
                            disabled = true,
                        }
                    end
                    Game.OpenMenu('palm6_drugs_dry_load', ('Slot %d — hang buds'):format(slot.index), sub, 'palm6_drugs_dry')
                end,
            }
        elseif slot.state == 'drying' then
            options[#options + 1] = {
                title = ('Slot %d — %s drying'):format(slot.index, slot.strainLabel or 'Buds'),
                description = ('Ready in ~%d min'):format(math.max(1, math.floor((slot.secondsLeft or 0) / 60))),
                icon = 'fas fa-hourglass-half',
                disabled = true,
            }
        elseif slot.state == 'ready' then
            if slot.owner then
                options[#options + 1] = {
                    title = ('Slot %d — %s dried!'):format(slot.index, slot.strainLabel or 'Buds'),
                    description = 'Collect your Heavenly buds',
                    icon = 'fas fa-cannabis',
                    onSelect = function()
                        if Game.ProgressBar('Taking down buds…', (Config.Dry.collectSeconds or 4) * 1000) then
                            TriggerServerEvent('palm6_drugs:dryCollect', slot.index)
                        end
                    end,
                }
            else
                options[#options + 1] = {
                    title = ('Slot %d — in use'):format(slot.index),
                    description = 'Only the owner can take these down',
                    icon = 'fas fa-ban',
                    disabled = true,
                }
            end
        end
    end

    Game.OpenMenu('palm6_drugs_dry', 'Drying Rack', options)
end)

-- ---------------------------------------------------------------------------
-- COOK — the meth lab (§9). 3 burners; all state comes from the server. The
-- player picks a pseudo stack (its grade sets the quality floor); acid + red
-- phosphorus are auto-consumed server-side. Cooking is loud (server heat).
-- ---------------------------------------------------------------------------
RegisterNetEvent('palm6_drugs:cookMenuData', function(d)
    if not d then return end

    local haveAcid = (d.acid or 0) > 0
    local haveRedP = (d.redP or 0) > 0
    local canLoad  = d.rankOk and (d.liveCooks or 0) < (d.maxCooks or 2)

    local options = {
        {
            title = Config.Cook.label,
            description = ('Crystal in ~%d min · Acid %d · Red P %d · cooks %d/%d'):format(
                d.cookMinutes or 20, d.acid or 0, d.redP or 0, d.liveCooks or 0, d.maxCooks or 2),
            icon = 'fas fa-fire',
            disabled = true,
        },
    }

    for _, slot in ipairs(d.slots or {}) do
        if slot.state == 'empty' then
            options[#options + 1] = {
                title = ('Burner %d — idle'):format(slot.index),
                description = canLoad and 'Load pseudo + acid + red phosphorus to cook'
                    or (not d.rankOk and 'You are not experienced enough to cook'
                        or 'You already have too many cooks going'),
                icon = 'fas fa-plus',
                disabled = not canLoad,
                onSelect = canLoad and function()
                    local sub = {}
                    for _, p in ipairs(d.pseudo or {}) do
                        sub[#sub + 1] = {
                            title = ('Pseudo (grade %d) x%d'):format(p.grade or 1, p.count),
                            description = (haveAcid and haveRedP)
                                and 'Start a cook with this pseudo' or 'You are missing acid or red phosphorus',
                            icon = 'fas fa-flask',
                            disabled = not (haveAcid and haveRedP),
                            onSelect = function()
                                if Game.ProgressBar('Loading the burner…', (Config.Cook.loadSeconds or 5) * 1000) then
                                    TriggerServerEvent('palm6_drugs:cookStart', slot.index, p.slot)
                                end
                            end,
                        }
                    end
                    if #sub == 0 then
                        sub[#sub + 1] = {
                            title = 'No pseudo on you',
                            description = 'Get pseudoephedrine (plus acid + red phosphorus) first',
                            icon = 'fas fa-ban',
                            disabled = true,
                        }
                    end
                    Game.OpenMenu('palm6_drugs_cook_load', ('Burner %d — load'):format(slot.index), sub, 'palm6_drugs_cook')
                end or nil,
            }
        elseif slot.state == 'cooking' then
            options[#options + 1] = {
                title = ('Burner %d — cooking'):format(slot.index),
                description = ('Ready in ~%d min'):format(math.max(1, math.floor((slot.secondsLeft or 0) / 60))),
                icon = 'fas fa-hourglass-half',
                disabled = true,
            }
        elseif slot.state == 'ready' then
            if slot.owner then
                options[#options + 1] = {
                    title = ('Burner %d — batch ready!'):format(slot.index),
                    description = 'Bag the crystal',
                    icon = 'fas fa-vial',
                    onSelect = function()
                        if Game.ProgressBar('Bagging the crystal…', (Config.Cook.collectSeconds or 5) * 1000) then
                            TriggerServerEvent('palm6_drugs:cookCollect', slot.index)
                        end
                    end,
                }
            else
                options[#options + 1] = {
                    title = ('Burner %d — in use'):format(slot.index),
                    description = 'Only the cook can bag this batch',
                    icon = 'fas fa-ban',
                    disabled = true,
                }
            end
        end
    end

    Game.OpenMenu('palm6_drugs_cook', Config.Cook.label, options)
end)

-- ---------------------------------------------------------------------------
-- DEALER — the NPC corner dealer (passive faucet; all state from the server)
-- ---------------------------------------------------------------------------
RegisterNetEvent('palm6_drugs:dealerMenuData', function(d)
    if not d then return end

    if not d.hired then
        Game.OpenMenu('palm6_drugs_dealer', Config.Dealer.label, {
            {
                title = ('Hire a dealer — $%d dirty'):format(d.hireCost or 0),
                description = ('He moves stocked product over time for a %d%% cut'):format(
                    math.floor((Config.Dealer.playerCut or 0.8) * 100)),
                icon = 'fas fa-user-plus',
                onSelect = function() TriggerServerEvent('palm6_drugs:dealerHire') end,
            },
        })
        return
    end

    local options = {
        {
            title = ('Holding %d / %d units'):format(d.stashUnits or 0, d.maxStash or 0),
            description = ('Owed: $%d dirty · buys up to $%d more today'):format(d.owed or 0, d.dailyRemaining or 0),
            icon = 'fas fa-briefcase',
            disabled = true,
        },
    }
    if (d.owed or 0) > 0 then
        options[#options + 1] = {
            title = ('Collect $%d dirty'):format(d.owed),
            description = 'Take your accumulated cut',
            icon = 'fas fa-sack-dollar',
            onSelect = function() TriggerServerEvent('palm6_drugs:dealerCollect') end,
        }
    end
    options[#options + 1] = {
        title = 'Stock product',
        description = 'Hand him weed product to push',
        icon = 'fas fa-box',
        onSelect = function()
            local sub = {}
            for _, h in ipairs(d.held or {}) do
                sub[#sub + 1] = {
                    title = ('%s [%s] x%d'):format(h.label, Config.QualityLabel(h.quality), h.count),
                    description = ('~$%d each — hand over the whole stack'):format(h.unit),
                    icon = 'fas fa-box',
                    onSelect = function() TriggerServerEvent('palm6_drugs:dealerStock', h.slot, h.count) end,
                }
            end
            if #sub == 0 then
                sub[#sub + 1] = {
                    title = 'No product on you',
                    description = 'Mix some weed product at the station first',
                    icon = 'fas fa-ban',
                    disabled = true,
                }
            end
            Game.OpenMenu('palm6_drugs_dealer_stock', 'Stock the dealer', sub, 'palm6_drugs_dealer')
        end,
    }
    options[#options + 1] = {
        title = 'Fire the dealer',
        description = 'Reclaim unsold product + owed cash',
        icon = 'fas fa-user-minus',
        onSelect = function() TriggerServerEvent('palm6_drugs:dealerFire') end,
    }
    Game.OpenMenu('palm6_drugs_dealer', Config.Dealer.label, options)
end)

-- ---------------------------------------------------------------------------
-- Fallback point dispatch (used only when qbx_police is absent)
-- ---------------------------------------------------------------------------
RegisterNetEvent('palm6_drugs:dispatch', function(d)
    if not d or not d.coords then return end
    Game.ShowDispatchBlip(d.coords, d.label or 'Drug activity reported', 60)
    Game.Notify({ title = 'Dispatch', description = d.label or 'Drug activity reported.', type = 'inform' })
end)

-- ---------------------------------------------------------------------------
-- World setup / teardown
-- ---------------------------------------------------------------------------
CreateThread(function()
    Wait(1000)

    -- Grow plots
    for i, plot in ipairs(Config.Grow.plots) do
        handles[#handles + 1] = Game.CreateInteraction(
            ('plot_%d'):format(i), plot, Config.Grow.plotRadius, 'Tend plot', 'fas fa-seedling',
            function() TriggerServerEvent('palm6_drugs:plotMenu', i) end)
    end

    -- Mixing station
    handles[#handles + 1] = Game.CreateInteraction(
        'mix', Config.Mix.coords, Config.Mix.radius, Config.Mix.label, 'fas fa-blender',
        function() TriggerServerEvent('palm6_drugs:mixMenu') end)

    -- Drying rack (buds → Heavenly)
    handles[#handles + 1] = Game.CreateInteraction(
        'dry', Config.Dry.coords, Config.Dry.radius, Config.Dry.label, 'fas fa-wind',
        function() TriggerServerEvent('palm6_drugs:dryMenu') end)

    -- Meth cook station (§9) — fixed object, no ped, so teardown just removes it
    handles[#handles + 1] = Game.CreateInteraction(
        'cook', Config.Cook.coords, Config.Cook.radius, Config.Cook.label, 'fas fa-fire',
        function() TriggerServerEvent('palm6_drugs:cookMenu') end)

    -- NPC street-buyer
    buyerPed = Game.SpawnPed(Config.Sell.pedModel, Config.Sell.coords, Config.Sell.pedHeading)
    handles[#handles + 1] = Game.CreateInteraction(
        'buyer', Config.Sell.coords, Config.Sell.radius, ('Sell to %s'):format(Config.Sell.label),
        'fas fa-user-secret',
        function() TriggerServerEvent('palm6_drugs:sellMenu') end)

    -- NPC corner dealer (passive faucet)
    dealerPed = Game.SpawnPed(Config.Dealer.pedModel, Config.Dealer.coords, Config.Dealer.pedHeading)
    handles[#handles + 1] = Game.CreateInteraction(
        'dealer', Config.Dealer.coords, Config.Dealer.radius, Config.Dealer.label,
        'fas fa-user-tie',
        function() TriggerServerEvent('palm6_drugs:dealerMenu') end)
end)

AddEventHandler('onResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() then return end
    for _, h in ipairs(handles) do Game.RemoveInteraction(h) end
    if buyerPed then Game.DeletePed(buyerPed) end
    if dealerPed then Game.DeletePed(dealerPed) end
end)
