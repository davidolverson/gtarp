-- ============================================================================
-- palm6_yard/client/main.lua
--
-- Pure logic: the three station interactions (labor / commissary / bail) and
-- their menus. All natives + ox_lib UI go through Game.* (bridge/cl_game.lua).
-- To port to GTA VI, rewrite the bridge, not this file. See docs/GTA6-READINESS.
--
-- The server does NOT trust anything sent from here. Labor and bail send NO
-- payload at all; the commissary sends only an item id + quantity, and the
-- server re-owns the price, the daily cap, the proximity, and the sentence
-- clock. The client renders xt-prison's own jail timer — it never asserts
-- 'I am free' and never sends a shave amount. Progress bars are cosmetic.
-- ============================================================================

local handles = {}
local blips = {}

-- ---------------------------------------------------------------------------
-- Commissary menu — built from the SHARED config for DISPLAY only. Prices shown
-- here are re-owned server-side; the client transmits only {item, qty}.
-- ---------------------------------------------------------------------------
local function openCommissary()
    local options = {}
    for _, c in ipairs(Config.Commissary.Items) do
        options[#options + 1] = {
            title = c.label,
            description = ('$%d each · up to %d/day'):format(c.price, Config.Commissary.DailyCapPerItem),
            icon = 'fas fa-basket-shopping',
            onSelect = function()
                local qty = Game.InputNumber(Config.Commissary.Label,
                    ('How many %s?'):format(c.label), Config.Commissary.DailyCapPerItem)
                if not qty then return end
                TriggerServerEvent('palm6_yard:server:buyCommissary', c.item, qty)
            end,
        }
    end
    Game.OpenMenu('palm6_yard_commissary', Config.Commissary.Label, options)
end

-- ---------------------------------------------------------------------------
-- Bail menu — the price is computed at the terminal (server-side), so the
-- client just confirms intent and fires. No amount is sent.
-- ---------------------------------------------------------------------------
local function openBail()
    if Game.Confirm(Config.Bail.Label,
        'Post bail for pretrial release? The bond is calculated from your remaining sentence. '
        .. 'Skipping court will put a warrant out for you.') then
        TriggerServerEvent('palm6_yard:server:postBail')
    end
end

-- ---------------------------------------------------------------------------
-- World setup / teardown
-- ---------------------------------------------------------------------------
CreateThread(function()
    Wait(1000)

    -- Labor yard: one E-press = one task (cosmetic progress bar, then fire).
    handles[#handles + 1] = Game.CreateInteraction(
        'labor', Config.Coords.Labor, Config.InteractRadius, Config.Labor.Label, 'fas fa-hammer',
        function()
            if Game.ProgressBar('Working the yard…', (Config.Labor.TaskSeconds or 6) * 1000) then
                TriggerServerEvent('palm6_yard:server:doLabor')
            end
        end)

    -- Commissary window.
    handles[#handles + 1] = Game.CreateInteraction(
        'commissary', Config.Coords.Commissary, Config.InteractRadius, Config.Commissary.Label,
        'fas fa-store', openCommissary)

    -- Bail bond terminal.
    handles[#handles + 1] = Game.CreateInteraction(
        'bail', Config.Coords.Bail, Config.InteractRadius, Config.Bail.Label,
        'fas fa-scale-balanced', openBail)

    -- Map blips.
    for key, coords in pairs(Config.Coords) do
        local b = Config.Blips[key]
        if b then blips[#blips + 1] = Game.CreateBlip(coords, b.sprite, b.colour, b.scale, b.label) end
    end
end)

AddEventHandler('onResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() then return end
    for _, h in ipairs(handles) do Game.RemoveInteraction(h) end
    for _, b in ipairs(blips) do Game.RemoveBlip(b) end
end)
