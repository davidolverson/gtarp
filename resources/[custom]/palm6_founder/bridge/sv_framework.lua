-- ============================================================================
-- palm6_founder/bridge/sv_framework.lua
--
-- Platform adapter (server). The ONLY file that touches player identifiers, so
-- server/main.lua stays engine-agnostic. To port to GTA VI, rewrite this file
-- against the new identity API. Mirrors palm6_allowlist's bridge.
-- ============================================================================

Bridge = {}

-- The player's raw Discord id (no 'discord:' prefix), or nil.
function Bridge.GetDiscordId(src)
    local ids = GetPlayerIdentifiers(src) or {}
    for i = 1, #ids do
        if ids[i]:sub(1, 8) == 'discord:' then return ids[i]:sub(9) end
    end
    return nil
end
