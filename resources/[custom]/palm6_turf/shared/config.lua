-- ============================================================================
-- palm6_turf/shared/config.lua — engine-agnostic tunables (Tier 1, carries to VI).
--
-- The Phase 6 roadmap candidate "faction reputation tracker"
-- (docs/BUILD-ROADMAP.md) — never built. qbx_core has gangs as a
-- first-class primitive (PlayerData.gang, /setgang) but no gameplay was
-- ever layered on top of it. Reputation here = turf zones held.
-- ============================================================================
Config = {}

Config.Debug = false

Config.InteractRadius = 3.0
Config.TagProgressMs = 8000

-- Zone coords reuse already-validated ground-level points from elsewhere
-- in this repo (spawn / shop / robbery locations) rather than new,
-- unverified coordinates — same city-wide spread, zero placement risk.
Config.Zones = {
    { id = 'legion_square', label = 'Legion Square',  coords = vector3(195.17, -933.77, 30.69) },
    { id = 'grove_street',  label = 'Grove Street',    coords = vector3(-47.30, -1757.40, 29.42) },
    { id = 'mirror_park',   label = 'Mirror Park',     coords = vector3(1163.10, -322.90, 69.20) },
    { id = 'vinewood',      label = 'Vinewood',        coords = vector3(-1222.10, -906.90, 12.33) },
    { id = 'sandy_shores',  label = 'Sandy Shores',    coords = vector3(1961.30, 3740.30, 32.34) },
    { id = 'paleto_bay',    label = 'Paleto Bay',      coords = vector3(1728.66, 6414.16, 35.04) },
}

-- Blip sprite/colour for an owned zone vs. unclaimed. GTA V native ids —
-- see docs/GTA6-TIER3-RETUNE.md §7 (blip sprites & colours).
Config.BlipSprite = 84
Config.UnclaimedColour = 0   -- white
Config.ClaimedColour = 1     -- red-ish; per-gang colour is deferred to v2
Config.BlipScale = 0.8

-- Reputation (palm6_gangs) awarded for a genuine turf TAKEOVER — capturing a
-- zone that a DIFFERENT player-run gang currently holds. Not granted for
-- claiming unowned turf. Bounded per-zone by RepCooldownSec so two gangs can't
-- ping-pong a single zone to farm rep. Set RepPerCapture = 0 to disable.
Config.RepPerCapture = 10
Config.RepCooldownSec = 600   -- a given zone can mint rep at most once / 10 min
