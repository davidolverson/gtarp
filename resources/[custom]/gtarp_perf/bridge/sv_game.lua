-- ============================================================================
-- gtarp_perf/bridge/sv_game.lua
--
-- Game/runtime adapter (server). The ONLY file in this resource that calls
-- the game timer native. Core logic (server/main.lua) calls Bridge.* only,
-- so the hitch sampler's ring buffer and p95/p99 math are engine-agnostic.
--
-- To port to GTA VI, rewrite THIS FILE against the new millisecond timer.
-- See docs/GTA6-READINESS.md (Section 3, the bridge pattern).
-- ============================================================================

Bridge = {}

-- Monotonic millisecond game timer used to measure server-thread hitches.
function Bridge.GetTimerMs()
    return GetGameTimer()
end
