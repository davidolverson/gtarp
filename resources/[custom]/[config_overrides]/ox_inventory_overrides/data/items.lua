-- ============================================================================
-- ox_inventory_overrides/data/items.lua
--
-- Items we ADD to the recipe's items table. Anything already shipped by
-- ox_inventory (water, sandwich, bandage, etc.) is referenced from shops
-- without re-declaring here. Server apply step (server/apply.lua) merges
-- these into ox_inventory's runtime items table on resource start.
--
-- Each item is { name, label, weight, stack, consume?, description? }.
-- ============================================================================

ExtraItems = {
    -- Society / job-issue items referenced by phase 3 loadouts.
    handcuffs       = { label = 'Handcuffs',       weight = 200,  stack = false },
    radio           = { label = 'Radio',           weight = 250,  stack = false },
    mdt_tablet      = { label = 'MDT Tablet',      weight = 700,  stack = false },
    defibrillator   = { label = 'Defibrillator',   weight = 1500, stack = false },
    firstaid        = { label = 'First Aid Kit',   weight = 500,  stack = true  },
    painkillers     = { label = 'Painkillers',     weight = 50,   stack = true, consume = 1.0 },
    adrenaline      = { label = 'Adrenaline Shot', weight = 100,  stack = true, consume = 1.0 },
    medikit         = { label = 'Medikit',         weight = 400,  stack = true, consume = 1.0 },

    -- Civilian convenience items.
    coffee          = { label = 'Coffee',          weight = 150,  stack = true, consume = 1.0 },
    energy_drink    = { label = 'Energy Drink',    weight = 200,  stack = true, consume = 1.0 },
    snack_bar       = { label = 'Snack Bar',       weight = 50,   stack = true, consume = 1.0 },

    -- Hardware
    repair_kit      = { label = 'Repair Kit',      weight = 1200, stack = true },
    flashlight      = { label = 'Flashlight',      weight = 300,  stack = false },
    tirepack        = { label = 'Tire Pack',       weight = 2500, stack = true },

    -- Grind tools (gtarp_grind) — buyable at the Hardware Store.
    fishing_rod     = { label = 'Fishing Rod',     weight = 1000, stack = false },
    pickaxe         = { label = 'Pickaxe',         weight = 1500, stack = false },
    hunting_knife   = { label = 'Hunting Knife',   weight = 400,  stack = false },

    -- Grind yields (gtarp_grind) — sold to the matching buyer.
    raw_fish        = { label = 'Fish',            weight = 200,  stack = true },
    raw_ore         = { label = 'Ore',             weight = 300,  stack = true },
    raw_meat        = { label = 'Raw Meat',        weight = 250,  stack = true },
    animal_pelt     = { label = 'Animal Pelt',     weight = 400,  stack = true },

    -- Serialized sneakers (gtarp_flashdrop). One base item; per-pair identity
    -- (label, serial, uid) rides in metadata. Must match Config.Item in
    -- gtarp_flashdrop/shared/config.lua — that resource presence-checks this
    -- item at start and disables drops with a console error if it is missing.
    flashdrop_sneaker = { label = 'Sneakers',      weight = 800,  stack = false },

    -- Counterfeit-cash economy (gtarp_counterfeit). Must match Config.Items
    -- in gtarp_counterfeit/shared/config.lua — that resource presence-checks
    -- these at start and self-disables with a console error if any is
    -- missing. counterfeit_cash is FAKE money with a serial in metadata —
    -- distinct name and semantics from the recipe's `markedbills` (dirty
    -- REAL money); it is never launderable and never stacks.
    counterfeit_cash    = { label = 'Bundled Cash',    weight = 120,  stack = false },
    counterfeit_printer = { label = 'Compact Printer', weight = 9000, stack = false },
    counterfeit_paper   = { label = 'Linen Paper',     weight = 200,  stack = true },
    counterfeit_ink     = { label = 'Intaglio Ink',    weight = 350,  stack = true },
    marker_pen          = { label = 'Detector Pen',    weight = 30,   stack = false },

    -- Drug supply chain (gtarp_drugs) — Schedule I MVP (weed). Must match
    -- Config in gtarp_drugs/shared/config.lua: the resource presence-checks the
    -- core items at start and self-disables with a console error if any core
    -- item is missing (and warns per missing mix additive). Names are distinct
    -- from qbx_drugs' weed_brick/coke_brick so the two item sets never overlap.
    -- (REPLACES the earlier generic-draft cannabis_leaf / weed_baggie.)
    --
    -- Grow chain: weed_seed (strain chosen at plant), soil (consumed per plant),
    -- fertilizer/speed_grow/pgr (grow additives set quality/speed/yield),
    -- wateringcan (tool, never consumed).
    weed_seed           = { label = 'Cannabis Seed',   weight = 10,   stack = true  },
    soil                = { label = 'Bag of Soil',     weight = 500,  stack = true  },
    fertilizer          = { label = 'Fertilizer',      weight = 400,  stack = true  },
    speed_grow          = { label = 'Speed-Grow',      weight = 300,  stack = true  },
    pgr                 = { label = 'PGR',             weight = 250,  stack = true  },
    wateringcan         = { label = 'Watering Can',    weight = 1200, stack = false },

    -- Metadata items. Identity (strain/quality/effects/brand) rides in
    -- metadata; ox_inventory stacks these only when metadata matches, so two
    -- differently-branded products never merge. The server sets metadata.label
    -- and metadata.description at grant time for the tooltip.
    -- weed_bud    metadata: { strain, quality, effects[], dried }
    -- weed_product metadata: { brand, base, effects[], quality, unit_value, batch_id, producer }
    weed_bud            = { label = 'Cannabis Buds',   weight = 40,   stack = true  },
    weed_product        = { label = 'Weed Product',    weight = 30,   stack = true  },

    -- Meth cook chain (gtarp_drugs §9). pseudo/acid/red_phosphorus are the cook
    -- precursors; meth_raw is the raw crystal (same metadata shape as weed_bud,
    -- base='meth'), meth_product the finished branded product (like weed_product).
    -- gtarp_drugs stays disabled for meth until all five are registered here.
    -- pseudo       metadata: { grade }                       (1-2; sets quality floor)
    -- meth_raw     metadata: { base, quality, effects[], dried }
    -- meth_product metadata: { brand, base, effects[], quality, unit_value, batch_id, producer }
    pseudo              = { label = 'Pseudoephedrine',  weight = 30,   stack = true  },
    acid                = { label = 'Hydrochloric Acid',weight = 200,  stack = true  },
    red_phosphorus      = { label = 'Red Phosphorus',   weight = 150,  stack = true  },
    meth_raw            = { label = 'Meth (Raw)',       weight = 30,   stack = true  },
    meth_product        = { label = 'Meth',             weight = 20,   stack = true  },

    -- Mix additives (gtarp_drugs §2). Each appends one base effect at the
    -- mixing station. `energy_drink` (Athletic) is already registered above
    -- under civilian items and is reused — it is intentionally NOT re-declared
    -- here.
    cuke                = { label = 'Cuke',            weight = 100,  stack = true  },
    banana              = { label = 'Banana',          weight = 120,  stack = true  },
    paracetamol         = { label = 'Paracetamol',     weight = 40,   stack = true  },
    donut               = { label = 'Donut',           weight = 90,   stack = true  },
    viagra              = { label = 'Viagra',          weight = 30,   stack = true  },
    mouthwash           = { label = 'Mouth Wash',      weight = 200,  stack = true  },
    flu_medicine        = { label = 'Flu Medicine',    weight = 120,  stack = true  },
    gasoline            = { label = 'Gasoline',        weight = 800,  stack = true  },
    motor_oil           = { label = 'Motor Oil',       weight = 700,  stack = true  },
    mega_bean           = { label = 'Mega Bean',       weight = 110,  stack = true  },
    chili               = { label = 'Chili',           weight = 60,   stack = true  },
    battery             = { label = 'Battery',         weight = 300,  stack = true  },
    iodine              = { label = 'Iodine',          weight = 50,   stack = true  },
    addy                = { label = 'Addy',            weight = 30,   stack = true  },
    horse_semen         = { label = 'Horse Semen',     weight = 150,  stack = true  },
}
