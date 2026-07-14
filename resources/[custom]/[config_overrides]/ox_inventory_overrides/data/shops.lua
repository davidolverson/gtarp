-- ============================================================================
-- ox_inventory_overrides/data/shops.lua
--
-- Curated shop catalog.
--
-- PRICE LADDER (source-of-truth formula):
--   A 7-minute paycheck of $350 (police grade 0) buys roughly:
--     ~70 waters ($5)         basic hydration
--     ~20 sandwiches ($15)    full meal
--     ~3 first-aid kits ($120) emergency care
--     ~1 repair kit ($300)    vehicle repair
--   Adjust paycheck cadence (qbx_economy_overrides) and prices here in
--   lockstep so the ratio stays roughly stable.
--
-- Society shops (police_armoury, ems_medical) are zero-cost: items are
-- requisitioned, but every transaction is still logged by ox_inventory.
-- ============================================================================

local function P(name, price, count, license, metadata)
    return {
        name = name,
        price = price,
        count = count or 50,
        license = license,
        metadata = metadata,
    }
end

ExtraShops = {

    -- ---------------------------------------------------------------------
    -- General store (24/7)
    -- ---------------------------------------------------------------------
    general_store = {
        name = 'General Store',
        groups = nil, -- public
        inventory = {
            P('water',         5),
            P('sandwich',      15),
            P('coffee',        8),
            P('energy_drink',  12),
            P('snack_bar',     6),
            P('bandage',       40),
            P('painkillers',   60),
            P('flashlight',    150),
        },
        locations = {
            vector3(24.47, -1346.62, 29.50),     -- Innocence Blvd
            vector3(-3038.94, 585.95, 7.91),     -- Pacific Bluffs
            vector3(-3242.47, 1001.46, 12.83),   -- Banham Canyon
            vector3(1728.66, 6414.16, 35.04),    -- Paleto Bay
            vector3(1163.37, -323.80, 69.21),    -- Mirror Park
            vector3(2557.94, 382.05, 108.62),    -- Tataviam Mtns
            vector3(373.87, 325.89, 103.57),     -- Downtown
        },
    },

    -- ---------------------------------------------------------------------
    -- Ammunition (license-gated)
    -- ---------------------------------------------------------------------
    ammu_nation = {
        name = 'Ammu-Nation',
        groups = nil,
        inventory = {
            P('pistol_ammo',  50,  100, 'weapon'),
            P('smg_ammo',     80,  100, 'weapon'),
            P('shotgun_ammo', 60,  100, 'weapon'),
            P('flashlight',   150),
        },
        locations = {
            vector3(21.7,  -1106.42, 29.80),   -- Innocence Blvd
            vector3(810.25, -2157.6,  29.62),  -- El Burro Heights
            vector3(1693.4,  3760.6,  34.71),  -- Sandy Shores
        },
    },

    -- ---------------------------------------------------------------------
    -- Hardware
    -- ---------------------------------------------------------------------
    hardware = {
        name = 'Hardware Store',
        groups = nil,
        inventory = {
            P('repair_kit',    300),
            P('tirepack',      180),
            P('flashlight',    150),
            P('radio',         450),
            -- palm6_grind tools
            P('fishing_rod',   250),
            P('pickaxe',       350),
            P('hunting_knife', 300),
        },
        locations = {
            vector3(2748.4, 3473.4, 55.66),    -- Sandy Shores
            vector3(-422.7, 6136.0, 31.86),    -- Paleto Bay
        },
    },

    -- ---------------------------------------------------------------------
    -- Clothing (one entry — players use qbx tailor for the rest)
    -- ---------------------------------------------------------------------
    clothing = {
        name = 'Suburban',
        groups = nil,
        inventory = {
            -- Clothing-store entries are mostly handled by the qbx
            -- clothing resource; this is a placeholder so the shop
            -- registry contains a clothing entry the catalog test
            -- script can find.
            P('snack_bar',  6),
        },
        locations = {
            vector3(127.0, -223.4, 54.56),
        },
    },

    -- ---------------------------------------------------------------------
    -- Society — Mission Row PD armoury (zero-cost)
    -- ---------------------------------------------------------------------
    police_armoury = {
        name = 'Mission Row PD Armoury',
        groups = { ['police'] = 0 },
        inventory = {
            P('weapon_combatpistol', 0,  20),
            P('weapon_stungun',      0,  20),
            P('weapon_nightstick',   0,  20),
            P('weapon_flashlight',   0,  20),
            P('pistol_ammo',         0, 200),
            P('handcuffs',           0,  50),
            P('radio',               0,  50),
            P('armor',               0,  50),
            P('bandage',             0, 100),
            P('mdt_tablet',          0,  10),
        },
        locations = {
            vector3(461.79, -983.04, 30.69),
        },
    },

    -- ---------------------------------------------------------------------
    -- Society — Pillbox Hill EMS (zero-cost)
    -- ---------------------------------------------------------------------
    ems_medical = {
        name = 'Pillbox Hill — Medical Supply',
        groups = { ['ambulance'] = 0 },
        inventory = {
            P('bandage',       0, 200),
            P('medikit',       0,  50),
            P('painkillers',   0, 100),
            P('adrenaline',    0,  50),
            P('defibrillator', 0,  10),
            P('radio',         0,  50),
            P('firstaid',      0,  50),
        },
        locations = {
            vector3(307.7, -1433.4, 29.9),
        },
    },

    -- ---------------------------------------------------------------------
    -- Garden & Hydro Supply — grow inputs + household "additives" for
    -- palm6_drugs. Legit storefront (nothing illegal is sold here; the
    -- product itself is made by the player). Prices set against the ~$350
    -- paycheck: a seed + soil + water is a modest starting outlay.
    -- ⚠️ coords are placeholders — VERIFY IN-GAME (on-ground/reachable).
    -- ---------------------------------------------------------------------
    garden_supply = {
        name = 'Garden & Hydro Supply',
        groups = nil, -- public
        inventory = {
            -- grow inputs
            P('weed_seed',    50),
            P('soil',         15),
            P('wateringcan',  80),
            P('fertilizer',   60),   -- → Premium quality
            P('speed_grow',   40),
            P('pgr',          75),
            -- mix additives (each adds one base effect; household goods)
            P('cuke',          8),
            P('banana',        6),
            P('paracetamol',  15),
            P('donut',         8),
            P('viagra',       45),
            P('mouthwash',    10),
            P('flu_medicine', 18),
            P('gasoline',     20),
            P('motor_oil',    25),
            P('mega_bean',    12),
            P('chili',         6),
            P('battery',      20),
            P('iodine',       22),
            P('addy',         60),
            P('horse_semen',  30),
            P('energy_drink', 12),
        },
        locations = {
            vector3(1391.5, 3605.5, 38.9),   -- Sandy Shores (VERIFY IN-GAME)
            vector3(2001.5, 4636.5, 41.0),   -- Grapeseed nursery (VERIFY IN-GAME)
        },
    },
}
