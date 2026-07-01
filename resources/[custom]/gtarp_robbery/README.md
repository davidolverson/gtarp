# gtarp_robbery

Store & ATM robberies — the illegal side of the economy that gives the police
job something to respond to. Completes the loop alongside `gtarp_grind` (legal)
and `gtarp_housing`.

Bridge-pattern (see `docs/GTA6-READINESS.md`): logic in `server/` + `client/`;
all qbx/ox_inventory/native/ox_lib calls in `bridge/`. No DB — cooldowns are
in-memory.

## How it works

1. Draw a weapon, walk to a store register or ATM, `[E]`.
2. Server checks the **police gate** (`Config.MinPolice`), the per-spot
   **cooldown**, and proximity, then **reserves** the spot and fires a
   **dispatch** (blip + notify) to every on-duty officer.
3. Hold through the progress bar (`Config.*.hold_seconds`). Moving away cancels
   it (soft 60s penalty so start/cancel can't spam dispatch).
4. On completion the server pays `reward_min..reward_max` cash; stores have a
   chance to also drop `markedbills` (only if that item exists).

Two-phase + server-side proximity re-check on completion keeps the reward
authoritative; the weapon requirement is a client gate.

## Solo testing

`Config.MinPolice = 0` ships by default so a robbery completes with **no cops
online** — ideal for the first smoke test. Raise it (2–3) before going live so
robberies require police presence.

## Tuning (`shared/config.lua`)

- `Stores` / `ATMs`: hold time, cooldown, reward range, locations.
- `Stores.marked_*`: optional marked-bills loot.
- `Dispatch`: blip sprite/colour/scale + alert lifetime.
- `MinPolice`, `InteractRadius`, `RequireWeapon`.

## GTA VI notes (Tier 3)

Register/ATM coords are Los Santos points (see `docs/GTA6-TIER3-RETUNE.md`).
Rewards, timers, cooldowns, and the dispatch design are Tier 1 and carry.

## Deferred to v2

- Bank/jewellery heists (multi-stage, crew-based).
- Wanted level / heat that decays and scales police response.
- Register props/animations and lockpick minigames.
- Fence NPC to launder `markedbills`.
