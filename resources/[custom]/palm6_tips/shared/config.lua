-- ============================================================================
-- palm6_tips/shared/config.lua — engine-agnostic tunables (Tier 1,
-- carries to VI). Anonymous payphone tips: a civilian walks to a
-- payphone and calls something in; it lands on the police 911 log
-- (palm6_mdt /calls) with NO identity attached — the payphone is the
-- point. Snitching becomes a scene: you have to physically go there,
-- and anyone might see you do it.
-- ============================================================================
Config = {}

Config.Debug = false

-- Payphone locations (server-checked against the caller's real coords).
-- A starter set of well-known street phones — tune to your map; any
-- coords work, they're just "places you can phone from".
Config.Payphones = {
    { x = 195.17,   y = -933.77,  z = 30.69 },   -- Legion Square
    { x = 79.5,     y = -1749.0,  z = 29.3 },    -- Davis, Grove St corner
    { x = -1389.0,  y = -585.0,   z = 30.2 },    -- Vespucci canals
    { x = 1163.0,   y = -323.0,   z = 69.2 },    -- Mirror Park
    { x = 289.0,    y = 176.5,    z = 104.2 },   -- Downtown Vinewood
    { x = -722.0,   y = -1108.0,  z = 11.0 },    -- La Puerta
    { x = 1361.0,   y = 3591.0,   z = 34.9 },    -- Sandy Shores
    { x = -110.0,   y = 6421.0,   z = 31.5 },    -- Paleto Bay
}
Config.PayphoneRadius = 3.0

Config.Tip = {
    MinChars       = 10,    -- "drugs" is not a tip
    MaxChars       = 140,
    PerCitizenCd   = 300,   -- one tip per citizen per 5 minutes
    Prefix         = '[TIP] ',  -- how tips read on the /calls log
    NotifyPolice   = true,  -- soft ping to on-duty officers on a new tip
}

-- Per-source command cooldown (seconds) — the anti-spam floor under the
-- per-citizen one above.
Config.RateLimits = {
    tip = 10,
}
