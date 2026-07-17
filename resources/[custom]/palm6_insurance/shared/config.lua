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
-- MinValue. The per-tier rates (premium/coverage/deductible/term) live in
-- Config.Tiers below; these are the global, tier-independent bounds.
Config.Underwriting = {
    MinValue    = 5000,
    MaxValue    = 300000,
    MinPremium  = 250,
    -- Re-insure lock window (global anti-faucet): after a paid/processing DAMAGE
    -- claim a plate can't be re-insured for this long, so the same unrepaired
    -- damage can't fund a second claim. Kept >= the longest tier term.
    ReinsureLockHours = 120,
}

-- Plan tiers, sold by the Mors Mutual agent. `standard` reproduces the old flat
-- plan exactly, so policies issued before tiers existed (backfilled to
-- 'standard' by sql/0064) behave identically. PremiumPct is % of clamped
-- vehicle value; CoveragePct is the payout cap (% of value); DeductibleP is the
-- deductible as % of coverage; ProcessingSec is how long a claim takes to pay;
-- TheftPayoutPct is the fraction of coverage a theft claim pays (Premium = full).
Config.DefaultTier = 'standard'   -- tier used by the bare /insure command
Config.TierOrder   = { 'basic', 'standard', 'premium' }
Config.Tiers = {
    basic = {
        key = 'basic', label = 'Basic', order = 1,
        PremiumPct = 0.03, CoveragePct = 0.40, DeductibleP = 0.15,
        TermHours = 48, ProcessingSec = 900, TheftPayoutPct = 0.70,
        blurb = 'Bare-minimum cover. Cheapest premium, higher deductible, slower payout.',
    },
    standard = {
        key = 'standard', label = 'Standard', order = 2,
        -- Reproduces the pre-tier flat plan EXACTLY (incl. theft at full
        -- coverage), so 0064-backfilled policies are unchanged.
        PremiumPct = 0.05, CoveragePct = 0.60, DeductibleP = 0.10,
        TermHours = 72, ProcessingSec = 600, TheftPayoutPct = 1.00,
        blurb = 'The everyday plan. Balanced cover and cost.',
    },
    premium = {
        key = 'premium', label = 'Premium', order = 3,
        PremiumPct = 0.08, CoveragePct = 0.85, DeductibleP = 0.05,
        TermHours = 120, ProcessingSec = 180, TheftPayoutPct = 1.00,
        blurb = 'Full protection. Highest coverage cap, lowest deductible, fastest payout, longest term.',
    },
}

-- The insurance agent NPC that stands at the desk. Interacting with it opens
-- the plan/claim menu; the map blip stays too. z is dropped 1.0 by the spawn
-- helper so the ped stands on the floor.
Config.Agent = {
    model   = 'a_m_m_business_01',
    coords  = { x = -815.09, y = -1078.97, z = 11.13 },  -- the Office desk
    heading = 123.0,
    label   = 'Talk to the insurance agent',
    icon    = 'fa-solid fa-file-contract',
}

-- Claims. (Payout SPEED and theft % are per-tier — see Config.Tiers.)
Config.Claims = {
    PerCitizenCdSec = 900,   -- one claim filed per citizen per this window
    MinDamageFrac   = 0.25,  -- below this combined damage the adjuster laughs you out
    TotalLossFrac   = 0.85,  -- at/above this combined damage a claim upgrades to total_loss
    -- A DAMAGE claim leaves the (repairable) car with its owner, so it must not
    -- pay out the full coverage cap — that basis is meant for a CONSUMED car
    -- (theft / total-loss). Cap the damage-claim basis at this fraction of the
    -- vehicle's value across ALL tiers, so a damage payout never scales with the
    -- plan tier (Premium's higher cap only pays out when the car is actually
    -- gone). This bounds the long-standing "keep the car AND bank a repair
    -- claim" loop; it does NOT eliminate it (insurance fraud is a deliberate RP
    -- hook here — flagged claims still pay and open a police case). 0.60 keeps
    -- Basic/Standard damage payouts identical to before the tier change.
    DamageCoverageCapPct = 0.60,
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

-- Per-source command / agent-event cooldowns (seconds).
Config.RateLimits = {
    insure    = 5,
    fileclaim = 5,
    policy    = 2,
    quote     = 2,
    claimlist = 2,   -- distinct from `policy` so the two read-only agent menus don't share a budget
}
