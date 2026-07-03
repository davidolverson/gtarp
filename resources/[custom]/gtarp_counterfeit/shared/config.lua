-- ============================================================================
-- gtarp_counterfeit/shared/config.lua — engine-agnostic tunables (Tier 1,
-- carries to VI). Only district centres, sink/fence coords, ped models, the
-- anchor-prop whitelist, and blip sprites are Tier 3 Los Santos values (see
-- docs/GTA6-TIER3-RETUNE.md when the VI map lands).
--
-- DESIGN INTENT — counterfeit cash with a MEMORY. Every wad the printer
-- spits out carries a server-minted serial; every transfer (player trade,
-- ground drop, sink spend, fence pass) appends a hop to a provenance chain
-- capped at the last Config.HopCap hops. One seized wad + the evidence
-- locker terminal turns that chain into named case LEADS (gtarp_evidence
-- v2 exports) — and interrogating a lead unlocks the next hop. One bust
-- cascades into a network takedown. The provenance/cascade system is the
-- 1-of-1; the printer itself is deliberately simple.
--
-- NOT dirty money. The recipe's `markedbills` (qbx_storerobbery/qbx_drugs)
-- is REAL money that needs laundering. `counterfeit_cash` is FAKE money
-- that needs passing — it can never be laundered, deposited, or exchanged
-- in bulk for clean cash. Its only exits are goods (sinks), risk-priced
-- per-wad fence passes that get worse the more the batch circulates, and
-- the evidence bag.
-- ============================================================================
Config = {}

Config.Debug = false

Config.InteractRadius = 2.0   -- client interact range (printer/sink/fence)

-- ---------------------------------------------------------------------------
-- Items. ALL registered declaratively in
-- ox_inventory_overrides/data/items.lua (ExtraItems) — runtime merges never
-- reach ox_inventory (export returns are msgpack copies). Presence-checked
-- at resource start; the whole resource self-disables with a loud console
-- error if any REQUIRED item is missing (same boot gate as gtarp_flashdrop).
--
-- The evidence-bag pair belongs to the qbx_police seizure pattern
-- (empty_evidence_bag -> filled_evidence_bag with metadata). It is a SOFT
-- dependency: when those items are absent, /seizefake still works — the wad
-- is destroyed and registered as seized — it just cannot produce a physical
-- bag for the locker stash.
-- ---------------------------------------------------------------------------
Config.Items = {
    -- The fake itself. Distinct NAME and semantics from `markedbills` (which
    -- is dirty REAL money). The label plays it straight — in RP only a
    -- detector pen tells a wad from bundled savings.
    Cash    = { name = 'counterfeit_cash',    label = 'Bundled Cash',    weight = 120,  stack = false },
    Printer = { name = 'counterfeit_printer', label = 'Compact Printer', weight = 9000, stack = false },
    Paper   = { name = 'counterfeit_paper',   label = 'Linen Paper',     weight = 200,  stack = true },
    Ink     = { name = 'counterfeit_ink',     label = 'Intaglio Ink',    weight = 350,  stack = true },
    Pen     = { name = 'marker_pen',          label = 'Detector Pen',    weight = 30,   stack = false },
}

-- qbx_police evidence-bag items (soft — see above).
Config.EvidenceBag = {
    Empty  = 'empty_evidence_bag',
    Filled = 'filled_evidence_bag',
}

-- ---------------------------------------------------------------------------
-- Districts (Tier 3 centres). A printer must be placed INSIDE a district
-- (server-side distance check against the placement coords). District heat
-- is what police see — never the printer itself.
-- ---------------------------------------------------------------------------
Config.Districts = {
    { id = 'strawberry',  label = 'Strawberry',   center = vector3(180.0, -1730.0, 29.0),  radius = 600.0 },
    { id = 'la_mesa',     label = 'La Mesa',      center = vector3(750.0, -950.0, 25.0),   radius = 550.0 },
    { id = 'vespucci',    label = 'Vespucci',     center = vector3(-1150.0, -1300.0, 5.0), radius = 650.0 },
    { id = 'mirror_park', label = 'Mirror Park',  center = vector3(1090.0, -640.0, 57.0),  radius = 550.0 },
    { id = 'paleto',      label = 'Paleto Bay',   center = vector3(-140.0, 6350.0, 31.0),  radius = 700.0 },
    { id = 'sandy',       label = 'Sandy Shores', center = vector3(1850.0, 3690.0, 34.0),  radius = 800.0 },
}

-- ---------------------------------------------------------------------------
-- Printer placement. The printer item deploys at the player's feet, but only
-- next to a whitelisted anchor prop — industrial printing gear or, with
-- bob74_ipl started, the Bikers counterfeit-cash factory dressing. The
-- anchor check runs CLIENT-side (map props are not networked; the server
-- cannot see them) and is placement flavor, not a security gate: the gates
-- that matter — item possession, district containment, spacing, per-citizen
-- cap, coord sanity vs the player's server-side position — are all
-- server-side. A spoofed anchor buys nothing but a printer in an ugly spot.
--
-- Unknown model names degrade gracefully: they hash to values no world prop
-- carries and simply never match. Verify/extend in-game with a props
-- inspector if a spot refuses to validate.
-- ---------------------------------------------------------------------------
Config.Printer = {
    AnchorProps = {
        -- bob74_ipl — Bikers counterfeit-cash factory dressing (natural spots)
        'bkr_prop_prtmachine_dryer_01a',
        'bkr_prop_prtmachine_cutter_01a',
        'bkr_prop_prtmachine_press_01a',
        'bkr_prop_fakecash_pallet_01a',
        -- base-game interior printing/office gear (works without any IPL)
        'prop_printer_01',
        'prop_printer_02',
        'prop_photocopier_01',
        'v_res_printer',
        'v_ret_gc_print',
    },
    AnchorRadius     = 4.0,    -- client: max distance from an anchor prop
                               -- (the press deploys at the player's
                               -- SERVER-side position — the client never
                               -- supplies coordinates)
    SpawnProp        = true,   -- server-side networked prop at the placement
                               -- (OneSync). Cosmetic; everything works without.
    PropModel        = 'prop_printer_01',

    MaxPerCitizen    = 1,      -- placed printers per character
    MinSpacing       = 50.0,   -- metres between any two placed printers
    MaxPaper         = 60,     -- hopper caps
    MaxInk           = 30,
}

-- ---------------------------------------------------------------------------
-- Print cycles. Two-phase (start -> progress bar -> finish) with server-side
-- min AND max elapsed checks plus a position anchor, exactly like
-- gtarp_flashdrop's craft. Materials are deducted at START (finishing
-- outside the window wastes them — greed has a price).
-- ---------------------------------------------------------------------------
Config.Print = {
    PaperPerCycle = 6,      -- hopper cost per cycle
    InkPerCycle   = 2,
    WadsPerCycle  = 4,      -- counterfeit_cash items minted per clean cycle
    FaceValue     = 1000,   -- what one wad claims to be worth ($ face)
    CycleSec      = 20,     -- progress-bar time (server-verified window)
    GraceSec      = 20,     -- server tolerance past CycleSec
    CooldownSec   = 180,    -- per-character, between cycles
    AnchorRadius  = 3.0,    -- max drift between start and finish position
}

-- ---------------------------------------------------------------------------
-- District heat. Printing (and, faintly, spending) warms the district.
-- Above PingThreshold, on-duty police get a VAGUE zone ping — a wide-radius
-- circle jittered off the true printer position, never a point. Heat decays
-- every sweep; going quiet is a strategy.
-- ---------------------------------------------------------------------------
Config.Heat = {
    PerCycle        = 25.0,  -- heat added per print cycle
    PerSpend        = 4.0,   -- heat added when a wad is passed in a district
    DecayPerMin     = 1.5,   -- linear decay
    PingThreshold   = 50.0,  -- district heat needed before police feel it
    PingCooldownSec = 300,   -- min seconds between pings per district
    PingRadius      = 250.0, -- radius of the vague area circle shown to police
    PingJitter      = 150.0, -- ping centre = source coords +/- this much
    SweepSec        = 60,    -- decay/ping sweep cadence (server)
}

-- ---------------------------------------------------------------------------
-- Provenance. Every transfer of a wad appends (from, to, timestamp); the
-- chain keeps only the LAST HopCap hops per serial — old history falls off
-- the end, so moving paper fast genuinely erodes the trail.
-- ---------------------------------------------------------------------------
Config.HopCap = 6

-- ---------------------------------------------------------------------------
-- Sinks — player-facing NPC vendors that take a wad at face value for a
-- basket of goods (never money: counterfeit has no bulk cash-out). Each
-- spend is a provenance hop + a circulation tick for the batch. A vendor
-- checks bills with probability rising with the batch's circulation; a
-- caught wad is refused, sometimes kept, sometimes reported.
-- Goods reference items that already exist in ox_inventory_overrides
-- ExtraItems (energy_drink, snack_bar, repair_kit, tirepack, fishing_rod,
-- coffee) — presence-checked at boot alongside our own items.
-- ---------------------------------------------------------------------------
Config.Sinks = {
    {
        id = 'liquor_backdoor', label = 'Backdoor Liquor',
        coords = vector3(-1224.6, -906.8, 12.3), pedModel = 'mp_m_shopkeep_01', pedHeading = 32.0,
        district = 'vespucci',
        goods = { { name = 'energy_drink', count = 6 }, { name = 'snack_bar', count = 8 } },
    },
    {
        id = 'chop_counter', label = 'La Mesa Parts Counter',
        coords = vector3(731.9, -1088.8, 22.2), pedModel = 'g_m_m_mexboss_01', pedHeading = 90.0,
        district = 'la_mesa',
        goods = { { name = 'repair_kit', count = 2 }, { name = 'tirepack', count = 1 } },
    },
    {
        id = 'paleto_bait', label = 'Paleto Bait & Tackle',
        coords = vector3(-275.6, 6635.2, 7.5), pedModel = 'a_m_m_hillbilly_02', pedHeading = 220.0,
        district = 'paleto',
        goods = { { name = 'fishing_rod', count = 1 }, { name = 'coffee', count = 4 } },
    },
}

Config.Sink = {
    DetectBase       = 0.05,  -- vendor check probability at circulation 0
    DetectPerHop     = 0.02,  -- + per circulation tick on the batch
    DetectCap        = 0.60,
    KeepOnDetect     = 0.50,  -- chance a detecting vendor keeps the wad
    PoliceCallChance = 0.35,  -- chance a detecting vendor reports it
                              -- (police:server:policeAlert, cornerselling-style)
    CooldownSec      = 60,    -- per-character, per sink spend
}

-- ---------------------------------------------------------------------------
-- NPC fences — the only place a wad turns into real cash, and it is a bad
-- trade on purpose: a flat fraction of face, a daily quota, and a rejection
-- probability that RISES with the batch's total circulation AND its print
-- size (quality decays with greed). Deliberately NOT drug cornerselling:
-- fixed back-room contacts you must walk to (not any ped on any street),
-- per-wad serialized passes (not bulk baggies), and the risk curve is
-- batch-history driven, not a flat coin flip. What it REUSES from
-- cornerselling is the alert plumbing: a rejection reports through
-- police:server:policeAlert with the same probability pattern as
-- qbx_drugs' policeCallChance.
-- ---------------------------------------------------------------------------
Config.Fences = {
    { id = 'pawn_sandy',   label = 'Sandy Pawn Back Room',     coords = vector3(1697.5, 3757.8, 34.7), pedModel = 'g_m_m_casrn_01',     pedHeading = 310.0, district = 'sandy' },
    { id = 'arcade_straw', label = 'Strawberry Arcade Office', coords = vector3(232.6, -1385.8, 30.5), pedModel = 'g_m_y_ballasout_01', pedHeading = 140.0, district = 'strawberry' },
}

Config.Fence = {
    Rate             = 0.35,   -- real cash paid per wad = FaceValue * Rate
    RejectBase       = 0.10,   -- rejection probability at circulation 0
    RejectPerHop     = 0.04,   -- + per circulation tick on the batch
    RejectPerWadOver = 0.015,  -- + per wad the batch printed beyond SmallBatch
    SmallBatch       = 8,      -- batches this size or smaller add no size penalty
    RejectCap        = 0.85,
    KeepOnReject     = 0.35,   -- chance a rejecting fence keeps the wad anyway
    PoliceCallChance = 0.25,   -- chance a rejection is reported
                               -- (police:server:policeAlert, cornerselling-style)
    DailyQuota       = 6,      -- wads per character per fence per day
    CooldownSec      = 45,     -- per-character, between passes
}

-- ---------------------------------------------------------------------------
-- Detector pen. Usable item; a steady-hands check, then the registry
-- verdict: serial, batch wear band, and how hot the paper is. The pass/fail
-- of the minigame is client-reported (deliberate, same trust boundary as
-- gtarp_flashdrop's legit check: it only reveals registry truth about a wad
-- the caller already holds).
-- ---------------------------------------------------------------------------
Config.Pen = {
    CooldownSec = 10,
    Difficulty  = { 'easy', 'medium' },
    MaxCheckSec = 30,   -- server window for the two-phase check
}

-- ---------------------------------------------------------------------------
-- Police: seizure + the serial-run terminal + the cascade.
-- ---------------------------------------------------------------------------
Config.Police = {
    -- The serial terminal lives AT the gtarp_evidence locker (same Mission
    -- Row point — keep in sync with gtarp_evidence Config.LockerCoords).
    TerminalCoords    = vector3(434.0, -983.0, 30.7),
    TerminalRadius    = 3.0,     -- client prompt radius (server adds slack)

    LeadsPerRun       = 2,       -- hops revealed by the initial serial run
    LeadsPerPress     = 1,       -- extra hops per successful interrogation
    InterrogateRadius = 4.0,     -- server-side distance to the pressed suspect

    RaidRadius        = 15.0,    -- /counterfeitraid finds printers within this
    RaidHeatClear     = true,    -- raiding clears the district's heat

    -- Case identity: one case per batch, idempotent across officers.
    IncidentKeyPrefix = 'counterfeit-batch:',
    CaseTitle         = 'Counterfeit Currency — Batch %s',
}

-- ---------------------------------------------------------------------------
-- Presentation (Tier 3 sprites).
-- ---------------------------------------------------------------------------
-- Police heat-ping area blip. Sinks and fences are deliberately unblipped —
-- word-of-mouth RP.
Config.HeatBlip = { colour = 1, alpha = 80, durationSec = 120 }

-- Rate limits (seconds) on client-triggerable server events.
Config.RateLimits = {
    menu   = 1,   -- any menu/data fetch
    action = 1,   -- spend/pass/feed/place submissions
    print  = 2,   -- print start attempts
    police = 1,   -- seizure/terminal actions
}
