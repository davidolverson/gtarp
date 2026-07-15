-- ============================================================================
-- palm6_clout/shared/config.lua — engine-agnostic tunables (Tier 1, carries
-- to VI). Viewer math, donation economy, milestones, VOD rules, and every
-- timing live here; only the pawnshop coords, danger-zone coords, and the
-- ped model are Tier 3 (Los Santos values).
--
-- IMPORTANT: milestone payouts are snapshotted per-deal at UNLOCK time.
-- Retuning Milestones here affects deals unlocked AFTER the change — money
-- already earned is never silently repriced.
-- ============================================================================
Config = {}

Config.Debug = false

-- ---------------------------------------------------------------------------
-- Streamer phone (inventory gate).
-- Going live requires holding this inventory item. The item must exist in
-- your inventory data — see README for the one-block item definition to
-- paste into your items catalog. Set to false to run without the item gate
-- (anyone can /golive). Checked at go-live AND re-checked every tick: sell
-- or lose the phone mid-stream and the stream dies.
-- ---------------------------------------------------------------------------
-- RE-GATED 2026-07-15: streamer_phone is now defined in
-- ox_inventory_overrides/data/items.lua AND sold at the General Store ($2500),
-- so the go-live gate is a real one-time cost basis (clean donations/brand
-- deals were otherwise minted with zero cost). Re-checked every tick: sell or
-- lose the phone mid-stream and the stream dies. Set false to ungate again.
Config.PhoneItem = 'streamer_phone'

-- ---------------------------------------------------------------------------
-- Stream lifecycle (all enforced server-side).
-- ---------------------------------------------------------------------------
Config.TickIntervalMs = 5000     -- viewer-sim cadence; one pass over all live streams
Config.GoLiveCooldownSec = 60    -- per character, between stream starts
Config.WarmupSec = 60            -- min stream age before donations/milestones count
                                 -- (the min-elapsed half of the stream's elapsed gate)
Config.MaxStreamSec = 7200       -- hard cap; streams auto-end after 2h
                                 -- (the max-elapsed half — bounds every per-stream loop)
Config.AnnounceGoLive = true     -- server-wide "went LIVE" ping (drives the chase-off RP)

-- ---------------------------------------------------------------------------
-- Viewer simulation. Viewers are pure server math — no external anything.
-- Each tick: score real nearby events, else decay toward the floor.
-- ---------------------------------------------------------------------------
Config.StartViewersMin = 8       -- opening audience is a dice roll in this range
Config.StartViewersMax = 18
Config.MinViewers = 5            -- decay floor while live
Config.MaxViewers = 2500         -- hard ceiling on the counter

Config.IdleDecayPct = 0.06       -- share of viewers lost per quiet tick (6%)

-- Anything witnessed inside this radius of the streamer is "on stream" —
-- it scores viewers AND lands on the VOD.
Config.WitnessRadius = 30.0

Config.Gain = {
    GunshotEvent = 8,            -- per weapon-damage event witnessed (one per shooter/tick)
    MaxGunshotEventsPerTick = 4, -- cap so a mag-dump is content, not a printer
    Explosion = 25,              -- per explosion witnessed
    MaxExplosionsPerTick = 2,
    PoliceChase = 30,            -- streamer moving fast with police close = peak content
    CrowdPerPlayer = 2,          -- each other player within WitnessRadius
    CrowdCap = 16,               -- crowd bonus ceiling per tick
}

-- "Police chase involvement": streamer speed above this (m/s; 20 = 72 km/h)
-- with an on-duty officer within PoliceChaseRadius. Both checked server-side.
Config.ChaseSpeedMs = 20.0
Config.PoliceChaseRadius = 60.0

-- Dying on stream: viewers spike (the clip goes viral) for one tick, then
-- the stream resets to a fresh opening audience. The spike fires ONCE per
-- stream — repeat deaths just reset. A one-tick spike can never sustain a
-- milestone (see MilestoneSustainTicks), so dying is a stat, not a farm.
Config.DeathSpikeMult = 2.5
-- A player ped reads as down/dead at or below this health (GTA V player
-- health floor is 100; retune for VI).
Config.DeadHealthThreshold = 100

-- ---------------------------------------------------------------------------
-- Danger zones (palm6_turf synergy — soft dependency).
-- Streaming inside a GANG-OWNED turf zone multiplies every viewer gain:
-- filming on somebody's block is exactly the content the audience wants —
-- and exactly why the gang wants the camera gone. Ownership is read from
-- the palm6_turf table (refreshed every TurfRefreshSec); if that resource
-- or table is absent this silently never applies.
-- Zone ids + coords MUST mirror palm6_turf's Config.Zones (Tier 3 coords).
-- ---------------------------------------------------------------------------
Config.DangerZoneEnabled = true
Config.DangerZoneMult = 1.5
Config.DangerZoneRadius = 80.0
Config.TurfRefreshSec = 60
Config.DangerZones = {
    { id = 'legion_square', coords = vector3(195.17, -933.77, 30.69) },
    { id = 'grove_street',  coords = vector3(-47.30, -1757.40, 29.42) },
    { id = 'mirror_park',   coords = vector3(1163.10, -322.90, 69.20) },
    { id = 'vinewood',      coords = vector3(-1222.10, -906.90, 12.33) },
    { id = 'sandy_shores',  coords = vector3(1961.30, 3740.30, 32.34) },
    { id = 'paleto_bay',    coords = vector3(1728.66, 6414.16, 35.04) },
}

-- ---------------------------------------------------------------------------
-- Donations. Every DonationIntervalSec a donation MAY fire, with probability
-- scaled by current viewers. In-game cash, hourly-capped. The donor name is
-- picked server-side and fed to the overlay so the chat line matches the
-- money that actually moved.
-- ---------------------------------------------------------------------------
Config.DonationIntervalSec = 90
Config.DonationViewerDivisor = 400  -- chance = viewers / divisor (see clamps)
Config.DonationMinChance = 0.05
Config.DonationMaxChance = 0.90
Config.DonationMin = 25             -- $ floor per donation
Config.DonationMax = 120            -- $ ceiling before the viewer bonus
Config.DonationPerViewer = 0.35     -- + floor(viewers * this) on top
Config.DonationHourlyCap = 3000     -- $ per character per rolling hour
                                    -- (in-memory ledger; resets on resource restart)

Config.DonorNames = {
    'xX_Sn1per_Xx', 'GrindsetGoblin', 'LethalLarry', 'NPC_Energy', 'ClipFarmer99',
    'BasedBecky', 'OGKushLord', 'ratio_machine', 'SendItSteve', 'DrDonowitz',
    'MoistCritikal2', 'FreeVbucks_org', 'YourMomsFavorite', 'CopWatcher24',
    'BlockBaby400', 'TouchGrassAndy', 'W_Rizzler', 'SkillIssueSam', 'LilCapper',
    'GigaChadwick', 'PoorCashApp', 'The5thStar', 'AltF4Gaming', 'MicMuted',
}

-- ---------------------------------------------------------------------------
-- Brand deals. Holding a viewer count at/above each milestone for
-- MilestoneSustainTicks CONSECUTIVE ticks (post-warmup) unlocks a ONE-TIME
-- deal per character, cashed out at the pawnshop broker. Payout is
-- snapshotted at unlock. Keep sorted ascending by viewers.
-- ---------------------------------------------------------------------------
Config.MilestoneSustainTicks = 3
Config.Milestones = {
    { viewers = 50,   payout = 500,   label = 'SqueezeIt Energy — sponsored shoutout' },
    { viewers = 100,  payout = 1250,  label = 'Cluckin Bell — mukbang promo' },
    { viewers = 250,  payout = 3000,  label = 'UpNAtom Burger — collab drop' },
    { viewers = 500,  payout = 7500,  label = 'Sprunk — exclusive can reveal' },
    { viewers = 1000, payout = 20000, label = 'iFruit — flagship ambassador deal' },
}

-- ---------------------------------------------------------------------------
-- Pawnshop broker (brand-deal cashout). Tier 3 — Los Santos values.
-- Ground point reuses the repo-validated Vespucci canals alley spot
-- (palm6_pumpcoin exchange #2) — same alley, different hustle.
-- ---------------------------------------------------------------------------
Config.PawnshopCoords = vector4(-1179.5, -1483.5, 4.4, 125.0)
Config.PawnPedModel = 's_m_y_dealer_01'
Config.PawnSpawnRadius = 60.0    -- broker ped exists only when a player is this close
Config.InteractRadius = 2.0
Config.ClaimCooldownSec = 5

-- ---------------------------------------------------------------------------
-- The VOD (evidence liability). While live, witnessed crime events are
-- written to palm6_clout_vod — who, what, where, when.
-- ---------------------------------------------------------------------------
Config.VodRetentionHours = 24    -- how far back a subpoena reaches
Config.VodPruneDays = 7          -- rows older than this are deleted (housekeeping)
Config.VodMaxRowsPerMin = 10     -- per streamer — bounds DB writes under gunfights
Config.VodDedupeSec = 30         -- same suspect + same event type collapses within this

-- Police subpoena: on-duty police serve it on a streamer IN PERSON.
Config.SubpoenaRadius = 15.0     -- officer must be this close to the target
Config.SubpoenaCooldownSec = 60  -- per officer
Config.SubpoenaRowLimit = 25     -- most recent clips shown
-- Serving a subpoena also files a summary entry into the police evidence
-- log (palm6_evidence synergy — soft dependency, skipped if absent).
Config.WriteEvidenceOnSubpoena = true

-- ---------------------------------------------------------------------------
-- Misc.
-- ---------------------------------------------------------------------------
Config.TopStreamersLimit = 10    -- /streamers leaderboard size
Config.LiveTagText = '* LIVE *'  -- head tag over live streamers (everyone sees it)
Config.ClientTagRefreshMs = 2500 -- head-tag bookkeeping cadence (skipped when nobody is live)
Config.SweepIntervalMs = 30000   -- server housekeeping cadence
