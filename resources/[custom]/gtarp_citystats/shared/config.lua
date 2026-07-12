-- ============================================================================
-- gtarp_citystats/shared/config.lua, engine-agnostic tunables (Tier 1, carries
-- to VI). Mirrors the Config shape of gtarp_blotter and gtarp_economy.
--
-- citystats is a READ-ONLY civic-visibility surface: it owns no table and never
-- writes. It is the in-game version of the website /city page
-- (palm6/web/src/lib/economy.ts), aggregating existing gang, drug-economy and
-- warrant records into one summary that /citystats prints for any citizen.
-- Every value here is a display or safety knob, never a source of truth.
-- ============================================================================
Config = {}

Config.Debug = false

-- Server console and this ace may always run /citystats. Any online citizen may
-- run it too (no job gate): these are public city aggregates, mirroring the
-- public website /city page. The ace only matters if a section is ever gated.
Config.AdminAce = 'command.citystats'

-- Recent window for the time-bounded sections (drug economy). The gang, vault
-- and warrant aggregates are point-in-time totals and ignore this window.
Config.Window = {
    DefaultHours = 168,  -- /citystats with no argument looks back this far (one week)
    MaxHours     = 720,  -- clamp: 30 days is the deepest a caller may ask for
    MinHours     = 1,    -- clamp floor
}

-- Per-source command cooldown (seconds), mirroring gtarp_blotter.RateLimits.
Config.RateLimits = {
    citystats = 10,
}

-- Rows to show in the "top gangs by reputation" list.
Config.TopGangs = 3     -- how many top gangs to list
Config.MaxRows  = 10    -- hard ceiling any list query is capped to

-- Longest gang name / tag line before it is trimmed for display.
Config.TextClamp = 40

-- Which sections are computed and printed. Flip any to false to hide it (and
-- skip its query). Each maps to one pcall-wrapped section in server/main.lua.
Config.Stats = {
    Gangs    = true,   -- gtarp_gangs: count + city vault + top gangs by rep
    Members  = true,   -- gtarp_gang_members: affiliated citizen count
    Drugs    = true,   -- gtarp_drugs_sales: dirty moved + sale count in window
    Warrants = true,   -- gtarp_mdt_warrants: active warrant count
}
