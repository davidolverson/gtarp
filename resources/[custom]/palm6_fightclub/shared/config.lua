-- ============================================================================
-- palm6_fightclub/shared/config.lua — engine-agnostic tunables (Tier 1,
-- carries to VI). An underground bare-knuckle ring: two citizens queue up
-- at the ring, a match opens a betting window, spectators wager cash on
-- either fighter, then the fight runs unarmed and server-monitored until a
-- knockout, a forfeit (leaving the ring / drawing a weapon / disconnect),
-- or a timeout draw. Payouts are a parimutuel pool split among winning
-- bettors, minus a house rake, plus a purse cut straight to the winner.
-- ============================================================================
Config = {}

Config.Debug = false

-- The ring. Queueing and fighting both require being here (server-checked
-- against real coords, never client-trusted). Placeholder Tier-3 coords
-- (see docs/GTA6-READINESS.md) — retune once a real MLO/prop is picked.
Config.Ring = {
    -- retuned 2026-07-10 — VERIFY IN-GAME (on-ground/reachable)
    coords = { x = 108.0, y = -1305.0, z = 29.19 },  -- Vanilla Unicorn back lot, Strawberry
    radius = 15.0,
    label = 'the fight ring (Vanilla Unicorn back lot)',
}

-- Betting window. Spectators only — fighters cannot bet on their own match
-- (checked server-side against both fighters' citizenids).
Config.Betting = {
    WindowSec        = 60,
    MinBet           = 50,
    MaxBet           = 5000,
    RakePct          = 0.10,    -- house cut of the betting pool — an economy sink
    OddsBroadcastSec = 2,       -- tote-board throttle (T6 per-match timer cadence)
    MaxPoolPerMatch  = 50000,   -- aggregate match-fix cap; folded into the atomic
                                -- /fcbet insert (no TOCTOU); 0 disables the cap
}

-- The fight itself. Server-monitored, never client-trusted: health,
-- position, and current weapon are all read off the live synced peds
-- (same technique palm6_bounty's /capture uses).
Config.Fight = {
    -- §10b two-layer paid fighter (self-funded ante on top of the betting pool).
    EntryStake       = 500,   -- ante per fighter; 0 = for-rep-only (charge skipped, layer no-ops)
    EntryRakePct     = 0.10,  -- sink on the entry pot (anti-collusion); 0 = zero-sum wash (still no mint)
    EntryPotLoserPct = 0.0,   -- MVP off; boot-assert EntryRakePct+this<=1 AND this<0.5
    WinnerPursePct   = 0.15,  -- UNCHANGED: winner's cut of the betting pool
    -- (Legacy combat knobs KOHealth/MaxDurationSec/PollSec/RequireUnarmed removed —
    -- the fight lifecycle + combat now live entirely in palm6_fc_combat / fc_core.)
}

-- Per-source command cooldowns (seconds) — chat-command spam guard, distinct
-- from the queue/betting rules above.
Config.RateLimits = {
    fcbet     = 2,
    fcmatches = 2,
    fcdebug   = 1,   -- dev harness throttle (per-src; console src==0 bypasses)
    -- fcjoin/fcleave removed (queue deleted).
}
