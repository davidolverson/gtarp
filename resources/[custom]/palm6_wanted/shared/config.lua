-- ============================================================================
-- palm6_wanted/shared/config.lua, engine-agnostic tunables (Tier 1, carries
-- to VI). Mirrors the Config shape of palm6_blotter and palm6_ems.
--
-- palm6_wanted is a READ-ONLY, PLAYER-FACING civic surface: it owns no table
-- and never writes. It aggregates records other resources own (MDT warrants,
-- bounty contracts, MDT BOLOs) into two views:
--   - /wanted    : an in-character PUBLIC most-wanted board (top active
--                  warrants + top active bounties), for any citizen.
--   - /amiwanted : the caller's OWN active warrants, bounties on their head,
--                  and BOLOs naming them ("are you hot?").
-- Every value here is a display or safety knob, never a source of truth.
--
-- Distinct from palm6_blotter: the blotter is an on-duty-POLICE enforcement
-- digest (citation dollars, bookings, 911 calls). This resource shows no
-- police stats and has no on-duty gate, it is the citizen-facing wanted board.
-- ============================================================================
Config = {}

Config.Debug = false

-- The public board is IN-CHARACTER public: warrants and bounties are already
-- surfaced publicly IC (the web /blotter, the bounty board). Showing the named
-- citizen is consistent with that, but it is gated behind this flag so the
-- posture is one edit away. When false, names on the PUBLIC board are withheld
-- (the self-check always shows the caller their own detail regardless).
Config.ShowNames = true

-- Label substituted for a name on the public board when Config.ShowNames is
-- false. Kept in-character.
Config.WithheldLabel = '(name withheld)'

-- Per-view row caps for the public board. Each list is a parameterized,
-- LIMIT-capped SELECT, most-wanted first.
Config.Board = {
    Warrants = 8,    -- active warrants shown on /wanted (newest first)
    Bounties = 8,    -- active bounties shown on /wanted (highest amount first)
    MaxRows  = 20,   -- hard ceiling any board list query is capped to
}

-- Per-view row caps for the personal /amiwanted self-check.
Config.Self = {
    Warrants = 10,   -- caller's own active warrants listed
    Bounties = 10,   -- active bounties targeting the caller listed
    Bolos    = 10,   -- active BOLOs naming the caller listed
    MaxRows  = 20,   -- hard ceiling any self-check list query is capped to
}

-- Longest free-text reason/body line before it is trimmed for display.
Config.TextClamp = 80

-- Per-source command cooldowns (seconds), mirroring palm6_blotter.RateLimits.
Config.RateLimits = {
    wanted   = 5,
    amiwanted = 5,
}

-- In-character framing strings for the chat output headers. Pure display.
Config.Framing = {
    BoardTitle    = 'Los Santos Most Wanted',
    WarrantsTitle = 'Active warrants',
    BountiesTitle = 'Open bounties',
    SelfTitle     = 'Your wanted status',
    Clean         = 'You are clean. No active warrants, bounties or BOLOs on record.',
}
