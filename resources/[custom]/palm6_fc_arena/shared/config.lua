-- ============================================================================
-- palm6_fc_arena/shared/config.lua — presentation tunables ONLY.
-- Ring coords/radius, MaxCrowd, and Betting min/max come from palm6_fc_core
-- (exports.palm6_fc_core:Config()); this file never duplicates a money knob.
-- ============================================================================
Config = {}

Config.Debug = false

Config.GalleryRadius   = 7.0     -- crowd peds ring the center at this radius (m)
Config.RepelRadius     = 3.5     -- non-participants pushed out to this radius during LIVE
Config.CullDistance    = 60.0    -- despawn crowd when the local player is beyond this from ring center
Config.FightMarkOffset = 1.25    -- each fighter squared up this far from center on OPPOSING marks (2.5m apart)
Config.RepelNotifySec  = 5       -- throttle the "step back" spectator notify

-- Local, non-networked crowd ped models (cheap ambient peds — no custom assets).
Config.CrowdModels = {
    'a_m_y_hipster_01', 'a_f_y_vinewood_01', 'a_m_m_business_01', 'a_f_m_business_02',
    'a_m_y_downtown_01', 'a_m_y_beach_01', 'a_f_y_beach_01', 'a_m_y_soucent_01',
}

Config.Blip = { sprite = 491, color = 1, scale = 0.9, label = 'Fight Club Ring' }

-- Fight-promoter NPC — discoverability / UX ONLY. Explains the loop; opens NO
-- match (challenges stay player-to-player via ox_target at the ring). Spawned
-- client-side only when exports.palm6_fc_core:Config().Enabled == true, so it is
-- prod-inert like everything else here.
-- A few metres from the ring center (Ring.coords in palm6_fc_core = 146.64,
-- -1279.0,28.98 · radius 15) so it stands INSIDE the ring zone. VERIFIED spot
-- 2026-07-19 (Vanilla Unicorn side lot, exterior/on-ground).
Config.Promoter = {
    model   = 'a_m_m_business_01',
    coords  = { x = 149.5, y = -1281.0, z = 28.98 },
    heading = 235.0,
    label   = 'Talk to the fight promoter',
    icon    = 'fa-solid fa-hand-fist',
}

Config.RateLimits = { fcspectate = 1 }

Config.CrowdTestSec = 10         -- DEBUG ONLY: how long /fcarenatest holds the fake LIVE statebag
