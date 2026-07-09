# gtarp_protection

Turf finally pays. A protection racket that makes controlling ground worth
something.

`gtarp_turf` ships zone control as **pure reputation** — its own README defers
"material reward for holding turf" to v2. This *is* that v2 layer. A gang that
controls a turf zone can lean on the businesses inside it for protection money;
lose the turf, lose the income. Payments come out **dirty** (`black_money`) —
it's a shakedown, not a paycheck — so the proceeds feed `gtarp_laundering` the
same way `gtarp_numbers` winnings do.

## Commands

- **`/shakedown`** — at a business whose turf zone your gang controls, collect
  protection money (paid in `black_money`). Each business is "paid up" for
  ~30 min after any collection. Small chance the business calls the cops.
- **`/rackets`** — read-only: how many business blocks your crew controls and
  how many are ready to collect vs still paid up.

## What makes it 1-of-1 (and not a dupe)

- **Nothing does gang/business extortion or passive turf income.** Dup-gated
  against the real deployed recipe (`qbx_management` is boss-menu only — no
  income/extortion) and every `gtarp_*` resource.
- **Fills gtarp_turf's own documented v2 gap** rather than re-treading a
  pipeline — it's the first thing that makes turf ownership economically real.
- **Composes via the established house patterns, no upstream change.** Turf
  ownership is read live with the soft `SELECT owner_gang FROM gtarp_turf WHERE
  zone_id=?` cross-read (same as `gtarp_flashdrop`/`clout`/`pumpcoin`), and gang
  membership via qbx_core's first-class `PlayerData.gang`. `gtarp_turf` is a
  soft dependency — if it isn't running, no zone has an owner and nothing is
  collectable.
- Pays in `black_money` (never `counterfeit_cash` — that's `gtarp_counterfeit`
  — and never the unregistered `markedbills`).

## Anti-abuse (all server-side)

- Gang (`PlayerData.gang`), zone ownership (live turf read), and position (off
  the caller's ped) are all read server-side; the client sends nothing but the
  command. You can only collect a business whose zone **your** gang controls.
- Per-business **collect lock** + a re-checked, gang-agnostic per-business
  cooldown (`is there a collection newer than the interval`) mean two crew
  members can't double-collect one business in a cycle, even racing the same
  tick.
- Per-character command cooldown set **before** any DB yield (the
  `gtarp_chopshop` rl() idiom). Chat commands aren't net events, so eventguard
  doesn't cover them — the cooldown + interval + lock are the guard.
- A reported shakedown fires a **native police alert** (`police:server:
  policeAlert`) and opens/append a **`gtarp_evidence` v2** extortion case (via
  the frozen `EnsureCase`/`AppendEntry`/`LinkSuspect` exports — never its
  tables directly), bucketed to a 5-minute window.

## Data

`gtarp_protection_collections` (`sql/0035_protection.sql`) — one row per
shakedown: gang, business_id, zone_id, citizenid, amount, flagged,
evidence_case_id. Export `GetSummary()` → `{ businesses, shakedowns,
totalCollected, flagged }`.

## Tuning (`shared/config.lua`)

`Config.Businesses` (id → turf zone → coords; Tier-3 placeholders reusing
turf's validated zone points — retune to real storefronts in-game),
`PayoutMin`/`PayoutMax`, `CollectIntervalSec`, `ReportChance`, `CooldownSec`.
