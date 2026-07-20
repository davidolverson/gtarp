# palm6_protection

Turf finally pays. A protection racket that makes controlling ground worth
something.

`palm6_turf` ships zone control as **pure reputation** — its own README defers
"material reward for holding turf" to v2. This *is* that v2 layer. A gang that
controls a turf zone can lean on the businesses inside it for protection money;
lose the turf, lose the income. Payments come out **dirty** (`black_money`) —
it's a shakedown, not a paycheck — so the proceeds feed `palm6_laundering` the
same way `palm6_numbers` winnings do.

## Commands

- **`/shakedown`** — at a business whose turf zone your gang controls, collect
  protection money (paid in `black_money`). Each business is "paid up" for
  ~30 min after any collection. Small chance the business calls the cops. With
  `Config.ExtortOwned` on (dark by default), this ALSO works at a **player-owned
  `palm6_business` storefront** sitting on your controlled turf — draining its
  **real pooled account** (bounded, never minted) instead of minting; see
  "Extorting player-owned businesses" below.
- **`/rackets`** — read-only: how many business blocks your crew controls and
  how many are ready to collect vs still paid up.

## What makes it 1-of-1 (and not a dupe)

- **Nothing does gang/business extortion or passive turf income.** Dup-gated
  against the real deployed recipe (`qbx_management` is boss-menu only — no
  income/extortion) and every `palm6_*` resource.
- **Fills palm6_turf's own documented v2 gap** rather than re-treading a
  pipeline — it's the first thing that makes turf ownership economically real.
- **Composes via the established house patterns, no upstream change.** Turf
  ownership is read live with the soft `SELECT owner_gang FROM palm6_turf WHERE
  zone_id=?` cross-read (same as `palm6_flashdrop`/`clout`/`pumpcoin`), and gang
  membership via qbx_core's first-class `PlayerData.gang`. `palm6_turf` is a
  soft dependency — if it isn't running, no zone has an owner and nothing is
  collectable.
- Pays in `black_money` (never `counterfeit_cash` — that's `palm6_counterfeit`
  — and never the unregistered `markedbills`).

## Anti-abuse (all server-side)

- Gang (`PlayerData.gang`), zone ownership (live turf read), and position (off
  the caller's ped) are all read server-side; the client sends nothing but the
  command. You can only collect a business whose zone **your** gang controls.
  (As with every FiveM proximity check, the ped position is client-synced under
  OneSync — a position spoof could fake standing at a business, but the payout is
  still gated on live turf ownership + the per-business cooldown.)
- Per-business **collect lock** + a re-checked, gang-agnostic per-business
  cooldown (`is there a collection newer than the interval`) mean two crew
  members can't double-collect one business in a cycle, even racing the same
  tick.
- Per-character command cooldown set **before** any DB yield (the
  `palm6_chopshop` rl() idiom). Chat commands aren't net events, so eventguard
  doesn't cover them — the cooldown + interval + lock are the guard.
- A reported shakedown fires a **native police alert** (`police:server:
  policeAlert`) and opens/append a **`palm6_evidence` v2** extortion case (via
  the frozen `EnsureCase`/`AppendEntry`/`LinkSuspect` exports — never its
  tables directly), bucketed to a 5-minute window.

## Data

`palm6_protection_collections` (`sql/0035_protection.sql`) — one row per
shakedown: gang, business_id, zone_id, citizenid, amount, flagged,
evidence_case_id. Export `GetSummary()` → `{ businesses, shakedowns,
totalCollected, flagged }`.

## Extorting player-owned businesses (`Config.ExtortOwned`, DARK by default)

The hardcoded `Config.Businesses` above **mint** dirty cash. This optional layer
lets the same `/shakedown` lean on a **player-owned `palm6_business` storefront**
in a zone your gang controls, taking the money out of that business's **real
pooled account** instead — the site's "every dollar from another citizen"
integrity carried into the racket.

- **Bounded, never wipes:** a shakedown takes
  `min(random(PayoutMin..PayoutMax), floor(balance * OwnedCutPct))` — up to 15% of
  the register, so a big business pays more and a near-empty one yields nothing
  (≥ 85% always remains). Still paid to the collector as `black_money`.
- **Turf-gated, passive:** the storefront must sit in a controlled zone (nearest
  `Config.Zones` center within `OwnedZoneRadius`; off-turf shops aren't shakeable).
  Works whether or not the owner is online — the owner is notified if online and
  the business ledger always records an `extortion` row.
- **No mint, no overdraw:** the drain goes through three invoking-resource-guarded
  `palm6_business` exports — `BusinessAtCoords` (find the shop), `Extort` (atomic
  guarded debit + ledger + owner notify), `RefundExtortion` (compensating credit
  if the cash hand-off fails after the debit). Cooldown/evidence reuse the same
  `palm6_protection_collections` table, namespaced `owned:<id>` (no new migration).
- Distinct from `palm6_business`'s own **register robbery** (`/robstore`, any
  player, clean-to-bank): this is organised, turf-based, and dirty.

While `Config.ExtortOwned = false`, `/shakedown` and `/rackets` are byte-identical
to the hardcoded-only behavior. See
`docs/superpowers/specs/2026-07-20-palm6-protection-extort-owned-design.md`.

## Tuning (`shared/config.lua`)

`Config.Businesses` (id → turf zone → coords; Tier-3 placeholders reusing
turf's validated zone points — retune to real storefronts in-game),
`PayoutMin`/`PayoutMax`, `CollectIntervalSec`, `ReportChance`, `CooldownSec`.
Owned-business layer: `Config.ExtortOwned`, `Config.Zones` (mirror of
`palm6_turf`), `OwnedZoneRadius`, `OwnedRadius`, `OwnedCutPct`.
