-- ============================================================================
-- palm6_rapsheet/shared/config.lua, engine-agnostic tunables (Tier 1, carries
-- to VI). Mirrors the Config shape of palm6_blotter and palm6_citations.
--
-- The rap sheet is a READ-ONLY justice-record surface: it owns no table and
-- never writes. It reads existing law/enforcement records (citations, MDT
-- bookings, MDT warrants, bounty contracts) for a single citizen and prints
-- them. Every value here is a display or safety knob, never a source of truth.
-- ============================================================================
Config = {}

Config.Debug = false

-- On-duty gate for /priors. Confirmed real: qbx job name 'police' with
-- job.onduty == true (proven by palm6_citations / palm6_blotter
-- Bridge.IsOnDutyPolice).
Config.PoliceJob = 'police'

-- Server console and this ace may run /priors without the police gate, so
-- staff can pull a citizen's sheet. Mirrors palm6_blotter Config.AdminAce.
Config.AdminAce = 'command.priors'

-- Per-section row caps for the listed (not just counted) records. Each list
-- query is capped to at most MaxRows regardless of the per-section value.
Config.Lists = {
    Citations = 8,   -- outstanding citations shown in the sheet
    Bookings  = 8,   -- unsealed bookings/arrests shown in the sheet
    Warrants  = 8,   -- active warrants shown in the sheet
    Bounties  = 8,   -- active bounties targeting the citizen
    MaxRows   = 15,  -- hard ceiling any list query is capped to
}

-- Longest free-text field (charges, reasons) before it is trimmed for display.
Config.TextClamp = 80

-- Per-source command cooldowns (seconds), mirroring palm6_blotter.RateLimits.
Config.RateLimits = {
    rapsheet = 5,
    record   = 5,
}
