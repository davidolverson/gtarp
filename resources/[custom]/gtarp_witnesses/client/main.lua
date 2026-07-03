-- ============================================================================
-- gtarp_witnesses/client/main.lua
--
-- Pure logic. Calls Game.* (bridge/cl_game.lua) for all native access —
-- no direct natives or framework UI calls here (§6 gate).
--
-- This side is PRESENTATION ONLY: it renders the witness markers the
-- server says this client is entitled to (police = all un-canvassed,
-- suspects = their own still-active ones), shows prompts, and runs the
-- canvass / press progress bars. Every gate that matters — duty, armed,
-- ownership, proximity, the two-phase elapsed window, the payoff charge —
-- is validated server-side; nothing sent from here is trusted.
--
-- Perf: no unconditional per-frame work. The render loop sleeps 1s with
-- no nearby witnesses, 250ms while approaching, and only goes per-frame
-- inside marker draw distance.
-- ============================================================================

local witnesses = {}   -- array of { id, x, y, z, role = 'police'|'suspect', label }
local blips = {}       -- [witnessId] = blip handle
local busy = false     -- a canvass/press progress bar is running

local POLICE_RGB  = { 240, 200, 80 }
local SUSPECT_RGB = { 220, 60, 60 }

-- ---------------------------------------------------------------------------
-- Sync
-- ---------------------------------------------------------------------------

local function clearBlips()
    for _, handle in pairs(blips) do Game.RemoveBlip(handle) end
    blips = {}
end

RegisterNetEvent('gtarp_witnesses:sync', function(list, _)
    if type(list) ~= 'table' then return end
    witnesses = list
    clearBlips()
    for _, w in ipairs(witnesses) do
        local cfg = w.role == 'police' and Config.PoliceBlip or Config.SuspectBlip
        blips[w.id] = Game.CreateWitnessBlip({ x = w.x, y = w.y, z = w.z }, cfg)
    end
end)

-- Late-join + duty-toggle coverage: one request at start, then a slow
-- timer. Event pushes from the server cover everything in between.
CreateThread(function()
    Wait(5000)
    while true do
        TriggerServerEvent('gtarp_witnesses:requestSync')
        Wait(Config.ClientSyncSec * 1000)
    end
end)

-- ---------------------------------------------------------------------------
-- Two-phase interactions (server-driven)
-- ---------------------------------------------------------------------------

RegisterNetEvent('gtarp_witnesses:beginCanvass', function(durationSec)
    if busy then return end
    busy = true
    local done = Game.ProgressBar('Talking to the witness...', durationSec * 1000)
    busy = false
    if done then
        TriggerServerEvent('gtarp_witnesses:canvass:finish')
    else
        TriggerServerEvent('gtarp_witnesses:canvass:cancel')
    end
end)

RegisterNetEvent('gtarp_witnesses:beginPress', function(durationSec)
    if busy then return end
    busy = true

    -- Watcher: the hold breaks the moment the weapon comes off aim.
    local holding = true
    CreateThread(function()
        while holding do
            Wait(150)
            if holding and not Game.IsAiming() then
                Game.CancelProgress()
            end
        end
    end)

    local done = Game.AimProgressBar('Making your point...', durationSec * 1000)
    holding = false
    busy = false

    if done then
        TriggerServerEvent('gtarp_witnesses:press:finish')
    else
        TriggerServerEvent('gtarp_witnesses:press:cancel')
        Game.Notify({ title = 'Witness', description = 'You backed off. They\'re still talking.', type = 'error' })
    end
end)

RegisterNetEvent('gtarp_witnesses:showStatement', function(title, body)
    Game.ShowDialog(title, body)
end)

-- ---------------------------------------------------------------------------
-- Appearance capture: server-requested, nonce-gated snapshot of the local
-- ped's REAL top/mask variation at crime time (see the server's trust-
-- boundary note — this only ever describes the local player).
-- ---------------------------------------------------------------------------
RegisterNetEvent('gtarp_witnesses:captureAppearance', function(nonce)
    if type(nonce) ~= 'string' then return end
    TriggerServerEvent('gtarp_witnesses:appearanceResult', nonce, Game.GetAppearanceSignature())
end)

-- ---------------------------------------------------------------------------
-- Render + prompt loop (distance-gated waits, per-frame only up close)
-- ---------------------------------------------------------------------------
CreateThread(function()
    while true do
        local wait = 1000

        if #witnesses > 0 and not busy then
            local me = Game.GetPlayerCoords()

            -- Nearest entitled witness.
            local nearest, nearestDist
            for _, w in ipairs(witnesses) do
                local d = Game.DistanceBetween(me, w)
                if not nearestDist or d < nearestDist then
                    nearest, nearestDist = w, d
                end
            end

            if nearestDist and nearestDist <= Config.MarkerDrawDistance then
                wait = 0  -- per-frame: markers + prompts

                for _, w in ipairs(witnesses) do
                    if Game.DistanceBetween(me, w) <= Config.MarkerDrawDistance then
                        Game.DrawWitnessMarker(w, w.role == 'police' and POLICE_RGB or SUSPECT_RGB)
                    end
                end

                if nearest.role == 'police' then
                    if nearestDist <= Config.Canvass.Radius then
                        Game.ShowHelpThisFrame(('Press ~INPUT_PICKUP~ to canvass the witness (%s)')
                            :format(nearest.label or 'incident'))
                        if Game.InteractPressed() then
                            TriggerServerEvent('gtarp_witnesses:canvass:start', nearest.id)
                        end
                    end
                else -- suspect
                    if nearestDist <= Config.Payoff.Radius then
                        Game.ShowHelpThisFrame(
                            ('Press ~INPUT_PICKUP~ to pay them off ($%d) — or aim a weapon and press ~INPUT_DETONATE~ to intimidate')
                            :format(Config.Payoff.Price))
                        if Game.InteractPressed() then
                            TriggerServerEvent('gtarp_witnesses:payoff', nearest.id)
                        end
                    elseif nearestDist <= Config.Press.Radius then
                        Game.ShowHelpThisFrame('Aim a weapon and press ~INPUT_DETONATE~ to intimidate the witness')
                    end

                    if nearestDist <= Config.Press.Radius and Game.AltPressed() then
                        if Game.IsArmed() and Game.IsAiming() then
                            TriggerServerEvent('gtarp_witnesses:press:start', nearest.id)
                        else
                            Game.Notify({ title = 'Witness',
                                description = 'You need a weapon up and aimed to make that point.',
                                type = 'error' })
                        end
                    end
                end
            elseif nearestDist and nearestDist <= 100.0 then
                wait = 250
            end
        end

        Wait(wait)
    end
end)
