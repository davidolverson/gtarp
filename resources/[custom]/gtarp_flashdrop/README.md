# gtarp_flashdrop

**Hype-drop culture for your city.** Limited-serial sneaker drops at surprise
locations, an organic flash-mob scramble, a consignment resale market with
full provenance, a no-questions fence, and counterfeits that pass a glance
but fail a legit check. Scarcity is **server-enforced**: every genuine pair
is a serialized one-of-N minted by the server and tracked in a registry that
no client can touch.

No other GTA RP script models hype-drop scarcity economics — drop events,
serials, provenance, resale, and counterfeits in one loop.

Bridge-pattern (see `docs/GTA6-READINESS.md`): all logic is in `server/` and
`client/`; every framework/native call lives in `bridge/`.

## The loop

1. **The riddle (T-30 min).** The scheduler (or an admin) arms a drop: a
   fictional branded pair with a hard supply cap (e.g. 12 serialized pairs).
   Every player in the city gets a location riddle. Crews argue, stake out,
   guess wrong.
2. **The leak (T-5 min).** Exact location hits everyone's map with a
   flashing blip. Organic flash mob. If the drop lands on claimed gang turf,
   the reveal calls the gang out by name.
3. **The line (T-0).** A pop-up table with a claim interaction. Checkout is
   a per-player **8-second timer**, one pair per citizen, cash only. Those 8
   exposed seconds — and the walk back to the car with $1,200 sneakers in
   your pocket — are the actual game. Blocking the line, taxing the table,
   and robbing people walking away all need zero extra code.
4. **The aftermarket.** Serials hit the consignment boutique at player-set
   prices (house keeps 10%). Every mediated transfer is provenance-logged.
   Robbed of your pair? Report the serial stolen: it is flagged **dirty
   forever** — the boutique refuses it, and the thief's only exit is the
   fence at 40% of retail.
5. **The fakes.** A back-alley workbench clones any drop the street has
   already seen. A fake is **byte-identical** to a real pair in the
   inventory — same label, same plausible serial. Only a paid legit-check
   minigame against the server registry (or the fence's expert lowball)
   tells them apart. Scamming a buyer with fakes is fully supported RP.

## Player surfaces

| Surface | Where | What |
| --- | --- | --- |
| Drop table | announced per-drop | claim one pair — 8s checkout, cash |
| SoleWorth Consignment | Rockford Hills (blipped) | browse / consign / cancel / legit check / report stolen |
| The fence | Sandy Shores (unmarked) | sells any pair no questions: 40% retail genuine, 5% fakes |
| Counterfeit bench | La Mesa alley (unmarked) | $300 + 12s crafts a fake of any past drop |

## Commands

| Command | Who | Effect |
| --- | --- | --- |
| `/flashdrop arm [CODE] [locationId] [hintSec] [revealSec] [liveSec]` | admin | arm a drop (args optional — random when omitted) |
| `/flashdrop cancel` | admin | pull the active drop |
| `/flashdrop status` | admin | active drop / scheduler ETA |

The command is ace-restricted. Grant it once in your server cfg:
`add_ace group.admin command.flashdrop allow`

## Server authority (what a modified client can NOT do)

- Serials are minted server-side only; supply caps, one-per-citizen, and
  stock (including in-flight reservations) live in server memory + MySQL.
- Both checkout phases re-check proximity server-side; the finish phase
  enforces a **min AND max elapsed** window (no instant checkouts, no
  parked reservations) **and a position anchor** — finish must happen within
  a few metres of where start happened, because the progress bar locks
  movement, so skipping the bar to move or fight through the window voids
  the claim. Craft enforces the same window + anchor. Legit-check enforces
  the window, proximity, and possession; the skill-check pass/fail itself is
  client-reported (deliberate: the fee is charged up front and a "pass" only
  reveals registry truth about a pair the player already holds).
- Every price, fee, payout, and affordability check is server-side; the
  consignment buy claims the listing row **atomically** so two buyers can
  never win the same pair, and every mutation reverts cleanly on a full
  inventory or failed charge.
- All client-triggerable events are rate-limited (`Config.RateLimits`).
- Fake/dirty status lives ONLY in the registry — item metadata is identical
  on real and counterfeit pairs, so inventory inspection reveals nothing.

## Config guide (`shared/config.lua`)

- **`Config.Catalog`** — the brand lineup: code, label, retail, supply cap,
  rarity weight (scheduler tickets), flavor blurb.
- **`Config.Locations`** — drop spots: coords + the T-30 riddle + optional
  `turfZone` (a `gtarp_turf` zone id for the reveal callout).
- **`Config.Timing`** — hint/reveal leads, live window, the 8s checkout,
  grace window, claim radius.
- **`Config.Scheduler`** — auto-drop cadence + minimum player count.
- **`Config.Consignment` / `Config.Fence` / `Config.Counterfeit`** —
  locations, ped models, fees, payout rates, cooldowns, listing caps.
- **`Config.LegitCheck`** — fee, cooldown, minigame difficulty ramp.
- **`Config.DropProp` / `Config.DropBlip`** — drop-site dressing.

## Install

1. Drop the folder in `resources/[custom]/` and add to `custom.cfg`:
   `ensure gtarp_flashdrop` — **after** `ox_inventory` and
   `ox_inventory_overrides`. The `flashdrop_sneaker` base item ships in
   `ox_inventory_overrides/data/items.lua` (`ExtraItems`); this resource
   presence-checks it at start and, if the inventory cannot resolve it,
   prints a loud console error and disables drops + crafting (runtime table
   merges do not reach ox_inventory — export returns are copies).
2. Apply `sql/0017_flashdrop.sql` (creates the four `gtarp_flashdrop_*`
   tables; `CREATE TABLE IF NOT EXISTS`, touches nothing else).
3. Grant the admin ace: `add_ace group.admin command.flashdrop allow`.
4. Test fast: `/flashdrop arm VLTA legion_underpass 60 30 300` = riddle
   now, reveal in 30s, doors in 60s, closes 5 min later.

Requires: `qbx_core`, `ox_lib`, `oxmysql`, `ox_inventory`. `ox_target` is
strongly recommended (falls back to marker + E prompts without it).

## Synergies (all soft — degrade silently when absent)

- **gtarp_turf**: drops with a `turfZone` read the zone owner and name the
  gang in the reveal broadcast. Free conflict.
- **gtarp_evidence**: stolen-serial reports write a theft entry to the
  evidence table for detective RP (same soft pattern as gtarp_pumpcoin's
  rug reveals). Robberies around drops feed cases organically.
- **Economy**: retail, the 10% consignment fee, legit-check fees, and
  counterfeit materials are all cash sinks; the fence's 40% is the only
  printer and pays under retail by design.

## Perf

48-slot safe. No unconditional per-frame client loops: interactions are
ox_target zones (event-driven) or 16m-gated marker points; drop-site
dressing (blip/prop/zone) exists only between reveal and close; the server
runs a single 5s lifecycle sweep.

## GTA VI notes (Tier 3)

Drop location coords, consignment/fence/bench coords, ped models, the table
prop, and blip sprites are Los Santos values — re-author against the VI map
(`docs/GTA6-TIER3-RETUNE.md`). The catalog, serials, registry, provenance,
market rules, and every timer are Tier 1 and carry unchanged.

## Deferred to v2

- Raffle-entry drops (pre-registration instead of first-come lines).
- Player-to-player direct trades logged in provenance (today only mediated
  transfers touch the registry — street trades are deliberately off-book).
- Wear/condition affecting resale value.
- A "grail wall" leaderboard of biggest collections.
