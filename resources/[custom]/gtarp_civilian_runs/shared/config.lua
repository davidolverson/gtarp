-- ============================================================================
-- gtarp_civilian_runs/shared/config.lua — engine-agnostic tunables (Tier 1, carries to VI).
--
-- Drives the "runs" already defined per-job in
-- qbx_civilian_jobs_overrides/config.lua (trucker/taxi/garbage/mechanic),
-- which were validated + exported (GetJobs/GetJob) but never actually had
-- a playable loop behind them. This resource is that loop: go to the
-- starter NPC, pick a run, drive to a destination, arrive in time, get
-- paid the run's configured payout.
--
-- Destination distance/time-limit scale by the run's position within its
-- job's `runs` array (index 1 = shortest, last = longest) — generic across
-- every curated job so this resource doesn't need job-specific logic.
-- ============================================================================
Config = {}

Config.Debug = false

Config.InteractRadius = 2.0
Config.ArrivalRadius = 15.0

-- [tier index] = { min, max } metres from the starter NPC for the random
-- destination point. Tier 4+ reuses the last entry.
Config.DestDistanceByTier = {
    { min = 150, max = 300 },
    { min = 300, max = 600 },
    { min = 600, max = 1000 },
}

-- [tier index] = seconds allowed to reach the destination. Tier 4+ reuses
-- the last entry. Generous — this times the drive, not a speedrun.
Config.TimeLimitByTier = { 90, 150, 220 }
