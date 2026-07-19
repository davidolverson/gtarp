-- ============================================================================
-- palm6_fc_arena/bridge/sv_framework.lua
-- Framework adapter (server). The ONLY server file calling qbx_core. Arena
-- moves NO money and touches NO DB — this exposes only cid<->src resolution.
-- ============================================================================
Bridge = {}

local function getPlayer(src)
    local ok, p = pcall(function() return exports.qbx_core:GetPlayer(src) end)
    return ok and p or nil
end

function Bridge.GetCitizenId(src)
    local p = getPlayer(src)
    return p and p.PlayerData and p.PlayerData.citizenid or nil
end

-- Server source for an online character, or nil (palm6_bounty precedent).
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

function Bridge.Notify(src, title, msg, t)
    TriggerClientEvent('ox_lib:notify', src, { title = title, description = msg, type = t or 'inform' })
end
