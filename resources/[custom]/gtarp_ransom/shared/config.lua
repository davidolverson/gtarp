-- ============================================================================
-- gtarp_ransom/shared/config.lua — engine-agnostic tunables (Tier 1, carries
-- to VI). The recipe's own `qbx_police`/`qbx_radialmenu` already ship a raw
-- "Kidnap"/"Take Hostage" physical mechanic (drag a restrained citizen into
-- a vehicle trunk) with zero economic or legal consequence. This resource
-- hangs a ransom economy and a felony paper trail off that existing verb —
-- it never duplicates the physical restrain/trunk mechanic itself.
-- ============================================================================
Config = {}

Config.Debug = false

-- A kidnapping only counts if the kidnapper actually demands within this
-- window of the server-validated kidnap event firing (see server/main.lua's
-- re-validation of `police:server:KidnapPlayer` — this resource never trusts
-- that event alone, it re-checks restraint + proximity itself).
Config.Ransom = {
    DemandWindowSec   = 600,   -- how long after a validated kidnap /demandransom stays valid
    MinAmount         = 250,
    MaxAmount         = 15000,
    InstructionsMin   = 5,
    InstructionsMax   = 140,
    TimeoutMinutes    = 20,    -- unpaid ransom auto-expires (still a felony — warrant issues either way)
    SweepSec          = 60,
    PostCooldownSec   = 10,
    PayCooldownSec    = 5,
}

-- Paying a ransom is a cash drop, not a bank-app tap — the payer has to
-- physically show up. Placeholder Tier-3 coords (see docs/GTA6-READINESS.md)
-- — retune once a real prop/MLO is picked. Reuses the "bail-bonds strip"
-- neighborhood gtarp_bounty's board sits in, different corner.
Config.DropPoint = {
    coords = { x = 442.80, y = -1017.30, z = 28.46 },  -- Alta St / Mission Row area
    radius = 15.0,
    label = 'the drop point downtown',
}
