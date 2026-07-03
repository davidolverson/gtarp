-- ============================================================================
-- gtarp_witnesses/shared/config.lua — engine-agnostic tunables (Tier 1,
-- carries to VI). Every crime leaves living NPC witnesses; police canvass
-- them for partial suspect facts, criminals press or pay them off.
--
-- Design intent: the witness layer is TESTIMONIAL ONLY. Physical forensics
-- (casings / blood / fingerprints) belong to qbx_police's evidence system
-- (client/evidence.lua) and are deliberately NOT captured here. Plate facts
-- are PARTIAL (3 chars max) so qbx_police ANPR stays the full-plate source.
-- Everything a witness "knows" is snapshotted and stored SERVER-SIDE at
-- crime time — the peds on screen are just markers; a modified client can
-- never invent, read, or destroy testimony.
-- ============================================================================
Config = {}

Config.Debug = false

-- ---------------------------------------------------------------------------
-- The event bus: which crimes create witnesses.
--
-- weaponDamage rides the built-in server game event (weaponDamageEvent) —
-- gunfire and armed assaults. The named entries shadow-listen on net events
-- fired by other resources (we validate nothing for them; the owning
-- resource does — we only snapshot bystanders).
--
-- `qbxAlerts = true` marks crimes the recipe ALREADY rolls its own
-- NPC-reported police alerts for (qbx_storerobbery's alertPolice(),
-- qbx_drugs cornerselling's policeCallChance — both fire
-- police:server:policeAlert themselves). gtarp_witnesses must never fire a
-- SECOND alert for those, so alert eligibility is per-hook and the global
-- switch below defaults OFF. Witness creation itself is always silent:
-- the value is the canvass, not a 911 ping.
-- ---------------------------------------------------------------------------
Config.Hooks = {
    -- Fired by qbx resources (storerobbery registers/safes, drugs corner
    -- selling, jewelery, houserobbery, bankrobbery) — they all funnel
    -- through police:server:policeAlert. Hooking the alert event itself
    -- covers every robbery-style trigger in the recipe with zero coupling.
    policeAlert = {
        enabled = true,
        crime = 'reported_crime',
        label = 'a reported crime',
        qbxAlerts = true,          -- the alert we hooked IS the qbx alert
    },
    -- Server game event: a player damaged something with a weapon while
    -- armed. Fist fights are ignored.
    weaponDamage = {
        enabled = true,
        crime = 'shots_fired',
        label = 'shots fired',
        qbxAlerts = false,         -- qbx_police logs casings client-side but
                                   -- rolls no NPC 911 call for gunfire
    },
    -- Our own custom layer: ATM robberies. gtarp_robbery already sends its
    -- own dispatch to police, so this hook is alert-ineligible too.
    -- SERVER-ONLY event: gtarp_robbery TriggerEvent()s it after every start
    -- gate passes (never the raw, forgeable 'gtarp_robbery:start' net event).
    gtarpRobbery = {
        enabled = true,
        event = 'gtarp_robbery:started',
        crime = 'atm_robbery',
        label = 'an ATM robbery',
        qbxAlerts = true,          -- gtarp_robbery fires its own dispatch
    },
}

-- Opt-in 911 layer, default OFF (per the duplication review). When true,
-- hooks with qbxAlerts = false (crimes nothing else alerts on) fire ONE
-- police:server:policeAlert when witnesses actually saw the crime. Hooks
-- with qbxAlerts = true never re-alert regardless of this switch.
Config.FirePoliceAlerts = false

-- ---------------------------------------------------------------------------
-- Witness snapshot
-- ---------------------------------------------------------------------------
Config.WitnessRadius       = 40.0 -- NPC peds within this range of the crime
Config.MinWitnesses        = 1    -- fewer eligible NPCs = the crime went unseen
Config.MaxWitnesses        = 4    -- hard cap per incident
Config.WitnessTtlMin       = 30   -- minutes a witness marker persists
Config.IncidentCooldownSec = 120  -- one incident per suspect per this window
                                  -- (a magazine dump is one crime, not thirty)

-- Facts a witness can hold. Each witness is dealt FactsPerWitnessMin..Max
-- distinct facts from whatever the suspect actually exposed (on foot = no
-- vehicle facts). Partial plates are clamped to PlateChars characters.
Config.FactsPerWitnessMin = 1
Config.FactsPerWitnessMax = 2
Config.PlateChars         = 3

-- Coarse clothing-colour vocabulary. The reported colour derives
-- DETERMINISTICALLY from the suspect ped's real torso drawable/texture
-- variation (same outfit = same statement every time), bucketed into this
-- street-level vocabulary — witnesses say "a dark top", not RGB values.
Config.TopColors = {
    'dark', 'light', 'red', 'blue', 'green', 'grey', 'brown', 'white',
}

-- Vehicle classes as a witness would describe them, keyed by the
-- server-side vehicle type string.
Config.VehicleClassLabels = {
    automobile = 'a car',
    bike       = 'a motorcycle',
    heli       = 'a helicopter',
    plane      = 'a plane',
    boat       = 'a boat',
    quadbike   = 'a quad bike',
    bicycle    = 'a bicycle',
    trailer    = 'a trailer',
    train      = 'a train',
    submarine  = 'a submarine',
}

-- ---------------------------------------------------------------------------
-- Police canvass
-- ---------------------------------------------------------------------------
Config.Canvass = {
    Radius      = 2.5,   -- client prompt range at a witness marker
    DurationSec = 5,     -- the doorstep interview takes this long
    GraceSec    = 15,    -- server tolerance past DurationSec (latency)
    CooldownSec = 6,     -- per-character canvass cooldown
}

-- Case-file integration (gtarp_evidence v2 exports). Cases are created
-- LAZILY: the first canvass of an incident calls EnsureCase with the
-- incident's stable key, so uncanvassed incidents never leave empty cases.
Config.Evidence = {
    Source   = 'gtarp_witnesses',        -- AppendEntry source tag
    TitleFmt = 'Witness canvass — %s',   -- %s = crime label
}

-- ---------------------------------------------------------------------------
-- Criminal counterplay. Only the incident's OWN suspect can press or pay
-- off its witnesses (server-enforced) — you cannot scrub someone else's
-- crime scene.
-- ---------------------------------------------------------------------------
Config.Press = {
    Radius       = 8.0,  -- how close the suspect must be to the marker
    AimSec       = 5,    -- weapon must stay aimed this long
    GraceSec     = 15,   -- server tolerance past AimSec
    AnchorRadius = 4.0,  -- max drift between press start and finish
    CooldownSec  = 30,   -- per-character press cooldown
    -- A pressed witness either clams up entirely or feeds police corrupted
    -- facts (wrong colour, flipped mask, scrambled plate). Chance the
    -- canvass still yields (corrupted) facts rather than nothing:
    CorruptedFactChance = 0.5,
}

Config.Payoff = {
    Radius      = 2.5,
    Price       = 750,   -- cash, charged server-side
    CooldownSec = 15,    -- per-character payoff cooldown
}

-- Pressing a witness in view of ANOTHER witness creates a fresh
-- intimidation incident against the presser. "In view" is approximated
-- server-side as another active witness within this range of the pressed
-- one (there is no server-side raycast; radius is the honest proxy).
Config.Intimidation = {
    WitnessRadius = 25.0,
    CrimeLabel    = 'witness intimidation',
}

-- ---------------------------------------------------------------------------
-- Presentation (Tier 3 — blip sprites are GTA V values)
-- ---------------------------------------------------------------------------
Config.PoliceBlip  = { sprite = 480, colour = 47, scale = 0.75, label = 'Witness' }
Config.SuspectBlip = { sprite = 480, colour = 1,  scale = 0.75, label = 'They saw you' }
Config.MarkerDrawDistance = 30.0   -- draw the ground marker inside this range

-- How often clients re-request their entitled witness list (seconds).
-- Event pushes cover the common case; this timer covers duty toggles and
-- late joins without any per-frame cost.
Config.ClientSyncSec = 60

-- ---------------------------------------------------------------------------
-- Anti-spam. gtarp_eventguard exposes no registration export for new
-- events (its guard list is its own static config, and we stay out of
-- other resources' files), so — per the gtarp_pumpcoin pattern — every
-- client-triggerable event here carries its own per-source rate limit AND
-- per-citizen cooldown, all server-side.
-- ---------------------------------------------------------------------------
Config.RateLimits = {   -- seconds, per source
    sync    = 10,
    canvass = 2,
    press   = 2,
    payoff  = 2,
    policeAlert = 10,   -- the police:server:policeAlert fan-in hook (it is
                        -- client-triggerable, so it needs its own limiter)
}

-- weaponDamageEvent fires per damage tick. When a crime goes unseen the
-- incident cooldown is refunded (by design), so this separate per-citizen
-- throttle caps how often the expensive GetAllPeds NPC scan can run.
Config.WeaponScanThrottleSec = 10
