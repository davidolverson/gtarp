-- ============================================================================
-- gtarp_yard/shared/config.lua
--
-- The Bolingbroke prison economy. Three server-authoritative surfaces layered
-- on top of xt-prison (the only jail system in the recipe):
--   LABOR      — shave your OWN sentence by working yard tasks. The shave is
--                server-computed, capped at 50% of the sentence (jail must
--                always cost something), and paid BELOW street rate so it is a
--                grievance-reliever, not an earner.
--   COMMISSARY — a buy-only cash shop (markup pricing + a daily per-item cap)
--                so there is no buy-low / resell-high loop.
--   BAIL       — pretrial release at a SUPERLINEAR price with a hard floor
--                above typical crime payout; releasing re-issues an mdt warrant
--                (gtarp_bounty then auto-posts a state contract on its sweep),
--                so bail is a skip, not a clean slate.
--
-- The DESIGN (loops, tuning, invariants) is Tier 1 and carries to GTA VI. The
-- COORDS are Tier 3 placeholders at Bolingbroke — VERIFY IN-GAME and move.
-- ============================================================================

Config = {}

Config.Debug = false

-- ---------------------------------------------------------------------------
-- Station coordinates (Tier-3 PLACEHOLDERS at Bolingbroke — confirm in-game).
-- The SERVER re-derives the caller's ped position and checks it against these;
-- the client sends no coordinates.
-- ---------------------------------------------------------------------------
Config.Coords = {
    Labor      = vector3(1800.00, 2600.00, 46.00),
    Commissary = vector3(1780.00, 2600.00, 46.00),
    Bail       = vector3(1690.00, 2560.00, 45.00),
}

-- Interaction radius (metres) for each station, plus the slack the server adds
-- on top when validating proximity (client target zone vs. server truth).
Config.InteractRadius = 2.0
Config.ProximitySlack = 2.0

-- ---------------------------------------------------------------------------
-- LABOR — sentence-shaving yard work.
--   * Pay is a flat cash trickle, deliberately BELOW street earning.
--   * CooldownSec is PERSISTED (gtarp_yard_labor) so relog-to-reset is blocked.
--   * Each task shaves ShaveMinutes off the CURRENT jail time, but the running
--     total is capped at ShaveCapPct of the sentence BASELINE. jailTime in
--     xt-prison is in MINUTES (granularity 1 min), so ShaveMinutes = 1 is the
--     ~20-40s research band rounded to the system's unit.
-- ---------------------------------------------------------------------------
Config.Labor = {
    Pay          = 75,     -- $50-100 band, below street
    CooldownSec  = 35,     -- 30-45s cadence
    ShaveMinutes = 1,      -- minutes shaved per completed task (xt-prison unit)
    ShaveCapPct  = 0.5,    -- total shave can never exceed 50% of the baseline
    TaskSeconds  = 6,      -- cosmetic client progress-bar length
    Label        = 'Prison Labor',
}

-- ---------------------------------------------------------------------------
-- COMMISSARY — buy-only cash shop. Prices are SERVER-OWNED (the client picks
-- item + qty only). Markup + a daily per-item cap (gtarp_yard_commissary_log)
-- kill the buy-low / resell-high loop; yard_soap is flagged contraband with no
-- market buyback. `price` already bakes in the ~1.5x street markup.
-- ---------------------------------------------------------------------------
Config.Commissary = {
    Account         = 'cash',
    CooldownSec     = 1,     -- serialises a single player's concurrent buys
    DailyCapPerItem = 5,     -- per character, per item, per day
    Label           = 'Commissary',
    Items = {
        { item = 'yard_commissary_snack', label = 'Commissary Snack', price = 25 },
        { item = 'yard_pruno',            label = 'Pruno (Prison Hooch)', price = 60 },
        { item = 'yard_soap',             label = 'Bar of Soap', price = 40 },
    },
}

-- ---------------------------------------------------------------------------
-- BAIL — pretrial release.
--   bail = Base + floor(remainingSeconds^Exp * K), floored at Floor.
-- Superlinear in remaining time and floored ABOVE a typical crime payout so it
-- stays a deterrent. Releasing sets jailTime to 0, returns confiscated items,
-- and re-issues an mdt warrant (the skip flag) — gtarp_bounty auto-posts the
-- state contract on its own 180s sweep, so we wire nothing there.
-- ---------------------------------------------------------------------------
Config.Bail = {
    Account             = 'bank',
    Base                = 500,
    K                   = 0.02,
    Exp                 = 1.15,
    Floor               = 2500,   -- above typical crime payout
    RearrestCooldownSec = 600,    -- audited on the bail row; kills bail-then-instant-crime
    CooldownSec         = 3,      -- anti-spam on the terminal itself
    WarrantReason       = 'Failure to appear (bail jump)',
    OfficerLabel        = 'Court',
    Label               = 'Bail Bond Terminal',
}

-- ---------------------------------------------------------------------------
-- NEW ox_inventory items this resource owns. They are NOT edited into items.lua
-- by this resource — they are RETURNED as a wiring delta for the orchestrator.
-- gtarp_yard self-disables LOUDLY at boot if any are missing (mirrors
-- gtarp_drugs). Every commissary item must be in this list.
-- ---------------------------------------------------------------------------
Config.RequiredItems = {
    'yard_commissary_snack',
    'yard_pruno',
    'yard_soap',
}

-- Map blips (Tier-3). Sprite/colour are GTA V blip ids.
Config.Blips = {
    Labor      = { sprite = 477, colour = 5,  scale = 0.8, label = 'Prison Labor' },
    Commissary = { sprite = 52,  colour = 2,  scale = 0.8, label = 'Commissary' },
    Bail       = { sprite = 188, colour = 3,  scale = 0.8, label = 'Bail Bond Terminal' },
}
