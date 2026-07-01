-- ============================================================================
-- gtarp_grind/shared/config.lua
--
-- Legal solo grind loops: fishing, mining, hunting. Gather at spots with the
-- right tool, sell the yield to a buyer for cash; XP scales yield + price.
--
-- The DESIGN (tools, yields, prices, XP curve) is Tier 1 and carries to
-- GTA VI. The coords (gather spots, sell points) are Tier 3 — Los Santos map
-- points, mirrored in docs/GTA6-TIER3-RETUNE.md.
-- ============================================================================

Config = {}

Config.Debug = false

-- Interaction radius (metres) for gather spots and sell points.
Config.InteractRadius = 2.5

-- Seconds a player must wait between gathers (per activity, anti-spam).
Config.GatherCooldown = 8

-- XP -> level. level = min(MaxLevel, floor(xp / XpPerLevel)).
Config.XpPerLevel = 100
Config.MaxLevel   = 20

-- Per-level sale bonus: sale price is multiplied by (1 + level * this).
Config.PriceBonusPerLevel = 0.05  -- +5% per level

Config.Activities = {
    fishing = {
        label   = 'Fishing',
        tool    = 'fishing_rod',
        verb    = 'Fishing…',
        gather_seconds = 6,
        yields  = { { item = 'raw_fish', min = 1, max = 3 } },
        xp_per_gather = 8,
        sell = {
            item  = 'raw_fish',
            price = 45,               -- base $ per fish (before level bonus)
            label = 'Fish Market',
            coords = vector3(-1817.30, -1193.20, 14.30),
        },
        spots = {
            vector3(-1850.20, -1235.60, 8.62),   -- Del Perro pier
            vector3(1299.80, 4224.90, 33.00),    -- Alamo Sea
            vector3(-1607.90, 5261.30, 3.90),    -- Paleto cove
        },
    },

    mining = {
        label   = 'Mining',
        tool    = 'pickaxe',
        verb    = 'Mining…',
        gather_seconds = 7,
        yields  = { { item = 'raw_ore', min = 1, max = 2 } },
        xp_per_gather = 10,
        sell = {
            item  = 'raw_ore',
            price = 70,
            label = 'Ore Buyer',
            coords = vector3(1109.60, -2007.90, 31.00),
        },
        spots = {
            vector3(2954.10, 2782.30, 40.50),    -- Davis Quarry
            vector3(2969.40, 2835.60, 42.20),
            vector3(2915.00, 2792.00, 39.80),
        },
    },

    hunting = {
        label   = 'Hunting',
        tool    = 'hunting_knife',
        verb    = 'Skinning…',
        gather_seconds = 6,
        yields  = {
            { item = 'raw_meat',    min = 1, max = 2 },
            { item = 'animal_pelt', min = 0, max = 1 },  -- pelt is a chance drop
        },
        xp_per_gather = 9,
        sell = {
            item  = 'raw_meat',
            price = 55,
            label = 'Butcher',
            coords = vector3(85.20, 6410.30, 31.30),
        },
        spots = {
            vector3(-1150.40, 4880.70, 220.10),  -- Great Chaparral
            vector3(-560.20, 5335.80, 70.40),    -- Paleto forest
            vector3(-778.10, 5591.40, 33.50),
        },
    },
}

-- Blip styling for sell points (Tier 3 GTA V sprite/colour ids).
Config.SellBlip = { sprite = 52, colour = 2, scale = 0.8 }
