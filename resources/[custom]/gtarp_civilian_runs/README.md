# gtarp_civilian_runs

The playable loop behind `qbx_civilian_jobs_overrides`' curated `runs`
(trucker, taxi, garbage, mechanic on-call). That resource validates and
**exports** the run catalog (`GetJobs`/`GetJob`/`GetPayoutBounds`) but
nothing ever called those exports to actually run a job — this resource
is that consumer.

Bridge-pattern (see `docs/GTA6-READINESS.md`): all logic is in `server/`
and `client/`; every qbx/native/ox_lib call lives in `bridge/`. Deliberately
generic across all four curated jobs — it reads whatever
`qbx_civilian_jobs_overrides` publishes rather than hardcoding job names, so
adding a fifth curated job there needs no changes here.

## How it works

- **Dispatch NPC.** Near any curated job's `starter_npc` coords, `[E]`
  opens a menu of that job's `runs` (route name, payout, cooldown).
- **Start.** Picking a run checks (server-side): on duty as that job,
  near the NPC, and that run isn't on cooldown. The cooldown reserves
  immediately, before the drive, so it can't be double-started.
- **Drive.** A route blip appears at a random point 150–1000m from the
  NPC (distance scales with the run's position in its job's `runs` array —
  first run = shortest/cheapest, last = longest/most-lucrative) with a
  time limit to match.
- **Arrive.** Getting within `Config.ArrivalRadius` of the blip before
  time runs out pays the run's configured payout to the player's bank.
  Running out of time pays nothing (the cooldown still applies).

## Config (`shared/config.lua`)

- `InteractRadius`, `ArrivalRadius` — proximity gates.
- `DestDistanceByTier`, `TimeLimitByTier` — destination distance and time
  limit per run-tier (index within a job's `runs` array).

## Deploy

- `ensure gtarp_civilian_runs` is wired into `custom.cfg`, after
  `qbx_civilian_jobs_overrides`.
- No SQL migration — no persistent state, matching `gtarp_robbery` and
  `gtarp_mechanic`.

## GTA VI notes (Tier 3)

None of the coords here are hardcoded — destinations are generated at
runtime relative to each job's `starter_npc.coords`, which is already
tracked in `docs/GTA6-TIER3-RETUNE.md` §3. Nothing new to add there.

## Deferred to v2

- Destination points are a random offset, not terrain-snapped — on the
  largest tier (600–1000m) a marker can occasionally land off-road or at
  the wrong elevation. Fine for a drivable approximation; a curated
  waypoint pool per job would be the real fix.
- No job-specific flavor (trucker doesn't carry cargo, taxi has no
  passenger, garbage has no bins) — this is a single generic "go there,
  get paid" loop shared by all four jobs, not four distinct minigames.
- No multi-stop routes.
