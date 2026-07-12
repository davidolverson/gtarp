-- ============================================================================
-- gtarp_ems/shared/config.lua - engine-agnostic tunables (Tier 1, carries to
-- VI). Mirrors the Config.Citation / Config.RateLimits shape from
-- gtarp_citations. EMS bills are DEBT WITH MEMORY, same as citations: a bill
-- is a ledger row recorded against the patient, settled later from bank via
-- /paymedbill. A patient who is broke at the scene still leaves a trace.
-- ============================================================================
Config = {}

Config.Debug = false

-- Job the mechanics are gated to. Confirmed real: qbx_ambulance_overrides
-- Config.JobName = 'ambulance'.
Config.JobName = 'ambulance'

-- OPTIONAL item gate. gtarp_citations requires the 'mdt_tablet' item, but
-- there is no confirmed EMS-owned inventory item in the repo today, so this
-- is OFF by default. If a medical tablet item is later added to
-- ox_inventory, set RequireItem = true and TabletItem to its name.
Config.RequireItem = false
Config.TabletItem  = 'ems_tablet'

Config.Bill = {
    MinAmount   = 50,
    MaxAmount   = 5000,   -- server-enforced cap; never trust a client amount
    ReasonMin   = 5,
    ReasonMax   = 140,
    ListLimit   = 8,      -- /medbills shows at most this many
    BillRadius  = 8.0,    -- medic must be within this of the patient to bill
}

-- Where paid EMS bills land (society account, same soft-dependency banking
-- path gtarp_citations uses for the police account). Absence never blocks
-- settlement.
Config.EmsAccount = 'ambulance'

-- /emscalls read-only dispatch reader over gtarp_mdt_calls.
Config.Calls = {
    ListDefault = 6,
    ListMax     = 15,
    -- gtarp_mdt_calls has NO status column. "recent" = last N rows within
    -- this many hours, newest first.
    WindowHours = 24,
}

-- OPTIONAL treatment log. Off keeps the resource to one table.
Config.LogTreatments = true

-- Per-source command cooldowns (seconds), mirroring gtarp_citations.RateLimits.
Config.RateLimits = {
    emsbill    = 10,
    medbills   = 2,
    paymedbill = 5,
    emscalls   = 3,
    treat      = 8,
}

-- OPTIONAL Discord feed, OFF by default. Reuses the existing 'police' feed
-- key because a dedicated feed would require editing gtarp_discord's config
-- (a live file we must not touch).
Config.Discord = {
    Enabled = false,
    Feed    = 'police',
}
