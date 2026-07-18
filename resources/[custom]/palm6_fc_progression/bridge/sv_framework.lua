-- ============================================================================
-- palm6_fc_progression/bridge/sv_framework.lua
-- Framework adapter (server). The ONLY file here that calls qbx_core / natives.
-- server/main.lua calls Bridge.* only (§6 gate) — ports to VI by rewriting this.
-- Rep is a cash-neutral ledger, so NO money functions are bridged here.
-- ============================================================================
Bridge = {}

local function getPlayer(src)
    local ok, p = pcall(function() return exports.qbx_core:GetPlayer(src) end)
    return ok and p or nil
end

-- Server source for an online character, or nil (offline winner just gets no toast).
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

-- Notify a player (ox_lib toast).
function Bridge.Notify(src, title, msg, t)
    TriggerClientEvent('ox_lib:notify', src, {
        title = title, description = msg, type = t or 'inform',
    })
end
