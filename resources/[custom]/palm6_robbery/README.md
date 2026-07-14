# palm6_robbery

ATM robberies — the illegal side of the economy that gives the police job
something to respond to. Completes the loop alongside `palm6_grind` (legal).

**Store/register robbery is intentionally not here.** The recipe's own
`qbx_storerobbery` already does that at the exact same store locations
(registers, safes, cameras, lockpick requirement, cop-count gate) — confirmed
by reading `resources/[qbx]/qbx_storerobbery` directly. An earlier draft of
this resource duplicated it; that half was removed before merge (see the
"verify against the real deployed tree" lesson in `docs/DEVELOPMENT.md`).
Bank vault heists are `qbx_bankrobbery` (recipe). ATMs are the one gap neither
recipe resource covers, so that's the whole scope here.

Bridge-pattern (see `docs/GTA6-READINESS.md`): logic in `server/` + `client/`;
all qbx/ox_inventory/native/ox_lib calls in `bridge/`. No DB — cooldowns are
in-memory.

## How it works

1. Draw a weapon, walk to an ATM, `[E]`.
2. Server checks the **police gate** (`Config.MinPolice`), the per-ATM
   **cooldown**, and proximity, then **reserves** the spot and fires a
   **dispatch** (blip + notify) to every on-duty officer.
3. Hold through the progress bar (`Config.ATMs.hold_seconds`). Moving away
   cancels it (soft 60s penalty so start/cancel can't spam dispatch).
4. On completion the server pays `reward_min..reward_max` cash.

Two-phase + server-side proximity re-check on completion keeps the reward
authoritative; the weapon requirement is a client gate.

## Solo testing

`Config.MinPolice = 0` ships by default so a robbery completes with **no cops
online** — ideal for the first smoke test. Raise it (2–3) before going live so
robberies require police presence.

## Tuning (`shared/config.lua`)

- `ATMs`: hold time, cooldown, reward range, locations.
- `Dispatch`: blip sprite/colour/scale + alert lifetime.
- `MinPolice`, `InteractRadius`, `RequireWeapon`.

## GTA VI notes (Tier 3)

ATM coords are Los Santos points (see `docs/GTA6-TIER3-RETUNE.md`). Reward,
timer, cooldown, and the dispatch design are Tier 1 and carry.

## Deferred to v2

- Wanted level / heat that decays and scales police response.
