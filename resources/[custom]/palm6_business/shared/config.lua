-- ============================================================================
-- palm6_business/shared/config.lua — engine-agnostic tunables.
--
-- DESIGN INTENT — the player-owned BUSINESS layer neither Qbox nor qbx_management
-- ships. qbx_management provides society bank accounts + boss menus for the
-- whitelisted JOBS (police/EMS/mechanic). It has NO concept of a civilian
-- business a player REGISTERS and RUNS: a registry, an account, employees,
-- payroll, walk-in revenue, and a ledger. That is this resource's scope, built
-- on our own tables (palm6_businesses / palm6_business_members /
-- palm6_business_ledger) — the same player-run-org shape as palm6_gangs.
--
-- MONEY SAFETY: a business is a POOLED REAL-MONEY account (like a gang vault),
-- never a printer. Money enters only via owner deposit, customer charge, and the
-- ONE capped NPC-income faucet (§ below). See docs/superpowers/specs/
-- 2026-07-20-palm6-business-design.md §2 for the full invariant list.
-- ============================================================================
Config = {}

Config.Debug = false

-- MASTER GATE. false = prod-inert: commands refuse, net events early-return,
-- nothing player-facing registers. Flip true (+ redeploy) to go live, batched
-- with a feel-test. Mirrors the palm6_racing / palm6_fc_core dark-ship idiom.
Config.Enabled = false

-- Command that opens the business menu (+ a short alias).
Config.Command = 'business'
Config.CommandAlias = 'biz'

-- ---------------------------------------------------------------------------
-- Registration
-- ---------------------------------------------------------------------------
-- One-time fee to register a business, charged from the founder's BANK (server
-- re-validates affordability before creating). A clean-money SINK. Set 0 = free.
Config.RegistrationCost = 75000

-- Name: 3-48 chars after sanitising to letters/digits/spaces/&'- (collapsed).
Config.NameMinLen = 3
Config.NameMaxLen = 48

-- Case-insensitive substring blocklist for the business name (first-line
-- profanity/impersonation filter — staff can still close via DB). Mirrors the
-- palm6_gangs blocklist.
Config.Blocklist = {
    'nigger', 'faggot', 'retard', 'rape', 'nazi', 'hitler', 'kkk',
    'cunt', 'admin', 'staff', 'police', 'server',
}

-- Business catalog. `label` shows in the register picker + roster. `flavor` is
-- cosmetic copy. All types share the same mechanics in Phase 0 (the difference
-- is roleplay identity + future storefront/venue hooks in Phase 1). Extensible.
Config.Types = {
    { key = 'restaurant', label = 'Restaurant',   flavor = 'Serve the city. Keep the lights on.' },
    { key = 'bar',        label = 'Bar / Venue',  flavor = 'Own the room. Turn a night into an institution.' },
    { key = 'garage',     label = 'Garage / Shop',flavor = 'A service people come back to.' },
    { key = 'retail',     label = 'Retail Front', flavor = 'A legit storefront on the map.' },
    { key = 'dealership',  label = 'Dealership',   flavor = 'Move product. Build a name.' },
}

-- ---------------------------------------------------------------------------
-- Roster / roles. Higher number = more authority. OWN ranks (palm6_business_
-- members.role stores these). Room left at 2 for a future Manager delegate.
-- ---------------------------------------------------------------------------
Config.Role = { Employee = 1, Manager = 2, Owner = 3 }
Config.RoleName = { [1] = 'Employee', [2] = 'Manager', [3] = 'Owner' }

Config.MaxEmployees = 10  -- excludes the owner (roster cap = MaxEmployees + 1)

-- Hire: the owner's nearest UNAFFILIATED online player within this radius gets
-- the prompt. The server picks the target from real ped positions; the client
-- never names who to hire (mirrors the palm6_gangs invite model). Expires.
Config.HireRadius = 6.0
Config.HireExpirySec = 60
Config.HireCooldownSec = 10  -- per owner, anti-spam (a hire pops a confirm dialog)

-- ---------------------------------------------------------------------------
-- Account (BANK money — clean, auditable). Deposits pull the owner's bank;
-- withdrawals + payroll + wages credit a bank. Every move is atomic + logged.
-- ---------------------------------------------------------------------------
Config.MinAmount = 1
Config.MaxPerAction = 1000000  -- sanity clamp on a single deposit/withdraw

-- Wage: the per-payroll-run amount an owner sets per employee. Clamp only.
Config.MaxWage = 100000

-- ---------------------------------------------------------------------------
-- Customer charge (player -> business). The owner/employee rings up the nearest
-- player, who CONFIRMS before their bank is charged. Pure redistribution.
-- ---------------------------------------------------------------------------
Config.ChargeRadius = 6.0
Config.ChargeExpirySec = 45
Config.ChargeMax = 100000
Config.ChargeCooldownSec = 5  -- per cashier, anti-spam

-- ---------------------------------------------------------------------------
-- NPC walk-in income — the ONE faucet. Bounded four ways (cost basis + active
-- work + per-employee cooldown + per-business daily cap). See spec §6.
-- ---------------------------------------------------------------------------
-- Owner buys SUPPLY with clean bank money (a SINK) before any NPC income is
-- possible. Each serve consumes 1 unit. This cost basis is the primary limiter:
-- net margin per unit = ServePayout - StockUnitCost, bounded and small.
Config.StockUnitCost = 120       -- clean bank $ per supply unit
Config.MaxSupplyUnits = 500      -- storage cap (prevents infinite pre-stocking)
Config.StockMaxPerBuy = 100      -- units per buy action (clamp)

-- Each serve: a clocked-in worker performs the serve action (client skill-check),
-- consumes 1 supply unit, credits the account by ServePayout.
Config.ServePayout = 300         -- clean bank $ an NPC pays per serve
Config.ServeCooldownSec = 45     -- per worker, between serves (persisted, os.time)

-- Per-business daily cap on NPC income (day_npc_income, resets when the UTC
-- day_key rolls). A full day of serving cannot exceed this.
Config.DailyNpcIncome = 15000

-- Require a supply cost basis for NPC income (keep true — this is the faucet's
-- primary limiter). If ever false, NPC income becomes free-mint: DON'T.
Config.NpcRequiresSupply = true
