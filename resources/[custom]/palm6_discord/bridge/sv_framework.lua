-- ============================================================================
-- palm6_discord/bridge/sv_framework.lua
--
-- Runtime adapter (server). The ONLY file in this resource that calls the
-- HTTP native or reads convars. server/main.lua calls Bridge.* only, so the
-- queue/rate-limit/embed logic ports to GTA VI by rewriting THIS FILE.
-- See docs/GTA6-READINESS.md (Section 3, the bridge pattern).
-- ============================================================================

Bridge = {}

-- POST a JSON body; cb(statusCode, responseText, headers).
function Bridge.HttpPostJson(url, body, cb)
    PerformHttpRequest(url, function(status, text, headers)
        cb(status, text, headers or {})
    end, 'POST', body, { ['Content-Type'] = 'application/json' })
end

function Bridge.GetConvar(name)
    local v = GetConvar(name, '')
    return v ~= '' and v or nil
end
