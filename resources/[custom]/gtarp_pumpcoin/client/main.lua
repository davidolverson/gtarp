-- ============================================================================
-- gtarp_pumpcoin/client/main.lua
--
-- Pure logic. Calls Game.* (bridge/cl_game.lua) for all native/NUI-focus
-- access. No direct natives here (§6 gate). The server is authoritative on
-- every price, balance, proximity gate, and cooldown — this file is prompts,
-- NUI plumbing, and billboard blip bookkeeping only.
-- ============================================================================

local uiOpen = false
local BillboardBlips = {}   -- billboard id -> blip handle

local function closeUI()
    if not uiOpen then return end
    uiOpen = false
    Game.SetUIFocus(false)
    Game.SendUIMessage({ action = 'hide' })
end

-- ---------------------------------------------------------------------------
-- Exchange proximity loop. Idles at 1000ms; only tightens to per-frame while
-- standing on a terminal (same distance-gated pattern as gtarp_evidence —
-- no unconditional per-frame work on a 48-slot server).
-- ---------------------------------------------------------------------------
CreateThread(function()
    while true do
        local coords = Game.GetPlayerCoords()
        local wait = 1000

        local nearDist = math.huge
        for _, ex in ipairs(Config.Exchanges) do
            local d = Game.DistanceBetween(coords, ex)
            if d < nearDist then nearDist = d end
        end

        if uiOpen then
            -- Walk-away auto-close (server re-validates distance anyway).
            wait = 500
            if nearDist > (Config.InteractRadius + 2.0) then closeUI() end
        elseif nearDist <= Config.InteractRadius then
            wait = 0
            Game.ShowHelpThisFrame('Press ~INPUT_PICKUP~ to jack into the exchange')
            if Game.InteractPressed() then
                TriggerServerEvent('gtarp_pumpcoin:requestOpen')
            end
        end

        Wait(wait)
    end
end)

-- Optional exchange blips (off by default — back-alley word-of-mouth).
CreateThread(function()
    if not Config.ExchangeBlip.enabled then return end
    for _, ex in ipairs(Config.Exchanges) do
        Game.CreateExchangeBlip(ex)
    end
end)

-- ---------------------------------------------------------------------------
-- Server -> NUI
-- ---------------------------------------------------------------------------
RegisterNetEvent('gtarp_pumpcoin:open', function(payload)
    uiOpen = true
    Game.SetUIFocus(true)
    payload.action = 'open'
    Game.SendUIMessage(payload)
end)

RegisterNetEvent('gtarp_pumpcoin:data', function(payload)
    if not uiOpen then return end
    payload.action = 'data'
    Game.SendUIMessage(payload)
end)

RegisterNetEvent('gtarp_pumpcoin:chart', function(payload)
    if not uiOpen then return end
    payload.action = 'chart'
    Game.SendUIMessage(payload)
end)

-- A coin we hold just got rugged — refresh the board if it is open.
RegisterNetEvent('gtarp_pumpcoin:rugged', function()
    if uiOpen then TriggerServerEvent('gtarp_pumpcoin:requestData') end
end)

-- ---------------------------------------------------------------------------
-- NUI -> server. Callbacks forward intents only (ids + unit counts); the
-- server recomputes everything and never trusts these values.
-- ---------------------------------------------------------------------------
RegisterNUICallback('close', function(_, cb)
    closeUI()
    cb({ ok = true })
end)

RegisterNUICallback('refresh', function(_, cb)
    TriggerServerEvent('gtarp_pumpcoin:requestData')
    cb({ ok = true })
end)

RegisterNUICallback('chart', function(data, cb)
    TriggerServerEvent('gtarp_pumpcoin:requestChart', { coinId = tonumber(data and data.coinId) })
    cb({ ok = true })
end)

RegisterNUICallback('mint', function(data, cb)
    TriggerServerEvent('gtarp_pumpcoin:mint', {
        name = tostring(data and data.name or ''),
        ticker = tostring(data and data.ticker or ''),
        emoji = tostring(data and data.emoji or ''),
    })
    cb({ ok = true })
end)

RegisterNUICallback('buy', function(data, cb)
    TriggerServerEvent('gtarp_pumpcoin:buy', {
        coinId = tonumber(data and data.coinId),
        units = tonumber(data and data.units),
    })
    cb({ ok = true })
end)

RegisterNUICallback('sell', function(data, cb)
    TriggerServerEvent('gtarp_pumpcoin:sell', {
        coinId = tonumber(data and data.coinId),
        units = tonumber(data and data.units),
    })
    cb({ ok = true })
end)

-- ---------------------------------------------------------------------------
-- Billboard blips
-- ---------------------------------------------------------------------------
RegisterNetEvent('gtarp_pumpcoin:billboardAdd', function(id, coords, label)
    if BillboardBlips[id] then Game.RemoveBlip(BillboardBlips[id]) end
    BillboardBlips[id] = Game.CreateBillboardBlip(coords, label)
end)

RegisterNetEvent('gtarp_pumpcoin:billboardRemove', function(id)
    if BillboardBlips[id] then
        Game.RemoveBlip(BillboardBlips[id])
        BillboardBlips[id] = nil
    end
end)

RegisterNetEvent('gtarp_pumpcoin:billboardSync', function(list)
    for id, handle in pairs(BillboardBlips) do
        Game.RemoveBlip(handle)
        BillboardBlips[id] = nil
    end
    for _, b in ipairs(list or {}) do
        BillboardBlips[b.id] = Game.CreateBillboardBlip(b.coords, b.label)
    end
end)

-- Pull the current billboard set once on load.
CreateThread(function()
    Wait(3000)
    TriggerServerEvent('gtarp_pumpcoin:requestBillboards')
end)
