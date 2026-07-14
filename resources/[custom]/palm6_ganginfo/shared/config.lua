-- ============================================================================
-- palm6_ganginfo/shared/config.lua, engine-agnostic tunables (Tier 1, carries
-- to VI). Mirrors the Config shape of palm6_blotter.
--
-- ganginfo is a READ-ONLY public gang directory: it owns no table and never
-- writes. /ganginfo <tag> prints one gang's public profile (name, tag, rep,
-- member count, turf zones held, founded date, blurb). /gangs prints the top
-- gangs ranked by reputation. Every value here is a display or safety knob,
-- never a source of truth.
-- ============================================================================
Config = {}

Config.Debug = false

-- List caps for the /gangs leaderboard.
Config.List = {
    Top    = 10,   -- /gangs with no argument shows this many gangs
    MaxTop = 25,   -- hard ceiling any /gangs [n] request is clamped to
}

-- Longest free-text blurb (palm6_gangs.description) shown before it is trimmed.
Config.TextClamp = 120

-- Per-source command cooldowns (seconds), mirroring palm6_blotter.RateLimits.
-- The server console (source 0) bypasses these.
Config.RateLimits = {
    ganginfo = 3,
    gangs    = 5,
}
