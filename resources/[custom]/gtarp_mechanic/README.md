# gtarp_mechanic

Vehicle repair invoices for on-duty mechanics. Fills in the "repair
invoices to other players" income stream that
`qbx_civilian_jobs_overrides/config.lua` documents but never implemented —
the mechanic job's on-call runs were always meant to be a minor supplement
to this, not the whole job.

Bridge-pattern (see `docs/GTA6-READINESS.md`): all logic is in `server/` and
`client/`; every qbx/native/ox_lib call lives in `bridge/`.

## How it works

- **Find a damaged vehicle.** Any vehicle with engine or body health below
  `Config.EngineHealthThreshold` / `Config.BodyHealthThreshold` shows a
  repair prompt to anyone standing near it — the job/duty gate is
  server-authoritative, not client-hidden.
- **Start.** `[E]` as an on-duty mechanic near a damaged vehicle looks for
  another player within `Config.CustomerSearchRadius` of the vehicle to
  invoice. No nearby customer, no repair — mechanics don't self-service.
  The vehicle goes on a per-vehicle cooldown immediately, before the
  progress bar, so it can't be double-started.
- **Complete.** After the repair progress bar finishes, the server
  re-validates (still on duty, still near the vehicle, customer still
  around and able to pay), charges the customer's bank
  `Config.RepairCost`, credits the full amount to the mechanic, then tells
  the mechanic's client to actually fix the vehicle
  (`SetVehicleFixed` + engine/body health + deformation).

## Commands

| Command | Where | Effect |
| --- | --- | --- |
| `[E]` near a damaged vehicle | on-duty mechanic | start a repair invoice |

## Config (`shared/config.lua`)

- `InteractRadius`, `CustomerSearchRadius` — proximity gates.
- `RepairCost` — flat invoice, paid customer → mechanic in full.
- `RepairCooldownSeconds` — per-vehicle, prevents immediate re-invoicing.
- `EngineHealthThreshold`, `BodyHealthThreshold` — damage threshold to show
  the prompt at all.

## Deploy

- `ensure gtarp_mechanic` is wired into `custom.cfg`.
- No SQL migration — no persistent state, matching `gtarp_robbery`.

## GTA VI notes (Tier 3)

None — this resource has no map-bound coords or model names of its own.
The mechanic starter NPC location it complements
(`qbx_civilian_jobs_overrides/config.lua`) is already tracked in
`docs/GTA6-TIER3-RETUNE.md` §3.

## Deferred to v2

- Configurable per-tier repair pricing (light vs. heavy damage).
- Optional parts/inventory item requirement to repair.
- A society-fund split instead of paying the mechanic 100% directly.
