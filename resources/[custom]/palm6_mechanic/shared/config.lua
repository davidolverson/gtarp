-- ============================================================================
-- palm6_mechanic/shared/config.lua — engine-agnostic tunables (Tier 1, carries to VI).
-- ============================================================================
Config = {}

Config.Debug = false

-- How close the mechanic must be to the vehicle to start a repair.
Config.InteractRadius = 3.0

-- How far from the vehicle to look for another player to invoice. Mechanic
-- income is repair invoices to other players, not self-service — see
-- qbx_civilian_jobs_overrides/config.lua's mechanic job comment.
Config.CustomerSearchRadius = 8.0

-- Flat repair invoice, paid in full from the customer's bank to the
-- mechanic's bank.
Config.RepairCost = 350

-- Per-vehicle cooldown after a repair, so the same vehicle can't be
-- immediately re-invoiced.
Config.RepairCooldownSeconds = 45

-- A vehicle is considered damaged (and thus repairable) when either health
-- value drops below its threshold. Native max is ~1000.0 for both.
Config.EngineHealthThreshold = 900.0
Config.BodyHealthThreshold = 900.0

Config.ProgressMs = 6000

-- Self-serve vehicle kits (usable ox_inventory items) — makes the already-sold
-- repair_kit / tirepack actually do something. Complementary to the mechanic
-- invoice job (self-service, no mechanic needed). The item is consumed
-- server-side BEFORE the repair; using a kit away from a vehicle spends it.
Config.Kits = {
    Enabled    = true,
    RepairItem = 'repair_kit',   -- full engine/body/deformation repair
    TireItem   = 'tirepack',     -- replaces all tyres
    Radius     = 5.0,            -- how close a vehicle must be to work on it
}
