-- ============================================================================
-- palm6_eventguard/bridge/sv_framework.lua
--
-- Framework/runtime adapter (server). The ONLY file in this resource that
-- reads player identifiers or drops (kicks) a player. Core logic
-- (server/main.lua) calls Bridge.* only, so the ratelimit buckets, the
-- breach accounting, and the kick decision are engine-agnostic.
--
-- The guarded event NAMES (e.g. QBCore:Server:UpdateMoney) live in
-- config.lua as data and are re-pointed per framework, not here.
--
-- See docs/GTA6-READINESS.md (Section 3, the bridge pattern).
-- ============================================================================

Bridge = {}

-- Primary identifier for a server source (used to label a violation row).
function Bridge.GetPrimaryIdentifier(src)
    local ids = GetPlayerIdentifiers(src) or {}
    return ids[1] or ''
end

-- Kick a player from the server with a reason string.
function Bridge.Kick(src, reason)
    DropPlayer(src, reason)
end
