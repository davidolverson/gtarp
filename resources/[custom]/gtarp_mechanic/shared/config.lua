-- ============================================================================
-- gtarp_mechanic/shared/config.lua — engine-agnostic tunables (Tier 1, carries to VI).
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
