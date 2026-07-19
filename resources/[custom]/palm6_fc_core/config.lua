-- ============================================================================
-- palm6_fc_core/config.lua — Def Jam fight-club SHARED data + constants.
-- COMBAT + CLIENT-DISPLAY authority (MONEY authority = palm6_fightclub/
-- shared/config.lua). Reached ONLY via exports.palm6_fc_core:Config() — never
-- a bare `Config` global from another resource (each resource = isolated Lua
-- state). DATA ONLY: zero behavior/events/threads. Loads in BOTH realms.
-- ============================================================================
Config = {}

-- HARD prod gate. Every fc resource checks exports.palm6_fc_core:Config().Enabled
-- before opening a match / running combat. Ships false = prod-inert.
-- TEST TOGGLE 2026-07-19 (uncommitted): flipped true to feel-test the fight club.
-- REVERT to false before any merge to main — the committed branch must stay dark.
Config.Enabled = true

-- Canonical ring (combat/arena read THIS; palm6_fightclub keeps its own
-- Config.Ring for atRing()). Coords retuned 2026-07-10 — VERIFY IN-GAME
-- (on-ground / reachable) before the combat feel-test (T6/T10 gate).
Config.Ring = {
    coords = { x = 108.0, y = -1305.0, z = 29.19 },  -- Vanilla Unicorn back lot, Strawberry
    radius = 15.0,
    label  = 'the fight ring (Vanilla Unicorn back lot)',
}

-- Fighter vitals (§6a). Server-owned per match; NEVER ped health.
Config.Vitals = {
    StartHP             = 100,
    MaxStamina          = 100,
    StaminaRegenPerSec  = 12,
    BlazinFullThreshold = 100,
}

-- Momentum gain (both fighters gain — the Def Jam feel).
Config.Momentum = {
    PerLandedHit = 12,
    PerTakenHit  = 6,
}

-- Move table (§6a) keyed by moveId. MVP ships all styles STAT-IDENTICAL —
-- styles differ only in clipset/anim feel (§8), so rep stays cash-neutral (§9).
Config.Moves = {
    jab      = { moveId = 'jab',      kind = 'light', damage = 6,  staminaCost = 4,  cooldownMs = 450,  activeWindowMs = 350, reach = 1.6, chipPct = 0.15, blockStamCost = 8  },
    cross    = { moveId = 'cross',    kind = 'light', damage = 9,  staminaCost = 7,  cooldownMs = 650,  activeWindowMs = 400, reach = 1.6, chipPct = 0.15, blockStamCost = 10 },
    hook     = { moveId = 'hook',     kind = 'heavy', damage = 15, staminaCost = 14, cooldownMs = 1100, activeWindowMs = 450, reach = 1.4, chipPct = 0.20, blockStamCost = 16 },
    uppercut = { moveId = 'uppercut', kind = 'heavy', damage = 18, staminaCost = 18, cooldownMs = 1300, activeWindowMs = 450, reach = 1.3, chipPct = 0.20, blockStamCost = 20 },
    body     = { moveId = 'body',     kind = 'heavy', damage = 13, staminaCost = 12, cooldownMs = 1000, activeWindowMs = 450, reach = 1.4, chipPct = 0.10, blockStamCost = 14 },
}

-- Lifecycle timers (§6a). Seconds unless the name says Ms.
Config.Timers = {
    ChallengeTTL = 20,
    BetWindowSec = 60,
    RoundSec     = 180,
    DrawBand     = 5,     -- HP% band → timeout draw
    RingPollSec  = 0.5,   -- ring-confinement poll cadence
    CountdownSec = 3,
}

-- Rep anchor (§6a) — single source of truth; §19.5 PvE fracs are RELATIVE to this.
Config.RepPerPvpWin = 100

-- Anti-farm knobs (§9).
Config.Rep = {
    RepCooldownSec           = 3600,  -- 1h per pairing (applies to win AND consolation)
    DailyRepCap              = 5,     -- wins' worth of rep / rolling 24h (shared with PvE)
    DailyDistinctOpponentCap = 4,
    LoserConsolation         = 0,     -- MVP off
}

-- Blazin finisher (§7).
Config.Blazin = {
    FullThreshold      = 100,
    HeavyQualifies     = true,
    MashReducePerHit   = 0.06,
    SceneDurationMs    = 3000,
    BaseFinisherDamage = 60,
}

-- Fallbacks when a player never opens SELECT. MUST reference real rows in
-- data.lua (asserted at boot in exports.lua).
Config.DefaultFighter = 'house_ace'
Config.DefaultStyle   = 'brawler'

Config.MaxCrowd = 12

-- CLIENT-DISPLAY MONEY MIRROR (§10b). These two values MUST equal the money
-- authority (palm6_fightclub Config.Fight.WinnerPursePct / Config.Betting.RakePct).
-- fc_core cannot read fightclub's isolated state, so the equality is cross-
-- asserted at FIGHTCLUB boot (T3), NOT here. HUD (T9) computes
-- takeout = RakePct + WinnerPursePct = 0.25 from these.
Config.WinnerPursePct = 0.15
Config.Betting = {
    RakePct          = 0.10,
    OddsBroadcastSec = 2,
    MinBet           = 50,
    MaxBet           = 5000,
}

-- §19.3 PvE block — SHIPS DARK (present, Enabled=false). Money-inert by
-- construction (is_pve=1 row, entry_pot=0, /fcbet rejects it). Difficulty is
-- policy-only (never HP/damage inflation). PveTierRepFrac = fraction of
-- RepPerPvpWin (asserted "full day < one PvP win" at boot in exports.lua).
Config.Pve = {
    Enabled                 = true,   -- TEST TOGGLE 2026-07-19 (uncommitted): flipped true for PvE feel-test; REVERT before merge
    MaxPop                  = 6,
    RequireNoHumanAtRing    = true,
    PreemptOnHumanChallenge = true,
    GrantsCash              = false,
    EntryFee                = 0,      -- PINNED 0 (§19.2)
    AiTickMs                = 250,
    CpuStepSpeed            = 2.2,    -- m/s, leashed to Ring.radius
    PveMinMatchSec          = 20,
    PveRepCooldownSec       = 3600,
    PveDailyRepGrantCap     = 3,
    DimFactor               = 0.5,
    PveCpuFinishers         = false,
    PveTierRepFrac = { T1 = 0.08, T2 = 0.14, T3 = 0.22, T4 = 0.32, T5 = 0.45 },
    Tiers = {
        { tier = 1, name = 'Rookie',    reactionMs = 800, blockChance = 0.10, aggression = 0.40, comboDepth = 1 },
        { tier = 2, name = 'Amateur',   reactionMs = 600, blockChance = 0.20, aggression = 0.60, comboDepth = 2 },
        { tier = 3, name = 'Contender', reactionMs = 450, blockChance = 0.35, aggression = 0.80, comboDepth = 2 },
        { tier = 4, name = 'Veteran',   reactionMs = 320, blockChance = 0.50, aggression = 1.00, comboDepth = 3 },
        { tier = 5, name = 'Legend',    reactionMs = 220, blockChance = 0.65, aggression = 1.00, comboDepth = 3 },
    },
    -- Original house-fighter CPUs, one per tier, on existing base ped models
    -- (zero custom assets). styleId must resolve to a Config.Styles id (asserted).
    CpuFighters = {
        { id = 'cpu_rook',    name = 'Freddy Fists', model = 'a_m_y_genstreet_01', styleId = 'brawler',   tier = 1 },
        { id = 'cpu_amateur', name = 'Lil Combo',    model = 'g_m_y_lost_01',      styleId = 'kickboxer', tier = 2 },
        { id = 'cpu_cont',    name = 'Marcus Steel', model = 'a_m_m_og_boss_01',   styleId = 'wrestler',  tier = 3 },
        { id = 'cpu_vet',     name = 'Old Snap',     model = 'g_m_m_armboss_01',   styleId = 'brawler',   tier = 4 },
        { id = 'cpu_legend',  name = 'The Warden',   model = 'a_m_m_bevhills_02',  styleId = 'wrestler',  tier = 5 },
    },
}
