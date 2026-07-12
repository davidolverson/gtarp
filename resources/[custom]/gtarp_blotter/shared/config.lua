-- ============================================================================
-- gtarp_blotter/shared/config.lua, engine-agnostic tunables (Tier 1, carries
-- to VI). Mirrors the Config shape of gtarp_citations and gtarp_ems.
--
-- The blotter is a READ-ONLY civic-visibility surface: it owns no table and
-- never writes. It aggregates existing law/enforcement records (citations,
-- MDT bookings, MDT 911 calls) into a single windowed summary for on-duty
-- police, and can (optionally, off by default) post that summary to Discord.
-- Every value here is a display or safety knob, never a source of truth.
-- ============================================================================
Config = {}

Config.Debug = false

-- On-duty gate. Confirmed real: qbx job name 'police' with job.onduty == true
-- (proven by gtarp_citations Bridge.IsOnDutyPolice).
Config.PoliceJob = 'police'

-- Server console and this ace may run /blotter without the police gate, so
-- staff can pull the summary. Mirrors gtarp_season Config.AdminAce.
Config.AdminAce = 'command.blotter'

-- Recent window for the aggregate. All queries are parameterized windowed
-- SELECTs over these hour bounds, newest first.
Config.Window = {
    DefaultHours = 24,   -- /blotter with no argument looks back this far
    MaxHours     = 168,  -- clamp: one week is the deepest a caller may ask for
}

-- Per-section row caps for the listed (not just counted) records.
Config.Lists = {
    Bookings = 6,   -- recent bookings/arrests shown in the /blotter output
    Calls    = 6,   -- recent 911 calls shown in the /blotter output
    MaxRows  = 15,  -- hard ceiling any list query is capped to
}

-- Longest booking charges/call text line before it is trimmed for display.
Config.TextClamp = 80

-- Per-source command cooldowns (seconds), mirroring gtarp_citations.RateLimits.
Config.RateLimits = {
    blotter = 5,
}

-- OPTIONAL weekly Discord digest, OFF by default. Reuses the existing
-- 'police' feed key because a dedicated feed would require editing
-- gtarp_discord's config (a live file we must not touch). When Enabled is
-- true and gtarp_discord is started, a single timer thread posts one embed
-- every IntervalHours summarizing the last WindowHours.
Config.Digest = {
    Enabled       = false,
    Feed          = 'police',
    IntervalHours = 168,     -- how often the digest fires (weekly)
    WindowHours   = 168,     -- how far back the digest summarizes (one week)
    BootDelayMs   = 60000,   -- wait after start before the first tick (let the DB settle)
}
