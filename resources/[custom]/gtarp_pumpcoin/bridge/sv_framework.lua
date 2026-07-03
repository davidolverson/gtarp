-- ============================================================================
-- gtarp_pumpcoin/bridge/sv_framework.lua
--
-- Framework adapter (server). The ONLY file in this resource that knows
-- about qbx_core, the qbx player/money API, the qbx players.money JSON
-- shape, ox_lib notifications, or server-side natives.
--
-- Core logic (server/main.lua) calls Bridge.* and nothing else: the bonding
-- curve, rug detection, delist settlement, and every validation gate above
-- this file are framework-free. To port to GTA VI, rewrite THIS FILE.
-- See docs/GTA6-READINESS.md (Section 3, the bridge pattern).
-- ============================================================================

Bridge = {}

-- Resolve the framework player object for a server source, or nil.
local function getPlayer(src)
    local ok, p = pcall(function() return exports.qbx_core:GetPlayer(src) end)
    return ok and p or nil
end

-- Stable per-character identity used as the key in our own tables.
function Bridge.GetCitizenId(src)
    local p = getPlayer(src)
    if not p or not p.PlayerData then return nil end
    return p.PlayerData.citizenid
end

-- RP display name (for rug reveals and the evidence log entry).
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

-- The character's gang name, or nil (gtarp_turf "verified" badge synergy).
function Bridge.GetGangName(src)
    local p = getPlayer(src)
    local g = p and p.PlayerData and p.PlayerData.gang
    if not g or not g.name or g.name == 'none' then return nil end
    return g.name
end

-- Current bank balance for an online source, or nil if not loaded.
function Bridge.GetBankBalance(src)
    local p = getPlayer(src)
    if not p or not p.PlayerData or not p.PlayerData.money then return nil end
    return p.PlayerData.money.bank or 0
end

-- Debit `amount` from the source's bank. Returns true on success.
-- Keeps the affordability pre-check before removing money.
function Bridge.ChargeBank(src, amount, reason)
    local p = getPlayer(src)
    if not p or not p.Functions then return false end
    if (p.PlayerData.money.bank or 0) < amount then return false end
    return p.Functions.RemoveMoney('bank', amount, reason) and true or false
end

-- Credit `amount` to an online source's bank. Returns true if applied.
function Bridge.CreditBank(src, amount, reason)
    local p = getPlayer(src)
    if not p or not p.Functions then return false end
    p.Functions.AddMoney('bank', amount, reason)
    return true
end

-- Credit `amount` to a character's bank by citizenid. Online -> framework
-- money API; offline -> direct write against the qbx players.money JSON so
-- delist settlements are never lost. This is the only place that JSON shape
-- is known (pattern lifted from gtarp_courier).
function Bridge.CreditBankByCitizenId(citizenid, amount, reason)
    for _, src in ipairs(GetPlayers()) do
        src = tonumber(src)
        local p = getPlayer(src)
        if p and p.PlayerData.citizenid == citizenid then
            p.Functions.AddMoney('bank', amount, reason)
            return true
        end
    end
    local ok = pcall(function()
        MySQL.update.await(
            "UPDATE players SET money = JSON_SET(money, '$.bank', CAST(JSON_EXTRACT(money,'$.bank') AS UNSIGNED) + ?) WHERE citizenid = ?",
            { amount, citizenid }
        )
    end)
    return ok
end

-- Server source for an online character, or nil (shill proximity + rug
-- broadcasts need to find the creator/holders if they are on).
function Bridge.GetSourceByCitizenId(citizenid)
    for _, src in ipairs(GetPlayers()) do
        src = tonumber(src)
        local p = getPlayer(src)
        if p and p.PlayerData and p.PlayerData.citizenid == citizenid then
            return src
        end
    end
    return nil
end

-- Current coords of a player's ped as {x,y,z}, or nil. Used for the
-- server-side exchange-proximity and shill-distance gates.
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

-- Notify a player.
function Bridge.Notify(src, title, msg, t)
    TriggerClientEvent('ox_lib:notify', src, {
        title = title, description = msg, type = t or 'inform',
    })
end

-- Notify every online player (rug reveals, shill announcements).
function Bridge.NotifyAll(title, msg, t)
    TriggerClientEvent('ox_lib:notify', -1, {
        title = title, description = msg, type = t or 'inform',
    })
end
