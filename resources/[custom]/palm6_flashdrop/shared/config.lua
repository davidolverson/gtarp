-- ============================================================================
-- palm6_flashdrop/shared/config.lua — engine-agnostic tunables (Tier 1,
-- carries to VI). Drop economics, timings, fees, and rules all live here;
-- only the coordinates, ped models, prop model, and blip sprites are Tier 3
-- (Los Santos values — see docs/GTA6-TIER3-RETUNE.md when the VI map lands).
--
-- Design intent: scarcity is SERVER-enforced. Every pair carries a serial
-- minted server-side and registered in palm6_flashdrop_serials; the registry
-- (not item metadata) is the source of truth for authentic / fake / stolen.
-- A counterfeit is byte-identical to a real pair in the player's inventory —
-- only a legit check against the registry tells them apart. That is the game.
-- ============================================================================
Config = {}

Config.Debug = false

-- ---------------------------------------------------------------------------
-- Base inventory item. One generic item; per-drop identity (label, serial)
-- rides in item metadata. The item is registered DECLARATIVELY in
-- ox_inventory_overrides/data/items.lua (ExtraItems) — runtime merges into
-- the table returned by ox_inventory:Items() do not reach ox_inventory
-- (cross-resource export returns are copies). At resource start this item is
-- presence-checked; if the inventory cannot resolve it, drops and crafting
-- are disabled with a loud console error. `ensure palm6_flashdrop` must come
-- AFTER ox_inventory (and ox_inventory_overrides).
-- ---------------------------------------------------------------------------
Config.Item = {
    name   = 'flashdrop_sneaker',
    label  = 'Sneakers',        -- fallback label; real pairs get metadata labels
    weight = 800,               -- grams
    stack  = false,             -- serialized — never stacks
}

-- ---------------------------------------------------------------------------
-- The drop catalog. Fictional in-universe brands only. `retail` is the
-- at-drop price; `cap` is the HARD supply per drop event (serials run
-- CODE-001/cap .. CODE-cap/cap). Weight the `rarity` field to taste — the
-- scheduler picks weighted-random, so grails stay rare.
--   rarity: how many scheduler "tickets" the entry gets (higher = commoner).
-- ---------------------------------------------------------------------------
Config.Catalog = {
    { code = 'VLTA', label = 'Volta Court Legend "Chalk"',        retail = 450,  cap = 18, rarity = 5,
      blurb = 'The everyman grail. Chalk-white leather, gum sole.' },
    { code = 'HZRD', label = 'Hazard Athletics HZ-1 "Caution"',   retail = 650,  cap = 14, rarity = 4,
      blurb = 'Hi-vis yellow with the wrong-way swoosh. Loud on purpose.' },
    { code = 'SBRT', label = 'Suburbia "Picket Fence" Low',       retail = 800,  cap = 12, rarity = 3,
      blurb = 'Streetwear does the suburbs. Ironic. Expensive.' },
    { code = 'NGHT', label = 'Nightcrawler NC-9 "Blackout"',      retail = 1200, cap = 10, rarity = 2,
      blurb = 'Matte black everything. Reflective heel only under headlights.' },
    { code = 'GRAL', label = 'Graal Atelier "Vinewood Ghost"',    retail = 2500, cap = 6,  rarity = 1,
      blurb = 'Hand-numbered atelier release. The one people get robbed for.' },
}

-- ---------------------------------------------------------------------------
-- Drop locations (Tier 3 — Los Santos coords, retune for VI).
-- `riddle` is the T-30min city-wide hint: cryptic enough to argue about,
-- solvable enough that crews stake out early. `turfZone` (optional) names a
-- palm6_turf zone id — when that turf has an owner, the T-5 reveal calls the
-- gang out by name (soft synergy; skipped if palm6_turf is absent).
-- ---------------------------------------------------------------------------
Config.Locations = {
    {
        id = 'legion_underpass',
        label = 'Legion Square underpass',
        coords = vector3(158.9, -985.7, 30.1),
        riddle = 'Where suits park and skaters roll, under the city\'s counting soul.',
    },
    {
        id = 'vespucci_basketball',
        label = 'Vespucci Beach courts',
        coords = vector3(-1289.2, -1387.8, 4.6),
        riddle = 'Salt air, chain nets, muscle and sand — buckets get counted where the boardwalk ends.',
    },
    {
        id = 'mirror_park_gazebo',
        label = 'Mirror Park lakeside',
        coords = vector3(1091.5, -675.3, 58.1),
        riddle = 'Hipsters named a puddle after your reflection. Meet me where the water copies you.',
    },
    {
        id = 'grove_cul_de_sac',
        label = 'Grove Street cul-de-sac',
        coords = vector3(107.1, -1938.5, 20.8),
        riddle = 'The most famous dead end in the state. Home court. You already know.',
        turfZone = 'grove_street',
    },
    {
        id = 'delperro_pier',
        label = 'Del Perro Pier entrance',
        coords = vector3(-1682.9, -1069.3, 13.2),
        riddle = 'Cotton candy, corn dogs, and a wheel that never stops turning. Walk the plank.',
    },
    {
        id = 'rancho_ballas',
        label = 'Rancho — Roy Lowenstein Blvd',
        coords = vector3(324.4, -2050.5, 20.9),
        riddle = 'Purple reign country. Bring friends or bring receipts.',
        -- No turfZone: palm6_turf has no Rancho/Ballas zone (its zones are
        -- legion_square, grove_street, mirror_park, vinewood, sandy_shores,
        -- paleto_bay). Add a matching zone to palm6_turf first, then point
        -- turfZone at it — an unknown id soft-degrades and never calls out.
    },
}

-- ---------------------------------------------------------------------------
-- Drop timeline + the physical line mechanic.
-- T-HintLeadSec: riddle broadcast. T-RevealLeadSec: exact location + blip.
-- T-0: checkout opens. Sold out or LiveDurationSec later: it is over.
-- ---------------------------------------------------------------------------
Config.Timing = {
    HintLeadSec    = 1800,  -- riddle lands 30 min before doors
    RevealLeadSec  = 300,   -- exact coords 5 min before doors
    LiveDurationSec = 900,  -- checkout window once live (15 min), unless sold out

    CheckoutSec      = 8,   -- per-player checkout timer at the pop-up table.
                            -- 8 exposed seconds — blocking the line and
                            -- robbing people walking away IS the game.
    CheckoutGraceSec = 20,  -- server tolerance past CheckoutSec before the
                            -- reservation is voided (latency + fumbling)
    ClaimRadius      = 20.0, -- server-side: how close to the table a claimant
                             -- must be at BOTH checkout start and finish
    AnchorRadius     = 3.0,  -- server-side: max drift between where a
                             -- two-phase action started and where it
                             -- finished. The progress bar locks movement
                             -- client-side, so a legit player never drifts;
                             -- a client that skips the bar to move/fight
                             -- through the window fails this and loses the
                             -- claim. Small slack for physics nudges.
}

Config.OnePerCitizen  = true  -- one pair per character per drop, enforced in DB
Config.AnnounceClaims = true  -- broadcast "9 of 12 left" as pairs move (hype)
Config.PayWith        = 'cash' -- street drop: cash only at the table

-- Automatic drop scheduler. Admins can always fire manual drops with
-- /flashdrop arm regardless of this.
Config.Scheduler = {
    Enabled        = true,
    MinIntervalMin = 120,   -- quiet time after a drop ends before the next
    MaxIntervalMin = 300,
    MinPlayers     = 6,     -- don't waste a drop on a dead server
}

-- ---------------------------------------------------------------------------
-- Aftermarket: SoleWorth consignment boutique (Tier 3 coords).
-- Lists CLEAN, AUTHENTIC serials only — the consignor legit-checks stock and
-- refuses fakes and reported-stolen pairs, which forces those to the fence.
-- ---------------------------------------------------------------------------
Config.Consignment = {
    Coords    = vector3(-165.6, -302.4, 39.7),  -- Rockford Hills back street
    PedModel  = 'a_m_y_hipster_01',
    PedHeading = 250.0,
    Blip      = { enabled = true, sprite = 617, colour = 46, scale = 0.7, label = 'SoleWorth Consignment' },

    FeePct              = 0.10,  -- house keeps 10% of every sale (sink)
    MinPrice            = 50,
    MaxPriceMult        = 10,    -- listing ceiling = retail * this
    MaxListingsPerPlayer = 3,
    BrowseLimit         = 25,    -- listings shown per browse
}

-- Legit check (offered at the consignment counter). A steady-hands minigame;
-- pass it and the registry verdict comes back: AUTHENTIC / COUNTERFEIT /
-- REPORTED STOLEN, plus the provenance tape for authentic pairs.
Config.LegitCheck = {
    Fee         = 50,
    CooldownSec = 15,
    -- minigame difficulty ramp (one round per entry)
    Difficulty  = { 'easy', 'easy', 'medium' },
}

-- ---------------------------------------------------------------------------
-- The fence (Tier 3 coords). No questions asked: buys clean AND dirty pairs
-- at a flat cut of retail. Spots fakes instantly and lowballs them to
-- nearly nothing. Fenced pairs leave circulation for good.
-- ---------------------------------------------------------------------------
Config.Fence = {
    Coords     = vector3(1391.4, 3605.5, 34.9),  -- Sandy Shores yard
    PedModel   = 'g_m_y_lost_01',
    PedHeading = 200.0,
    Blip       = { enabled = false },  -- unmarked; word-of-mouth RP

    PayoutRate     = 0.40,  -- genuine pairs (dirty or clean): 40% of retail
    FakePayoutRate = 0.05,  -- fakes: insultingly little
    CooldownSec    = 10,
}

-- ---------------------------------------------------------------------------
-- Counterfeit workbench (Tier 3 coords). Craft a fake of any drop that has
-- already gone live. The fake's metadata is IDENTICAL to a real pair —
-- plausible serial, same label — and only fails a registry legit check.
-- ---------------------------------------------------------------------------
Config.Counterfeit = {
    Coords      = vector3(716.8, -962.1, 30.4),  -- La Mesa alley unit
    Blip        = { enabled = false },  -- deeply unmarked

    CraftCost   = 300,   -- materials, cash up front
    CraftSec    = 12,    -- bench time (progress bar; server-verified window)
    CraftGraceSec = 20,  -- server tolerance past CraftSec
    CooldownSec = 300,   -- per-character bench cooldown
    Radius      = 15.0,  -- server-side proximity for start AND finish
}

Config.InteractRadius = 2.0   -- client interact range at peds/bench/table

-- ---------------------------------------------------------------------------
-- Synergy hooks (soft dependencies — every one degrades silently when the
-- other resource / table is absent).
-- ---------------------------------------------------------------------------
-- Stolen-pair reports write a theft entry into the palm6_evidence table for
-- detective RP (same soft pattern as palm6_pumpcoin's rug reveals).
Config.WriteEvidenceOnStolenReport = true

-- When a drop location names a `turfZone` and palm6_turf shows an owner,
-- the T-5 reveal calls the gang out — free conflict.
Config.TurfCallouts = true

-- ---------------------------------------------------------------------------
-- Presentation (Tier 3 — sprites/models are GTA V values).
-- ---------------------------------------------------------------------------
Config.DropBlip = { sprite = 618, colour = 5, scale = 1.0, flashes = true }

-- Pop-up table prop at the drop point (cosmetic; interaction works without
-- it). Set enabled=false to run prop-free.
Config.DropProp = { enabled = true, model = 'prop_table_04', zOffset = -1.0 }

-- Rate limits (seconds) on client-triggerable server events.
Config.RateLimits = {
    checkout = 2,   -- startCheckout attempts
    menu     = 1,   -- any menu/browse fetch
    action   = 1,   -- list/buy/cancel/fence submissions
    sync     = 5,   -- late-join state sync requests
}
