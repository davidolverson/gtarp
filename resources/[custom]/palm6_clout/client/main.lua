-- ============================================================================
-- palm6_clout/client/main.lua
--
-- Pure logic. Calls Game.* (bridge/cl_game.lua) for all native access.
-- No direct natives here (§6 gate). The server is authoritative on every
-- viewer number, donation, payout, proximity gate, and identity — this file
-- is overlay plumbing, LIVE head-tag bookkeeping, and the broker prompt.
--
-- The overlay is a pure HUD layer: it never takes NUI focus and the page
-- sends nothing back — there are zero NUI callbacks to trust or abuse.
-- ============================================================================

local LiveStreamers = {}   -- serverId -> streamer name (everyone who is live)
local Tags = {}            -- serverId -> { tag = handle, ped = handle }
local anyLive = false

-- ---------------------------------------------------------------------------
-- Own-stream overlay (server -> NUI, display only)
-- ---------------------------------------------------------------------------
RegisterNetEvent('palm6_clout:streamStarted', function(payload)
    Game.SendUIMessage({ action = 'open', viewers = payload.viewers or 0 })
end)

RegisterNetEvent('palm6_clout:tick', function(payload)
    Game.SendUIMessage({
        action = 'tick',
        viewers = payload.viewers or 0,
        mood = payload.mood or 'idle',
        trend = payload.trend or 'flat',
    })
end)

RegisterNetEvent('palm6_clout:donation', function(payload)
    Game.SendUIMessage({
        action = 'donation',
        name = payload.name or 'anon',
        amount = payload.amount or 0,
    })
end)

RegisterNetEvent('palm6_clout:milestone', function(payload)
    Game.SendUIMessage({
        action = 'milestone',
        viewers = payload.viewers or 0,
        label = payload.label or '',
    })
end)

RegisterNetEvent('palm6_clout:streamEnded', function(payload)
    Game.SendUIMessage({
        action = 'ended',
        peak = payload and payload.peak or 0,
        seconds = payload and payload.seconds or 0,
        donations = payload and payload.donations or 0,
    })
end)

-- Read-only dialogs (subpoena results, /clout dashboard, leaderboard).
RegisterNetEvent('palm6_clout:showVodLog', function(title, content)
    Game.ShowLogDialog(title, content)
end)

-- ---------------------------------------------------------------------------
-- LIVE head tags: everyone can SEE who is streaming. State is server-pushed;
-- this loop only reconciles tag handles against ped handles.
-- ---------------------------------------------------------------------------
local function refreshAnyLive()
    anyLive = next(LiveStreamers) ~= nil
end

local function dropTag(serverId)
    local rec = Tags[serverId]
    if rec then
        Game.RemoveLiveTag(rec.tag)
        Tags[serverId] = nil
    end
end

RegisterNetEvent('palm6_clout:liveAdd', function(serverId, name)
    LiveStreamers[serverId] = name or true
    refreshAnyLive()
end)

RegisterNetEvent('palm6_clout:liveRemove', function(serverId)
    LiveStreamers[serverId] = nil
    dropTag(serverId)
    refreshAnyLive()
end)

RegisterNetEvent('palm6_clout:liveSync', function(list)
    LiveStreamers = {}
    for _, e in ipairs(list or {}) do
        LiveStreamers[e.src] = e.name or true
    end
    -- Drop tags for anyone no longer live.
    for serverId in pairs(Tags) do
        if not LiveStreamers[serverId] then dropTag(serverId) end
    end
    refreshAnyLive()
end)

-- Pull the current live set once on load.
CreateThread(function()
    Wait(3000)
    TriggerServerEvent('palm6_clout:requestLiveSync')
end)

-- Tag reconciliation. Fully idle (2s sleeps, zero work) when nobody is
-- live; while someone is live it runs bookkeeping every ClientTagRefreshMs
-- — no per-frame work either way.
CreateThread(function()
    while true do
        if not anyLive then
            Wait(2000)
        else
            local me = Game.GetMyServerId()
            for serverId in pairs(LiveStreamers) do
                if serverId ~= me then
                    local ped = Game.GetPedForServerId(serverId)
                    local rec = Tags[serverId]
                    if not ped then
                        if rec then dropTag(serverId) end
                    elseif not rec or rec.ped ~= ped or not Game.IsTagActive(rec.tag) then
                        -- New, respawned, or re-scoped ped: (re)attach the tag.
                        if rec then dropTag(serverId) end
                        Tags[serverId] = { tag = Game.CreateLiveTag(ped, Config.LiveTagText), ped = ped }
                    end
                end
            end
            Wait(Config.ClientTagRefreshMs)
        end
    end
end)

-- ---------------------------------------------------------------------------
-- Pawnshop broker: ped spawn + [E] prompt. Idles at 1000ms; only tightens
-- to per-frame while standing at the broker (same distance-gated pattern as
-- palm6_evidence — no unconditional per-frame work on a 48-slot server).
-- ---------------------------------------------------------------------------
CreateThread(function()
    local brokerPed = nil
    while true do
        local coords = Game.GetPlayerCoords()
        local dist = Game.DistanceBetween(coords, Config.PawnshopCoords)
        local wait = 1000

        -- Ped lifecycle: exists only while a player is near enough to see it.
        if dist <= Config.PawnSpawnRadius and not brokerPed then
            brokerPed = Game.SpawnBrokerPed(Config.PawnPedModel, Config.PawnshopCoords)
        elseif dist > (Config.PawnSpawnRadius + 20.0) and brokerPed then
            Game.DeletePed(brokerPed)
            brokerPed = nil
        end

        if dist <= Config.InteractRadius then
            wait = 0
            Game.ShowHelpThisFrame('Press ~INPUT_PICKUP~ to cash out your brand deals')
            if Game.InteractPressed() then
                TriggerServerEvent('palm6_clout:requestClaimDeals')
            end
        end

        Wait(wait)
    end
end)
