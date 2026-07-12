# Palm6 — Player Cars & Clothes — Design Spec

**Date:** 2026-07-11
**Repo:** `gtarp` (Palm6 custom layer)
**Status:** Design approved (David, 2026-07-11). Terminal G owns the code; TF stood down.

## Goal

Give players the "cars and clothes" layer of the Palm6 RP loop, built on the
existing Qbox lean base (`qbx_vehicleshop`, `qbx_vehicles`/`qbx_garages`,
`illenium-appearance`) and shipped entirely through the `[custom]` layer this repo
auto-deploys — no hand-editing of remote base resources except through a reviewed,
idempotent deploy-time patch script (the proven `patch-ox-items.sh` pattern).

Four subsystems:

1. **Vehicle dealership catalog** — curate which cars are buyable + Palm6-tuned prices.
2. **Clothing / appearance** — branded clothing stores, barber, tattoo.
3. **New-player starter kit** — first spawn grants a starter vehicle (+ optional outfit) alongside the existing $1,500.
4. **Branded image assets** — delivered separately as `palm6/brand/CARS-CLOTHES-ASSET-PACK.md` (ChatGPT prompts). Not code.

## Grounding (real Qbox source, verified 2026-07-11 — not assumed)

- **`qbx_vehicleshop/config/shared.lua`**: `Config.finance` (minimumDown, maximumPayments),
  `Config.enableTestDrive`, `Config.vehicles` (`.default`, `.categories` map, `.models`
  model→shop map, `.blocklist`), and `Config.shops` — each shop has `type`
  (`free-use`/`managed`), `zone.shape`/`zone.size`, `blip`, `categories` (id→label),
  `testDrive`, `returnLocation`, `vehicleSpawns` (vec4), `showroomVehicles`.
  **Coords/spawns/showroom live here and are server-specific — the patch script must
  NEVER overwrite them.**
- **`qbx_core/shared/vehicles.lua`**: per-model table keyed by model with
  `{ name, brand, model, price (raw int), category, type, hash }`. **This is where car
  prices live.** Curating prices = rewriting `price` for a curated model set here.
- **`qbx_vehicles`**: `exports.qbx_vehicles:CreatePlayerVehicle{ model, citizenid, garage, props }`
  → returns `vehicleId` (or `nil, err`). Portable, schema-safe way to grant an owned car.
- **`illenium-appearance`**: `Config.Locations` (clothing / barber / tattoo / clothing
  rooms / outfit rooms as coord tables) + pricing. First-spawn appearance creator already
  runs for new characters, so players ALREADY choose clothes at spawn.

## Architecture

Everything lives under `resources/[custom]/`. Two mechanisms, chosen per what the base
resource actually reads:

- **Static Lua config (coords, catalog, prices)** → base resources read these at load;
  there is no runtime "add shop / set price" export. So changes go through a **deploy-time
  patch script** (`tools/patch-*.sh`) that transforms the *live deployed file* in place,
  idempotently, leaving it untouched on any failure. Modeled exactly on `patch-ox-items.sh`.
- **Runtime behavior (granting a car/outfit to a player)** → done live via confirmed
  exports, wrapped behind a `Bridge.*` adapter (GTA6-readiness bridge pattern), gated by
  a `UNIQUE(citizenid)` DB guard so it can only ever fire once per character.

### Subsystem 1 — Vehicle dealership catalog

- **`gtarp_dealership`** (new config-only resource): `shared/catalog.lua` = the canonical
  Palm6 catalog as pure data — a curated model list, each with a Palm6 **price tier**
  (economy / commuter / sedan / suv / sport / performance / super / motorcycle / offroad /
  utility) and a shop assignment (`pdm` standard lot vs `luxury` Bayside Prestige lot).
  Tier → price is a single table so the whole economy is tunable in one place. A boot-time
  `onResourceStart` validates the catalog (no dup models, price bounds, every tier defined)
  and prints a summary. No runtime game calls — safe.
- **`tools/patch-vehicle-prices.sh`** (deploy-time): reads `gtarp_dealership/shared/catalog.lua`,
  opens the live `[qbx]/qbx_core/shared/vehicles.lua`, and rewrites ONLY the `price =` field
  for each curated model to `tierPrice[tier]`. Idempotent (re-run = same result), verifies
  each target model exists, prints a per-model diff, and leaves the file untouched on any
  parse failure. Does not touch coords, categories, hashes, or any non-curated model.
- **Prices** are tuned to the real economy: starter cash $1,500, existing paychecks (read
  from `qbx_economy_overrides` JobPaychecks). A commuter car should be a few days' honest
  work, not a giveaway; supers are a long-term goal. Exact tier values live in the spec's
  companion table in `catalog.lua` and are reviewed before deploy.
- **Optional finance tune**: a second marker-block patch of `qbx_vehicleshop/config/shared.lua`
  `Config.finance` (e.g. minimumDown 20%, maximumPayments 24) — only if we want to deviate
  from stock. Default: leave stock (YAGNI) unless David asks.

### Subsystem 2 — Clothing / appearance

- New players already get the illenium first-spawn creator, so the core "pick your clothes"
  flow exists. Palm6 value-add:
  - **Branded stores** — the sign/menu art from the asset pack (Sundown Apparel, Bayside
    Cuts, Sundown Ink). Wiring art into illenium is asset-drop + a light NUI/config touch,
    deploy-side.
  - **Optional store config patch** — only if we want to change store locations/pricing from
    stock. Default: keep stock illenium locations (don't guess coords). If David wants
    specific store spots, that's a `patch-appearance.sh` marker-block against the live config.
- No forced runtime outfit by default (illenium outfit-save is version-specific and fragile).
  A preset "starter outfit" saved to the player's outfit list is possible later, gated OFF
  until validated in-game.

### Subsystem 3 — New-player starter kit (extends `gtarp_onboarding`)

Extend the existing guarded accept flow. After the `UNIQUE(citizenid)` INSERT succeeds and
starter cash is granted:

- **Starter vehicle** (config-gated, ON): `Bridge.GiveStarterVehicle(src, cid)` →
  `exports.qbx_vehicles:CreatePlayerVehicle{ model = Config.StarterVehicle.model,
  citizenid = cid, garage = Config.StarterVehicle.garage }`. On success, notify the player
  the car is in the named garage; flag `starter_vehicle_granted = 1`. Guarded the same way as
  cash: the once-per-citizen INSERT gate means the car can never be granted twice, even under
  replayed events. Model defaults to a cheap, legal economy car (e.g. `panto` or `blista`);
  garage defaults to a central public garage name (confirmed at deploy).
- **Starter outfit** (config-gated, OFF by default): placeholder Bridge hook
  `Bridge.SetStarterOutfit`; left OFF until the illenium outfit-save path is validated in-game.
- **DB**: add nullable columns `starter_vehicle_granted TINYINT(1) DEFAULT 0` and
  `starter_outfit_granted TINYINT(1) DEFAULT 0` to `gtarp_onboarding` via a new numbered
  migration (next free number after 0044). Additive, safe, idempotent guard unchanged.
- **Bridge additions** (`gtarp_onboarding/bridge/sv_framework.lua`): `GiveStarterVehicle`,
  `SetStarterOutfit`, `ResourceStarted('qbx_vehicles')` guard so the grant no-ops cleanly if
  the vehicle resource is absent (never crashes onboarding — cash still lands).

### Subsystem 4 — Branded assets

Delivered: `palm6/brand/CARS-CLOTHES-ASSET-PACK.md` — 11 ChatGPT prompts (dealership logo /
menu bg / lot signs / poster, clothing logo / sign / menu bg, barber sign, tattoo sign,
garage sign) on the Palm6 palette + Leonida style clause, license-safe (no real car
makes/badges/brands). David generates on ChatGPT and drafts to the MGT email. Save to
`palm6/brand/ingame/`; each maps to an in-game destination in the pack's delivery table.

## Error handling & safety

- Every framework/native call is behind `Bridge.*`; `pcall`-wrapped; missing base resource →
  graceful no-op, never a crash of onboarding.
- Starter grants are idempotent via the existing `UNIQUE(citizenid)` guard.
- Patch scripts: idempotent, verify targets exist, per-item diff, **leave live file untouched
  on any failure** (same contract as `patch-ox-items.sh`).
- No guessed coords/prices baked into any base file — prices come from the reviewed catalog;
  coords are never written.

## Testing

- **`gtarp_devtest`**: add boot-check assertions — catalog validates, tier table complete,
  `gtarp_dealership` online, onboarding exports present. (devtest already gates boot; the
  drugs work added similar checks.)
- **In-game (deploy-validated, can't be automated locally):** buy a car at each lot at the
  curated price; new character receives starter car in the right garage exactly once; clothing
  stores show branded art.

## Out of scope (YAGNI)

- Custom addon vehicles / EUP clothing packs (streamed binary assets — separate effort).
- Reworking store/dealership *locations* (keep stock coords unless David specifies).
- Forced starter outfit (deferred, gated OFF).

## Build order

1. This spec.
2. Migration `sql/00NN_onboarding_starter_grants.sql` + starter-kit code in `gtarp_onboarding`.
3. `gtarp_dealership` catalog resource + `tools/patch-vehicle-prices.sh`.
4. `gtarp_devtest` boot-checks.
5. Clothing store config/art wiring (mostly deploy-side; asset pack already delivered).
