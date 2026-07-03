-- ============================================================================
-- gtarp_counterfeit/client/main.lua
--
-- Pure logic. Calls Game.* (bridge/cl_game.lua) for all native access.
-- No direct natives or framework UI calls here (§6 gate). The server is authoritative on
-- every gate — items, serials, districts, quotas, timers, distances,
-- detection rolls; this file is prompts, menus, blips, and progress flows.
--
-- Perf: zero unconditional per-frame loops. Static interactions are
-- event-driven target zones (or 16m-gated marker points without ox_target);
-- printer zones exist only for the owner, only while placed.
-- ============================================================================

-- Static world state (whole session): sink/fence peds + zones.
local static = { handles = {}, peds = {} }

-- Dynamic: the local player's own printer zones, rebuilt on every sync.
local printerZones = {}

-- ---------------------------------------------------------------------------
-- Printer zones (owner only — the server decides who gets synced)
-- ---------------------------------------------------------------------------
local function clearPrinterZones()
    for _, h in ipairs(printerZones) do Game.RemoveInteraction(h) end
    printerZones = {}
end

RegisterNetEvent('gtarp_counterfeit:printerSync', function(list)
    clearPrinterZones()
    for _, p in ipairs(list or {}) do
        printerZones[#printerZones + 1] = Game.CreateInteraction(
            ('printer_%d'):format(p.id), p.coords, 'Work the press', 'fas fa-print',
            function() TriggerServerEvent('gtarp_counterfeit:printer:menu', p.id) end)
    end
end)

RegisterNetEvent('gtarp_counterfeit:printer:menuData', function(d)
    Game.OpenMenu('counterfeit_printer', 'The Press', {
        {
            title = ('Hopper: %d/%d paper, %d/%d ink'):format(d.paper, d.maxPaper, d.ink, d.maxInk),
            description = ('One cycle: %d paper + %d ink -> %d wads'):format(d.paperPerCycle, d.inkPerCycle, d.wadsPerCycle),
            icon = 'fas fa-gauge',
        },
        {
            title = ('Feed paper (%d on you)'):format(d.heldPaper),
            icon = 'fas fa-file',
            onSelect = function() TriggerServerEvent('gtarp_counterfeit:printer:feed', d.id, 'paper') end,
        },
        {
            title = ('Feed ink (%d on you)'):format(d.heldInk),
            icon = 'fas fa-fill-drip',
            onSelect = function() TriggerServerEvent('gtarp_counterfeit:printer:feed', d.id, 'ink') end,
        },
        {
            title = 'Run a print cycle',
            description = 'Loud on the block — every cycle warms the district',
            icon = 'fas fa-money-bill-wave',
            onSelect = function() TriggerServerEvent('gtarp_counterfeit:printer:start', d.id) end,
        },
        {
            title = 'Pack up the press',
            description = 'Hopper contents are LOST',
            icon = 'fas fa-box',
            onSelect = function() TriggerServerEvent('gtarp_counterfeit:printer:pickup', d.id) end,
        },
    })
end)

-- Placement: the server asked us to scan for a whitelisted anchor prop.
RegisterNetEvent('gtarp_counterfeit:beginPlacement', function()
    local model = Game.FindNearbyAnchorProp(Config.Printer.AnchorProps, Config.Printer.AnchorRadius)
    if not model then
        Game.Notify({
            title = 'Printer',
            description = 'Nowhere to set up here. Find real printing gear to blend in with — a print shop, a copier, a certain factory floor.',
            type = 'error',
        })
        return
    end
    TriggerServerEvent('gtarp_counterfeit:place', model)
end)

-- The print cycle: progress bar, then the server verifies the window.
RegisterNetEvent('gtarp_counterfeit:beginPrint', function(seconds)
    if Game.ProgressBar('Running plates — stay on the press', (seconds or 20) * 1000) then
        TriggerServerEvent('gtarp_counterfeit:printer:finish')
    else
        TriggerServerEvent('gtarp_counterfeit:printer:cancel')
        Game.Notify({ title = 'Printer', description = 'You stopped the run. The sheets went back in the hopper.', type = 'inform' })
    end
end)

-- ---------------------------------------------------------------------------
-- Detector pen
-- ---------------------------------------------------------------------------
RegisterNetEvent('gtarp_counterfeit:pen:pick', function(wads)
    local options = {}
    for _, w in ipairs(wads or {}) do
        options[#options + 1] = {
            title = 'Bundled Cash',
            description = 'Draw a test stroke on this bundle',
            icon = 'fas fa-highlighter',
            onSelect = function() TriggerServerEvent('gtarp_counterfeit:pen:start', w.serial) end,
        }
    end
    Game.OpenMenu('counterfeit_pen', 'Detector Pen', options)
end)

RegisterNetEvent('gtarp_counterfeit:pen:begin', function(serial)
    local passed = Game.SkillCheck(Config.Pen.Difficulty)
    TriggerServerEvent('gtarp_counterfeit:pen:finish', serial, passed)
end)

RegisterNetEvent('gtarp_counterfeit:report', function(title, content)
    Game.ShowReport(title, content)
end)

-- ---------------------------------------------------------------------------
-- Sinks + fences (menu data arrives from the server; menus only display it —
-- every selection is re-validated server-side)
-- ---------------------------------------------------------------------------
RegisterNetEvent('gtarp_counterfeit:sink:menuData', function(sinkId, wads)
    if #(wads or {}) == 0 then
        Game.Notify({ title = 'Vendor', description = '"Cash or nothing." You have no bundles on you.', type = 'inform' })
        return
    end
    local options = {}
    for _, w in ipairs(wads) do
        options[#options + 1] = {
            title = 'Pay with a bundle',
            description = 'Face value in goods — if the vendor takes it',
            icon = 'fas fa-money-bill',
            onSelect = function() TriggerServerEvent('gtarp_counterfeit:sink:spend', sinkId, w.serial) end,
        }
    end
    Game.OpenMenu('counterfeit_sink', 'Pay Cash', options)
end)

RegisterNetEvent('gtarp_counterfeit:fence:menuData', function(fenceId, wads, info)
    if #(wads or {}) == 0 then
        Game.Notify({ title = 'Fence', description = '"You got no paper I can move."', type = 'inform' })
        return
    end
    local options = {
        {
            title = ('Quota left today: %d'):format(info and info.quotaLeft or 0),
            description = 'The wearier the paper, the likelier the refusal',
            icon = 'fas fa-scale-unbalanced',
        },
    }
    for _, w in ipairs(wads) do
        options[#options + 1] = {
            title = ('Pass a bundle — $%d'):format(w.offer),
            description = w.remark,
            icon = 'fas fa-hand-holding-dollar',
            onSelect = function() TriggerServerEvent('gtarp_counterfeit:fence:pass', fenceId, w.serial) end,
        }
    end
    Game.OpenMenu('counterfeit_fence', 'The Fence', options)
end)

-- ---------------------------------------------------------------------------
-- Police surfaces
-- ---------------------------------------------------------------------------
RegisterNetEvent('gtarp_counterfeit:police:pickSeize', function(wads)
    local options = {}
    for _, w in ipairs(wads or {}) do
        options[#options + 1] = {
            title = 'Bag this bundle',
            description = 'Consumes an empty evidence bag if you carry one',
            icon = 'fas fa-box-archive',
            onSelect = function() TriggerServerEvent('gtarp_counterfeit:police:bag', w.serial) end,
        }
    end
    Game.OpenMenu('counterfeit_seize', 'Seize Counterfeit', options)
end)

-- The vague district heat ping (server decides who receives it).
RegisterNetEvent('gtarp_counterfeit:heatPing', function(d)
    if not d or not d.coords then return end
    Game.ShowAreaPing(d.coords, d.radius or 250.0, d.label or 'Counterfeit activity suspected',
        d.duration or Config.HeatBlip.durationSec, Config.HeatBlip.colour, Config.HeatBlip.alpha)
    Game.Notify({ title = 'Dispatch', description = d.label or 'Counterfeit activity suspected.', type = 'inform' })
end)

-- Fallback point dispatch (used only when qbx_police is absent).
RegisterNetEvent('gtarp_counterfeit:dispatch', function(d)
    if not d or not d.coords then return end
    Game.ShowDispatchBlip(d.coords, d.label or 'Counterfeit report', 60)
    Game.Notify({ title = 'Dispatch', description = d.label or 'Counterfeit report.', type = 'inform' })
end)

-- ---------------------------------------------------------------------------
-- Static world setup / teardown
-- ---------------------------------------------------------------------------
CreateThread(function()
    Wait(1000)

    for _, sink in ipairs(Config.Sinks) do
        static.peds[#static.peds + 1] = Game.SpawnPed(sink.pedModel, sink.coords, sink.pedHeading)
        static.handles[#static.handles + 1] = Game.CreateInteraction(
            ('sink_%s'):format(sink.id), sink.coords, ('Pay cash — %s'):format(sink.label),
            'fas fa-money-bill',
            function() TriggerServerEvent('gtarp_counterfeit:sink:menu', sink.id) end)
    end

    for _, fence in ipairs(Config.Fences) do
        static.peds[#static.peds + 1] = Game.SpawnPed(fence.pedModel, fence.coords, fence.pedHeading)
        static.handles[#static.handles + 1] = Game.CreateInteraction(
            ('fence_%s'):format(fence.id), fence.coords, 'Talk paper', 'fas fa-user-secret',
            function() TriggerServerEvent('gtarp_counterfeit:fence:menu', fence.id) end)
    end

    -- Pick up our own printer zones (server answers only with ours).
    TriggerServerEvent('gtarp_counterfeit:requestPrinters')
end)

AddEventHandler('onResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() then return end
    clearPrinterZones()
    for _, h in ipairs(static.handles) do Game.RemoveInteraction(h) end
    for _, p in ipairs(static.peds) do Game.DeletePed(p) end
end)
