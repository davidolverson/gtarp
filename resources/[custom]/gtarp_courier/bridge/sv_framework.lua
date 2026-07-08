-- ============================================================================
-- gtarp_courier/bridge/sv_framework.lua
--
-- Framework adapter (server). The ONLY file in this resource that knows
-- about qbx_core, the qbx player/money API, the qbx players.money JSON
-- shape, or ox_lib notifications.
--
-- Core logic (server/main.lua) calls Bridge.* and nothing else. To port
-- this resource to a different framework (or to GTA VI), rewrite THIS FILE
-- against the new money/identity/notify API. Everything above it is
-- untouched.
--
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
    if not p then return nil end
    return p.PlayerData and p.PlayerData.citizenid or nil
end

-- Current bank balance for an online source, or nil if not loaded.
function Bridge.GetBankBalance(src)
    local p = getPlayer(src)
    if not p or not p.PlayerData or not p.PlayerData.money then return nil end
    return p.PlayerData.money.bank or 0
end

-- Debit `amount` from the source's bank (escrow). Returns true on success.
-- Preserves the original affordability pre-check before removing money.
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

-- Credit `amount` to a character's bank by citizenid. If the character is
-- online, use the framework money API; if offline, write the qbx
-- players.money JSON directly so the refund is never lost. This is the
-- only place the players.money JSON shape is known.
function Bridge.CreditBankByCitizenId(citizenid, amount, reason)
    for _, src in ipairs(GetPlayers()) do
        src = tonumber(src)
        local p = getPlayer(src)
        if p and p.PlayerData.citizenid == citizenid then
            p.Functions.AddMoney('bank', amount, reason)
            return true
        end
    end
    MySQL.update.await(
        "UPDATE players SET money = JSON_SET(money, '$.bank', CAST(JSON_EXTRACT(money,'$.bank') AS UNSIGNED) + ?) WHERE citizenid = ?",
        { amount, citizenid }
    )
    return true
end

-- Send a notification to a player.
function Bridge.Notify(src, title, msg, t)
    TriggerClientEvent('ox_lib:notify', src, {
        title = title, description = msg, type = t or 'inform',
    })
end

-- Current coords of a player's ped as {x,y,z}, or nil. This is the server's
-- OWN read of position — the delivery-complete handler never trusts the
-- client's own "I arrived" claim (see server/main.lua gtarp_courier:complete).
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
