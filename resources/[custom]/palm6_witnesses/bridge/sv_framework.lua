-- ============================================================================
-- palm6_witnesses/bridge/sv_framework.lua
--
-- Framework adapter (server). The ONLY file in this resource that touches
-- qbx_core (identity, job, money), the recipe's police:server:policeAlert
-- event, or server-side game natives (ped enumeration, vehicle plate/type,
-- weapon state). The witness lifecycle, fact model, canvass/press/payoff
-- rules all live in server/main.lua and call Bridge.* only. To port to
-- GTA VI, rewrite THIS FILE. See docs/GTA6-READINESS.md (Section 3).
-- ============================================================================

Bridge = {}

local UNARMED = joaat('WEAPON_UNARMED')

-- Resolve the framework player object for a server source, or nil.
local function getPlayer(src)
    local ok, p = pcall(function() return exports.qbx_core:GetPlayer(src) end)
    return ok and p or nil
end

-- ---------------------------------------------------------------------------
-- Identity / job
-- ---------------------------------------------------------------------------

-- Stable per-character id, or nil.
function Bridge.GetCitizenId(src)
    local p = getPlayer(src)
    if not p or not p.PlayerData then return nil end
    return p.PlayerData.citizenid
end

-- Is this source an on-duty police officer right now?
function Bridge.IsOnDutyPolice(src)
    local p = getPlayer(src)
    local job = p and p.PlayerData and p.PlayerData.job
    return job ~= nil and job.name == 'police' and job.onduty == true
end

-- RP display name for a source (case-entry attribution).
function Bridge.GetPlayerName(src)
    local p = getPlayer(src)
    if p and p.PlayerData and p.PlayerData.charinfo then
        local ci = p.PlayerData.charinfo
        local name = ('%s %s'):format(ci.firstname or '', ci.lastname or '')
        name = name:gsub('^%s+', ''):gsub('%s+$', '')
        if #name > 0 then return name end
    end
    return GetPlayerName(src) or ('player %d'):format(src)
end

-- All connected sources as numbers.
function Bridge.GetPlayerSources()
    local out = {}
    for _, s in ipairs(GetPlayers()) do
        out[#out + 1] = tonumber(s)
    end
    return out
end

-- ---------------------------------------------------------------------------
-- Money (the payoff charge)
-- ---------------------------------------------------------------------------

-- Debit `amount` cash from the source. Returns true on success
-- (affordability checked here + by the framework's RemoveMoney).
function Bridge.ChargeCash(src, amount, reason)
    local p = getPlayer(src)
    if not p or not p.Functions then return false end
    if (p.PlayerData.money and p.PlayerData.money.cash or 0) < amount then return false end
    return p.Functions.RemoveMoney('cash', amount, reason) and true or false
end

-- ---------------------------------------------------------------------------
-- Presence / world (server-side anti-abuse — never trust claimed positions)
-- ---------------------------------------------------------------------------

-- Current coords of a player's ped as {x,y,z}, or nil.
function Bridge.GetCoords(src)
    local ped = GetPlayerPed(src)
    if not ped or ped == 0 then return nil end
    local c = GetEntityCoords(ped)
    return { x = c.x, y = c.y, z = c.z }
end

-- Distance in metres between two coord tables (accepts vector3 too).
function Bridge.Distance(a, b)
    return #(vector3(a.x, a.y, a.z) - vector3(b.x, b.y, b.z))
end

-- Is the player's ped holding anything other than fists right now?
-- Server-side read of the selected weapon — the press gate never trusts
-- the client's claim of being armed.
function Bridge.IsArmed(src)
    local ped = GetPlayerPed(src)
    if not ped or ped == 0 then return false end
    local ok, weapon = pcall(function() return GetSelectedPedWeapon(ped) end)
    return ok and weapon ~= nil and weapon ~= 0 and weapon ~= UNARMED
end

-- ---------------------------------------------------------------------------
-- NPC snapshot. OneSync exposes the ambient ped population server-side; we
-- return up to `maxCount` non-player peds within `radius` of `coords` as
-- plain coord tables. Population-type filtering keeps mission/permanent
-- peds (shop clerks behind counters, script peds) out of the pool where
-- the native is available; everything is pcall-guarded because ped
-- entities churn constantly.
-- ---------------------------------------------------------------------------
function Bridge.GetNearbyNpcCoords(coords, radius, maxCount)
    local out = {}
    local ok, peds = pcall(GetAllPeds)
    if not ok or type(peds) ~= 'table' then return out end
    local origin = vector3(coords.x, coords.y, coords.z)

    for _, ped in ipairs(peds) do
        if #out >= maxCount then break end
        local okPed = pcall(function()
            if IsPedAPlayer(ped) then return end
            local c = GetEntityCoords(ped)
            if #(c - origin) > radius then return end
            -- Ambient population only (3 = patrol, 4 = scenario, 5 = ambient).
            -- If the native is missing on this build, accept the ped.
            local okPop, pop = pcall(function() return GetEntityPopulationType(ped) end)
            if okPop and pop and pop ~= 3 and pop ~= 4 and pop ~= 5 then return end
            out[#out + 1] = { x = c.x, y = c.y, z = c.z }
        end)
        if not okPed and Config.Debug then
            print('[palm6_witnesses] ped snapshot skipped a stale entity')
        end
    end
    return out
end

-- ---------------------------------------------------------------------------
-- Suspect vehicle facts (server-side natives — nothing client-reported).
-- Returns { typeName = 'automobile'|..., plate = 'ABC 123' } or nil when
-- the suspect is on foot.
-- ---------------------------------------------------------------------------
function Bridge.GetVehicleFacts(src)
    local ped = GetPlayerPed(src)
    if not ped or ped == 0 then return nil end
    local ok, facts = pcall(function()
        local veh = GetVehiclePedIsIn(ped, false)
        if not veh or veh == 0 then return nil end
        local plate = GetVehicleNumberPlateText(veh)
        local vtype = GetVehicleType(veh)
        return {
            typeName = (type(vtype) == 'string' and vtype ~= '') and vtype or 'automobile',
            plate = type(plate) == 'string' and plate or '',
        }
    end)
    return ok and facts or nil
end

-- ---------------------------------------------------------------------------
-- Recipe police alert (opt-in, see Config.FirePoliceAlerts). This is the
-- EXACT event qbx_storerobbery / qbx_drugs cornerselling use —
-- qbx_police/server/main.lua handles it and derives the blip coords from
-- `suspectSrc`'s ped, exactly like cornerselling's
-- TriggerEvent('police:server:policeAlert', text, nil, playerSource).
-- We reuse it rather than rolling a parallel dispatch.
-- ---------------------------------------------------------------------------
function Bridge.PoliceAlert(suspectSrc, text)
    pcall(function()
        TriggerEvent('police:server:policeAlert', text, nil, suspectSrc)
    end)
end

-- ---------------------------------------------------------------------------
-- Notifications
-- ---------------------------------------------------------------------------

-- Notify one player (src 0 = server console).
function Bridge.Notify(src, title, msg, t)
    if not src or src == 0 then
        print(('[palm6_witnesses] %s: %s'):format(title, msg))
        return
    end
    TriggerClientEvent('ox_lib:notify', src, {
        title = title, description = msg, type = t or 'inform',
    })
end
