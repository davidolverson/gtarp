-- ============================================================================
-- gtarp_onboarding/bridge/sv_framework.lua
--
-- Framework adapter (server). The ONLY file in this resource that calls
-- qbx_core / framework exports or server-side game natives. server/main.lua
-- calls Bridge.* only, so its logic ports to GTA VI by rewriting THIS FILE.
-- See docs/GTA6-READINESS.md (Section 3, the bridge pattern).
-- ============================================================================

Bridge = {}

local function getPlayer(src)
    local ok, p = pcall(function() return exports.qbx_core:GetPlayer(src) end)
    return ok and p or nil
end

-- Stable per-character id, or nil.
function Bridge.GetCitizenId(src)
    local p = getPlayer(src)
    if not p or not p.PlayerData then return nil end
    return p.PlayerData.citizenid
end

-- Credit `amount` to the source's bank. Returns true if applied.
function Bridge.CreditBank(src, amount, reason)
    local p = getPlayer(src)
    if not p or not p.Functions then return false end
    p.Functions.AddMoney('bank', amount, reason)
    return true
end

-- Notify a player.
function Bridge.Notify(src, title, msg, t)
    TriggerClientEvent('ox_lib:notify', src, {
        title = title, description = msg, type = t or 'inform',
    })
end

-- Register a callback fired once a character is loaded and in the world,
-- server-side. Hides the framework's loaded-event name (same convention as
-- the client-side Game.OnPlayerLoaded in server_base/gtarp_turf/
-- server_identity — see their bridge/cl_game.lua). qbx_core fires
-- QBCore:Server:OnPlayerLoaded from server/events.lua with `source` set to
-- the newly-loaded player.
function Bridge.OnPlayerLoaded(handler)
    RegisterNetEvent('QBCore:Server:OnPlayerLoaded', function()
        handler(source)
    end)
end

function Bridge.RegisterCommand(name, handler)
    RegisterCommand(name, handler, false)
end

function Bridge.ResourceStarted(name)
    return GetResourceState(name) == 'started'
end
