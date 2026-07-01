-- ============================================================================
-- gtarp_robbery/shared/config.lua
--
-- Store & ATM robberies with a police dispatch alert. Rob a register while
-- armed, hold through a timer, and collect cash (+ a chance of marked items).
-- A dispatch pings on-duty police; a minimum-cops gate is configurable.
--
-- DESIGN (rewards, timers, cooldowns, dispatch rules) is Tier 1 and carries.
-- The register/ATM coords are Tier 3 (Los Santos points) — mirrored in
-- docs/GTA6-TIER3-RETUNE.md.
-- ============================================================================

Config = {}

Config.Debug = false

-- Minimum on-duty police required before a robbery can start.
-- 0 = solo-testable (a robbery works with no cops online). Raise for live
-- (2–3 is typical for a small serious-RP server).
Config.MinPolice = 0

-- Interaction radius (metres) for a register / ATM.
Config.InteractRadius = 1.8

-- The player must be holding a weapon (not fists/unarmed) to start a robbery.
Config.RequireWeapon = true

-- Police dispatch: blip lifetime + label.
Config.Dispatch = { blipSprite = 161, blipColour = 1, blipScale = 1.2,
                    label = 'Robbery in progress', durationSeconds = 90 }

-- ---------------------------------------------------------------------------
-- Store registers — bigger payout, longer hold, longer cooldown.
-- ---------------------------------------------------------------------------
Config.Stores = {
    hold_seconds   = 12,
    cooldown_secs  = 1800,           -- 30 min per store
    reward_min     = 800,
    reward_max     = 1800,
    marked_item    = 'markedbills',  -- optional loot item (only drops if it exists)
    marked_chance  = 0.5,
    marked_min     = 1,
    marked_max     = 3,
    locations = {
        { label = 'LTD Mirror Park',    coords = vector3(1163.10, -322.90, 69.20) },
        { label = 'LTD Grove St',       coords = vector3(-47.30, -1757.40, 29.42) },
        { label = '247 Sandy Shores',   coords = vector3(1961.30, 3740.30, 32.34) },
        { label = '247 Grapeseed',      coords = vector3(1697.90, 4924.20, 42.06) },
        { label = "Rob's Liquor Vinewood", coords = vector3(-1222.10, -906.90, 12.33) },
    },
}

-- ---------------------------------------------------------------------------
-- ATMs — small payout, short hold, short cooldown.
-- ---------------------------------------------------------------------------
Config.ATMs = {
    hold_seconds  = 6,
    cooldown_secs = 600,             -- 10 min per ATM
    reward_min    = 150,
    reward_max    = 400,
    locations = {
        { label = 'ATM — Legion Sq',    coords = vector3(147.40, -1035.50, 29.34) },
        { label = 'ATM — Del Perro',    coords = vector3(-1204.60, -324.80, 37.87) },
        { label = 'ATM — Sandy Shores', coords = vector3(1822.40, 3683.10, 34.28) },
    },
}
