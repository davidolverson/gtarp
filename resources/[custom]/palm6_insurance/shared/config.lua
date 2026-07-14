-- ============================================================================
-- palm6_insurance/shared/config.lua — engine-agnostic tunables (Tier 1,
-- carries to VI). Vehicle policies with a claim pipeline whose fraud
-- detection reads REAL city forensics: a damage claim with no
-- corresponding palm6_replay incident scene is exactly as suspicious as it
-- sounds. Flagged claims still pay (48-slot trust server) but open a
-- palm6_evidence case for police to work — insurance fraud is an RP hook,
-- not a mechanical denial.
-- ============================================================================
Config = {}

Config.Debug = false

-- The Mors Mutual desk. Both /insure and /fileclaim must be used within
-- radius of this point (server-checked against the caller's real coords).
Config.Office = {
    coords = { x = -815.09, y = -1078.97, z = 11.13 },  -- Little Seoul
    radius = 15.0,
    blip = { sprite = 524, color = 3, scale = 0.7, label = 'Mors Mutual Insurance' },
}

-- Underwriting. Vehicle value comes from the framework's vehicle catalog
-- (bridge), clamped to [MinValue, MaxValue]; unknown models underwrite at
-- MinValue.
Config.Underwriting = {
    PremiumPct  = 0.05,   -- one-time premium = 5% of value
    CoveragePct = 0.60,   -- max payout = 60% of value
    DeductibleP = 0.10,   -- deductible = 10% of coverage
    TermHours   = 72,     -- real hours a policy stays active
    MinValue    = 5000,
    MaxValue    = 300000,
    MinPremium  = 250,
}

-- Claims.
Config.Claims = {
    ProcessingSec   = 600,   -- payout lands this long after filing
    PerCitizenCdSec = 900,   -- one claim filed per citizen per this window
    MinDamageFrac   = 0.25,  -- below this combined damage the adjuster laughs you out
    TotalLossFrac   = 0.85,  -- at/above this combined damage a claim upgrades to total_loss
    TheftPayoutPct  = 1.0,   -- theft pays full coverage (minus deductible)
}

-- Fraud scoring. Signals sum; score >= FlagThreshold flags the claim and
-- opens an evidence case. All signals are server-derived — nothing here
-- trusts the client.
Config.Risk = {
    FlagThreshold    = 50,
    FreshPolicyMin   = 60,    -- policy younger than this (minutes) at filing
    FreshPolicyScore = 30,
    RepeatWindowH    = 48,    -- prior claims inside this window count
    RepeatScoreEach  = 20,    -- per prior claim
    NoSceneScore     = 35,    -- damage/total_loss with NO replay incident near the vehicle
    SceneRadius      = 120.0, -- metres from the vehicle at filing time
    SceneWindowMin   = 45,    -- replay scene must be at most this old (minutes)
    MaxPayoutScore   = 15,    -- claim that maxes the coverage cap
}

-- Per-source command cooldowns (seconds).
Config.RateLimits = {
    insure    = 5,
    fileclaim = 5,
    policy    = 2,
}
