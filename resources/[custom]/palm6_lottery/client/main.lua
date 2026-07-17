-- ============================================================================
-- palm6_lottery/client/main.lua
--
-- Pure logic. Calls Game.* (bridge/cl_game.lua) for all native / ox_lib UI.
-- No direct GTA natives or ox_lib here (§6 gate).
--
-- Presentation only: the kiosk clerk NPC, the map blip, and the menu. Every
-- action fires a server event that re-runs all authority (rate limit, open-draw
-- check, bank charge, per-draw cap), so there is nothing here to abuse — a
-- modified client can only pick how many tickets to REQUEST; the server prices,
-- charges, and caps it.
-- ============================================================================

local kioskPed, kioskZone, kioskBlip

-- Thousands separators for display ($12,345).
local function comma(n)
    local s = tostring(math.floor(tonumber(n) or 0))
    local out = s:reverse():gsub('(%d%d%d)', '%1,'):reverse()
    return (out:gsub('^,', ''))
end

local function openKiosk()
    TriggerServerEvent('palm6_lottery:kiosk:data')
end

RegisterNetEvent('palm6_lottery:kiosk:dataResult', function(d)
    if type(d) ~= 'table' then return end
    if not d.open then
        Game.Notify({ title = 'City Lottery', description = 'No draw is open right now — check back shortly.', type = 'inform' })
        return
    end

    local opts = {}
    opts[#opts + 1] = {
        title = ('💰 Jackpot: $%s'):format(comma(d.pot)),
        description = ('Winner takes $%s (after the %d%% house rake) · %d ticket(s) in'):format(comma(d.net), d.rakePct or 0, d.cnt or 0),
        icon = 'fa-solid fa-sack-dollar', disabled = true,
    }
    opts[#opts + 1] = {
        title = ('🎟️ You hold %d / %d tickets'):format(d.mine or 0, d.cap or 0),
        description = ('Ticket $%s · %s'):format(comma(d.ticketPrice), d.nextIn or ''),
        icon = 'fa-solid fa-user', disabled = true,
    }
    for _, n in ipairs(d.quickBuys or {}) do
        opts[#opts + 1] = {
            title = ('Buy %d ticket%s'):format(n, n == 1 and '' or 's'),
            description = ('$%s from your bank'):format(comma(n * d.ticketPrice)),
            icon = 'fa-solid fa-cart-plus',
            onSelect = function() TriggerServerEvent('palm6_lottery:kiosk:buy', n) end,
        }
    end
    opts[#opts + 1] = {
        title = 'Buy a custom amount…',
        description = ('Up to %d per purchase'):format(d.maxPerBuy or 25),
        icon = 'fa-solid fa-pen',
        onSelect = function()
            local n = Game.InputNumber('Buy lottery tickets', ('How many? ($%s each)'):format(comma(d.ticketPrice)), 1, d.maxPerBuy or 25, 1)
            if n and n > 0 then TriggerServerEvent('palm6_lottery:kiosk:buy', n) end
        end,
    }
    if d.recent and #d.recent > 0 then
        opts[#opts + 1] = {
            title = '🏆 Recent winners',
            description = 'See the last few jackpots',
            icon = 'fa-solid fa-trophy',
            onSelect = function()
                local r = {}
                for _, w in ipairs(d.recent) do
                    r[#r + 1] = {
                        title = ('$%s'):format(comma(w.amount)),
                        description = ('%s · %s'):format(w.name or 'a citizen', w.ago or ''),
                        icon = 'fa-solid fa-medal', disabled = true,
                    }
                end
                Game.OpenMenu('palm6_lottery_winners', 'Recent winners', r)
            end,
        }
    end

    Game.OpenMenu('palm6_lottery_kiosk', 'City Lottery — Draw #' .. tostring(d.drawId or '?'), opts)
end)

CreateThread(function()
    kioskBlip = Game.AddBlip(Config.Kiosk.coords, Config.Kiosk.blip)
    kioskPed = Game.SpawnPed(Config.Kiosk.model, Config.Kiosk.coords, Config.Kiosk.heading)
    kioskZone = Game.AddPedInteraction(kioskPed, Config.Kiosk.coords, Config.Kiosk.label, Config.Kiosk.icon, openKiosk)
end)

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    Game.RemoveInteraction(kioskZone)
    Game.DeletePed(kioskPed)
    Game.RemoveBlip(kioskBlip)
end)
