-- ============================================================================
-- palm6_season/shared/config.lua
--
-- Tunables for the read-only season scoreboard: ladder registry, row limits,
-- rate limits, the admin ace name, and the OFF-by-default Discord tie-in.
-- No secrets, no framework calls. server/main.lua holds the SQL keyed by the
-- same ladder names listed here, so this file is the single list a reviewer
-- reads to know exactly what boards exist.
-- ============================================================================

Config = {}

Config.Debug          = false

Config.TopN           = 10      -- default rows returned by /seasontop
Config.MaxTopN        = 25      -- hard ceiling a caller (or the cache) may request
Config.SeasonCacheSec = 15      -- GetCurrentSeason() cache TTL (seconds)
Config.QueryCacheSec  = 30      -- per-ladder result cache TTL (rate-limit relief)
Config.CmdCooldownSec = 5       -- per-player cooldown on /season and /seasontop

-- Ace gating the admin season-control commands (/seasonopen, /seasonclose).
-- A human grants this after review, e.g. add_ace group.admin command.season allow.
Config.AdminAce       = 'command.season'

-- Optional Discord tie-in. OFF by default and never a hard dependency: with
-- DiscordEnable = false nothing is ever posted. DiscordFeed reuses an EXISTING
-- palm6_discord feed key ('live') so no edit to palm6_discord is required.
Config.DiscordEnable  = false
Config.DiscordFeed    = 'live'

-- Ladder registry. key -> { title, subject }. subject is 'gang' or 'citizen'.
-- The matching SQL builder for each key lives in server/main.lua.
Config.Ladders = {
    rep   = { title = 'Top Crews (reputation)', subject = 'gang'    },
    turf  = { title = 'Turf Held',              subject = 'gang'    },
    drugs = { title = 'Drug Empire',            subject = 'citizen' },
    dirty = { title = 'Dirtiest Hustler',       subject = 'citizen' },
    -- wanted = { title = 'Most Wanted',        subject = 'citizen' },  -- D2 variant
}

-- Deterministic display / archive order (string-keyed tables are unordered).
Config.LadderOrder = { 'rep', 'turf', 'drugs', 'dirty' }
