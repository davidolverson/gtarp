-- ============================================================================
-- palm6_fc_arena/client/main.lua
-- Pure logic. Calls Game.* (bridge/cl_game.lua) for all natives / ox_lib.
-- Presentation only: ring blip + gallery zone, crowd peds (LIVE-only, culled),
-- spectator cam, soft-repel, fight-mark square-up. No authority.
-- ============================================================================

local ringBlip, ringZone
local crowd = {}
local currentMatchId
local spectating = false
local lastRepelNotify = 0

local function core() return exports.palm6_fc_core:Config() end

local function coreSafe()
    local ok, c = pcall(core)
    return ok and c or nil
end

local function enabled()
    local c = coreSafe(); return c and c.Enabled and true or false
end

local function ring()
    local c = coreSafe(); return c and c.Ring or nil
end

local function stateKey(id)
    local ok, k = pcall(function() return exports.palm6_fc_core:StateKeys() end)
    if ok and k and k.matchKey then return k.matchKey(id) end
    return ('fc:match:%d'):format(id)
end

local function isLive()
    if not currentMatchId then return false end
    local st = GlobalState[stateKey(currentMatchId)]
    return type(st) == 'table' and st.status == 'live'
end

-- BETTING open → discoverability notify for spectators.
RegisterNetEvent('palm6_fc_arena:bettingOpen', function(d)
    if type(d) ~= 'table' then return end
    currentMatchId = d.matchId
    Game.Notify({
        title = 'Fight Club',
        description = ('Match #%d open: %s vs %s\nBet: %s'):format(
            d.matchId or 0, d.f1name or '?', d.f2name or '?', d.betCmd or '/fcbet'),
        type = 'inform',
    })
end)

-- Square the local fighter up on their own mark (own ped only).
RegisterNetEvent('palm6_fc_arena:squareUp', function(d)
    if type(d) ~= 'table' or not d.coords then return end
    Game.SquareUp(d.coords, d.heading or 0.0)
end)

-- Canonical teardown (also the boot "abort any fight" broadcast) → tear down
-- all local presentation regardless of matchId (single ring in MVP).
RegisterNetEvent('palm6_fc_combat:teardown', function(d)
    if type(d) ~= 'table' then return end
    currentMatchId = nil
    if #crowd > 0 then Game.DeleteCrowd(crowd); crowd = {} end
    if spectating then Game.SpectateOff(); spectating = false end
end)

-- Presentation manager: crowd (LIVE + near) and soft-repel (LIVE + not a fighter).
CreateThread(function()
    while true do
        local sleep = 1000
        local r = ring()
        local live = enabled() and isLive()

        if live and r then
            local pc = Game.LocalCoords()
            local near = pc and Game.Dist(pc, r.coords) <= (Config.CullDistance or 60.0)
            if near and #crowd == 0 then
                local c = coreSafe()
                crowd = Game.SpawnCrowd(r.coords, (c and c.MaxCrowd) or 12, Config.GalleryRadius or 7.0)
            elseif (not near) and #crowd > 0 then
                Game.DeleteCrowd(crowd); crowd = {}
            end

            if near and not Game.IsFighter() then
                if Game.RepelFromRing(r.coords, Config.RepelRadius or 3.5) then
                    local t = GetGameTimer()
                    if t - lastRepelNotify > (Config.RepelNotifySec or 5) * 1000 then
                        lastRepelNotify = t
                        Game.Notify({ title = 'Fight Club', description = 'Stay clear of the ring during the fight.', type = 'error' })
                    end
                end
                sleep = 50    -- responsive repel while a non-fighter is at the ring
            else
                sleep = near and 250 or 1000
            end
        else
            if #crowd > 0 then Game.DeleteCrowd(crowd); crowd = {} end
            if spectating then Game.SpectateOff(); spectating = false end
            sleep = 1000
        end

        Wait(sleep)
    end
end)

-- Optional spectator cam toggle (non-participants, live fight only).
RegisterCommand('fcspectate', function()
    local r = ring()
    if not enabled() or not r then return end
    if Game.IsFighter() then return end
    if not isLive() then
        Game.Notify({ title = 'Fight Club', description = 'No live fight to spectate.', type = 'error' })
        return
    end
    spectating = not spectating
    if spectating then Game.SpectateOn(r.coords) else Game.SpectateOff() end
end, false)

-- Ring blip + gallery zone (only when enabled — prod-inert otherwise).
CreateThread(function()
    Wait(1500)  -- let fc_core exports come up
    if not enabled() then return end
    local r = ring()
    if not r then return end
    ringBlip = Game.AddBlip(r.coords, Config.Blip)
    ringZone = Game.AddRingZone(r.coords, r.radius or 15.0, function()
        Game.Notify({ title = 'Fight Club', description = 'You are at the fight ring. /fcspectate to watch, /fcbet during betting.', type = 'inform' })
    end, nil)
end)

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    if #crowd > 0 then Game.DeleteCrowd(crowd) end
    if spectating then Game.SpectateOff() end
    Game.RemoveBlip(ringBlip)
    Game.RemoveZone(ringZone)
end)
