# palm6_counterfeit

**Counterfeit cash with a memory.** A deployable printing press mints
serialized fake bills; every transfer — player trade, ground drop, sink
spend, fence pass — is remembered as a provenance hop; printing warms a
district heat value police feel only as a vague zone ping; and one seized
serial at the evidence locker terminal cascades, lead by lead and
interrogation by interrogation, into a full network takedown.

Money printers are a commodity script. The 1-of-1 here is the **paper
trail**: a hop chain capped at the last 6 transfers (the trail literally
wears off if you move paper fast), batch quality that decays with greed,
and a police investigation loop built ON the `palm6_evidence` v2 case
system rather than beside it.

Bridge-pattern (see `docs/GTA6-READINESS.md`): all logic is in `server/`
and `client/`; every qbx/ox/native call lives in `bridge/`.

## Not dirty money (integration contract)

The recipe's `markedbills` (qbx_storerobbery, qbx_drugs) is **dirty REAL
money** that needs laundering. `counterfeit_cash` is **FAKE money** that
needs *passing*. It deliberately:

- has a distinct item name and never stacks (each wad is one serial),
- can never be laundered, deposited, or bulk-exchanged for clean cash,
- exits circulation only via goods (sinks), risk-priced per-wad fence
  passes, NPC confiscation, or a police evidence bag.

## The loop

1. **The press.** Use a `counterfeit_printer` item next to real printing
   gear — an office copier, a print-shop machine, or (with `bob74_ipl`)
   the Bikers counterfeit-cash factory dressing (`Config.Printer.
   AnchorProps`). Placement must be inside a configured district;
   1 press per character, 50 m spacing, all server-enforced at the
   player's server-side position.
2. **The run.** Feed the hopper `counterfeit_paper` + `counterfeit_ink`,
   run a 20 s print cycle (two-phase, server-verified window + position
   anchor). Out come 4 wads of `counterfeit_cash` — each with a
   server-minted serial (`CF-K7M2PQ-03`) in metadata, each opening its own
   provenance chain. Every cycle **heats the district**.
3. **The heat.** Above the threshold, on-duty police get a wide, jittered
   area circle — a weather report, never a waypoint. Heat decays; going
   quiet is a strategy. A raid (`/counterfeitraid` within 15 m of a press)
   clears it.
4. **The spend.** Wads move hand to hand (every ox_inventory transfer is a
   hop), buy goods at shady vendors (sinks — goods, never money), or cash
   out at one of two back-room **fences** at 35% of face. Sinks and fences
   check the paper with probability rising with the batch's circulation
   and print size — *quality decays with greed*. A caught wad is refused,
   sometimes kept, sometimes reported (`police:server:policeAlert`, the
   same alert plumbing as qbx_drugs cornerselling — but fixed venues,
   per-wad serialized passes, daily quotas, and a batch-history risk curve
   instead of street-corner coin flips).
5. **The pen.** A `marker_pen` skill check reveals the registry truth
   about any wad you hold: serial, wear band, hands passed. Civilians can
   test what they're being paid with; cops confirm before seizing.
6. **The bust.** An officer takes a wad (recipe search/RP), `/seizefake`
   bags it — consuming a qbx_police `empty_evidence_bag` into a
   `filled_evidence_bag` whose metadata names the serial (soft: works
   bagless too). At the evidence locker, `/runserial CF-XXXXXX-NN` opens
   an idempotent per-batch case via the `palm6_evidence` v2 exports and
   unlocks the **last 2 hops as named leads** (suspects linked by
   citizenid). `/interrogate <case> <citizenid>` — with the suspect
   physically in front of you — unlocks the next hop. Repeat, hop by hop,
   until the chain closes on the press district. One bust cascades into a
   network takedown.

**The counter-play is real:** the chain keeps only the newest 6 hops. A
crew that moves paper through enough hands erases the print hop itself —
police trace a serial and find the trail worn blank.

## Player surfaces

| Surface | Where | What |
| --- | --- | --- |
| The press | player-placed (anchored to printing gear) | feed / print / pack up — owner only |
| Sinks x3 | Vespucci, La Mesa, Paleto (unmarked) | one wad -> a basket of goods |
| Fences x2 | Sandy pawn, Strawberry arcade (unmarked) | one wad -> 35% face in cash, quota 6/day |
| Detector pen | item, anywhere | skill check -> registry verdict |
| Serial terminal | evidence locker (Mission Row) | `/runserial`, then the cascade |

## Commands

| Command | Who | Effect |
| --- | --- | --- |
| `/seizefake` | on-duty police | bag a held wad (evidence-bag pattern) |
| `/runserial <serial>` | on-duty police, at the locker | open/join the batch case, unlock last 2 hops as leads |
| `/interrogate <case id> <citizenid>` | on-duty police, suspect within 4 m | unlock the next hop for every serial they touched |
| `/counterfeitraid` | on-duty police | seize a press within 15 m, clear district heat, log to the case |
| `/counterfeit` | admin (ace) | presses + district heat status |

Grant the admin ace once: `add_ace group.admin command.counterfeit allow`

## Server authority (what a modified client can NOT do)

- Serials are minted server-side only; the registry, hop chains, batch
  circulation, heat, quotas, and every detection/rejection roll live in
  server memory + MySQL.
- Placement uses the player's **server-side position** — the client never
  supplies coordinates. District containment, spacing, per-citizen cap,
  and item possession are all server-checked. The anchor-prop scan is the
  only client-reported input (map props are invisible to the server); it
  is placement *flavor* — spoofing it buys a printer in an ugly spot and
  nothing else.
- Print cycles are two-phase with **min AND max elapsed** server windows,
  fresh proximity, and a position anchor (the progress bar locks movement
  client-side; skipping it to move through the window fails the anchor
  and eats the materials). A janitor sweep voids sessions whose client
  never reported back.
- The pen's skill-check pass/fail is client-reported **by design** (same
  trust boundary as palm6_flashdrop's legit check): it only reveals
  registry truth about a wad the caller already physically holds —
  possession is re-checked server-side on finish.
- Every client-triggerable event is rate-limited (`Config.RateLimits`);
  per-character cooldowns gate print/sink/fence/pen.
- All police surfaces re-check on-duty status and distance server-side.

## Data (sql/0020_counterfeit.sql)

Six `palm6_counterfeit_*` tables (`CREATE TABLE IF NOT EXISTS`, no
framework tables touched): printers, batches, wads (the serial registry),
hops (the capped provenance chain), leads (cascade depth per case+serial),
heat (per-district, restart-safe). Case files themselves live in
`palm6_evidence` — this resource stores only *how deep* each serial has
been revealed, so there is no parallel evidence store.

## Install

1. `ensure palm6_counterfeit` in `custom.cfg` — **after** `ox_inventory`,
   `ox_inventory_overrides`, and `palm6_evidence`.
2. The five items (`counterfeit_cash`, `counterfeit_printer`,
   `counterfeit_paper`, `counterfeit_ink`, `marker_pen`) ship in
   `ox_inventory_overrides/data/items.lua` (`ExtraItems`). This resource
   presence-checks them (plus every sink good) at start and, if anything
   is missing, prints a loud console error and disables itself entirely
   (runtime item merges cannot reach ox_inventory — export returns are
   msgpack copies).
3. Apply `sql/0020_counterfeit.sql`.
4. Grant the admin ace (above).
5. Distribute `counterfeit_printer` / paper / ink / `marker_pen` through
   your black-market channels of choice (deliberately not shopped here —
   supply is an RP lever).

Requires: `qbx_core`, `ox_lib`, `oxmysql`, `ox_inventory` (hook API for
provenance), `palm6_evidence` (v2 exports — the serial terminal goes
offline without it, everything else still runs). Soft: `qbx_police`
(policeAlert + evidence-bag items; falls back to a direct officer
dispatch and bagless seizure), `ox_target` (marker + E prompt fallback),
`bob74_ipl` (extra anchor props), OneSync (server-side press prop —
cosmetic only).

## Config guide (`shared/config.lua`)

- **`Config.Districts`** — where presses may operate and heat is scored.
- **`Config.Printer`** — anchor-prop whitelist, spacing, hopper caps.
- **`Config.Print`** — cycle economics: materials, wads, face value,
  timings, cooldown.
- **`Config.Heat`** — heat per cycle/spend, decay, ping threshold /
  cooldown / radius / jitter.
- **`Config.HopCap`** — how much the paper remembers (default 6).
- **`Config.Sinks` / `Config.Sink`** — vendor locations, goods baskets,
  detection curve.
- **`Config.Fences` / `Config.Fence`** — venues, rate, rejection curve
  (circulation + batch size), daily quota, police-call chance.
- **`Config.Pen`** — cooldown, minigame difficulty.
- **`Config.Police`** — terminal coords (keep in sync with
  palm6_evidence's `LockerCoords`), leads per run/press, interrogate and
  raid radii, case title/key.

## Perf

48-slot safe. No unconditional per-frame client loops: sinks/fences/press
are ox_target zones (event-driven) or 16m-gated marker points; printer
zones exist only for the owner. The server runs a single 60 s heat sweep;
provenance writes ride the ox_inventory hook and are deferred to a worker
thread so they never delay an inventory move.

## GTA VI notes (Tier 3)

District centres, sink/fence coords, ped models, the anchor-prop model
names, the press prop, and blip sprites are Los Santos values — re-author
against the VI map (`docs/GTA6-TIER3-RETUNE.md`). The serial registry,
provenance chain, heat model, batch-decay curves, and the entire evidence
cascade are Tier 1 and carry unchanged.

## Deferred to v2

- Wad face-value denominations (config exists per batch; UI assumes one).
- Printer upgrades (better plates = slower wear-on-circulation).
- A `/counterfeit heatmap` MDT view for police command.
- Cross-batch link analysis (same press, different batches) at the
  terminal.
- Character-switch resync of printer zones without rejoining (the zone
  list currently syncs on resource start and placement).
