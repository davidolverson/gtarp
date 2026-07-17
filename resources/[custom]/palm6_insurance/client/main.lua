-- ============================================================================
-- palm6_insurance/client/main.lua
--
-- Pure logic. Calls Game.* (bridge/cl_game.lua) for all native / ox_lib UI.
-- No direct GTA natives or ox_lib here (§6 gate).
--
-- Presentation only: the office blip, the agent NPC, and the plan/claim menus.
-- Every menu action fires a server event that re-checks ALL authority (rate
-- limit, at-office, ownership, price recompute), so there is nothing here for a
-- modified client to abuse — the worst it can do is send a plate/tier the
-- server then validates and rejects.
-- ============================================================================

local agentPed, agentZone, officeBlip

local function notify(desc, kind)
    Game.Notify({ title = 'Mors Mutual', description = desc, type = kind or 'inform' })
end

-- --- Buy flow: quote the vehicle you're sitting in, then show the tiers -------
local function startBuy()
    local plate = Game.GetCurrentVehiclePlate()
    if not plate then
        notify('Get in the vehicle you want to insure, then talk to me.', 'error')
        return
    end
    TriggerServerEvent('palm6_insurance:agent:quote', plate)
end

RegisterNetEvent('palm6_insurance:agent:quoteData', function(data)
    if type(data) ~= 'table' or type(data.quotes) ~= 'table' then return end
    local options = {}
    for _, q in ipairs(data.quotes) do
        options[#options + 1] = {
            title = ('%s — $%d premium'):format(q.label, q.premium),
            description = ('%s\nCoverage $%d · deductible $%d · %dh term · payout ~%dm · theft %d%%')
                :format(q.blurb, q.coverage, q.deductible, q.termHours, q.payoutMin, q.theftPct),
            icon = 'fa-solid fa-shield-halved',
            onSelect = function()
                TriggerServerEvent('palm6_insurance:agent:buy', data.plate, q.key)
            end,
        }
    end
    Game.OpenMenu('palm6_insurance_tiers', 'Choose a plan — ' .. tostring(data.plate), options)
end)

-- --- Claim flow: list insured plates, pick one, pick damage / theft ----------
local function startClaim()
    TriggerServerEvent('palm6_insurance:agent:claimList')
end

RegisterNetEvent('palm6_insurance:agent:claimListData', function(data)
    if type(data) ~= 'table' or type(data.policies) ~= 'table' or #data.policies == 0 then
        notify('You have no active policies to claim on.', 'inform')
        return
    end
    local options = {}
    for _, p in ipairs(data.policies) do
        local plate = p.plate
        options[#options + 1] = {
            title = ('%s [%s]'):format(plate, p.tier),
            description = ('$%d coverage — file a claim'):format(p.coverage),
            icon = 'fa-solid fa-car-burst',
            onSelect = function()
                Game.OpenMenu('palm6_insurance_claim_' .. plate, 'Claim — ' .. plate, {
                    {
                        title = 'Report damage',
                        description = 'Bring the damaged vehicle to the office so the adjuster can inspect it.',
                        icon = 'fa-solid fa-car-crash',
                        onSelect = function() TriggerServerEvent('palm6_insurance:agent:fileclaim', plate, 'damage') end,
                    },
                    {
                        title = 'Report theft / stolen',
                        description = 'File if the vehicle is gone and nowhere in the city.',
                        icon = 'fa-solid fa-user-secret',
                        onSelect = function() TriggerServerEvent('palm6_insurance:agent:fileclaim', plate, 'theft') end,
                    },
                })
            end,
        }
    end
    Game.OpenMenu('palm6_insurance_claim_pick', 'File a claim', options)
end)

-- --- Root agent menu ---------------------------------------------------------
local function openAgentMenu()
    Game.OpenMenu('palm6_insurance_agent', 'Mors Mutual Insurance', {
        {
            title = 'Buy a policy',
            description = 'Insure the vehicle you drove up in — pick a plan.',
            icon = 'fa-solid fa-file-signature',
            onSelect = startBuy,
        },
        {
            title = 'File a claim',
            description = 'Damage or theft claim on one of your policies.',
            icon = 'fa-solid fa-car-burst',
            onSelect = startClaim,
        },
        {
            title = 'My policies & claims',
            description = 'See your active cover and any pending payouts.',
            icon = 'fa-solid fa-list',
            onSelect = function() TriggerServerEvent('palm6_insurance:agent:policies') end,
        },
    })
end

CreateThread(function()
    officeBlip = Game.AddBlip(Config.Office.coords, Config.Office.blip)
    agentPed = Game.SpawnPed(Config.Agent.model, Config.Agent.coords, Config.Agent.heading)
    agentZone = Game.AddPedInteraction(agentPed, Config.Agent.coords, Config.Agent.label, Config.Agent.icon, openAgentMenu)
end)

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    Game.RemoveInteraction(agentZone)
    Game.DeletePed(agentPed)
    Game.RemoveBlip(officeBlip)
end)
