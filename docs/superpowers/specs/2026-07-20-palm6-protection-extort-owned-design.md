# palm6_protection — extort player-owned businesses (Phase 1 seam)

_2026-07-20. Ships DARK. Wires the existing `palm6_protection` racket to
`palm6_business` so a gang controlling a turf zone can shake down a **player-owned
storefront** in that zone, draining its **real pooled account** instead of
minting._

## Goal
Today `palm6_protection` shakes down a hardcoded `Config.Businesses` list and
**mints** `black_money`. This adds a parallel path: an owned `palm6_business`
storefront sitting on a gang's controlled turf can be shaken down, and the payout
comes out of that business's **real `account_balance`** (bounded, never minted,
never overdrawn). Fulfils the seam the `GetStorefront` export comment already
names ("a future palm6_protection shake-down the shop") and the memory roadmap
item "palm6_protection extortion of owned businesses."

## Gate (dark-ship)
New `Config.ExtortOwned = false` in `palm6_protection/shared/config.lua`. When
`false`, the owned-business resolver short-circuits to `nil` on its first line, so
`/shakedown` and `/rackets` behave **byte-identically to today** (only the
hardcoded list, still minted). The hardcoded path is untouched regardless of the
flag. This is the established dark-ship pattern (racing / fightclub / business
phases).

Owned extortion has targets only once `palm6_business` storefronts exist, i.e.
effectively also requires `palm6_business Config.Phase1Enabled` — the business
lookup export is `phase1()`-gated. Documented dependency, not a code coupling.

## Money model (David's calls)
- **% cap, never wipes:** `amount = min(random(PayoutMin..PayoutMax),
  floor(balance * Config.OwnedCutPct))` with `OwnedCutPct = 0.15`. A shakedown
  stings but leaves ≥85% of the register; big businesses pay more, a near-empty
  one yields nothing.
- **Passive turf-tax:** works whether or not the owner is online (it taxes the
  books). The owner gets an in-game notification **if online** and the shakedown
  is always written to the business ledger (`extortion`, negative amount) — the
  durable record either way.

## Architecture — responsibility split
`palm6_protection` stays the gatekeeper (gang, turf ownership, proximity,
cooldown, report/evidence). Three tight new **`palm6_business` exports**, each
guarded by `GetInvokingResource() == 'palm6_protection'` (defense-in-depth; only
the racket may touch a business this way):

1. **`BusinessAtCoords(x, y, z, radius)`** → `{ id, name, biz_type, balance,
   ownerCid, x, y, z }` for the nearest **placed** storefront within `radius`, or
   `nil`. `phase1()`-gated + invoking-guarded (also closes an owned-business
   location/identity enumeration oracle, per the 2fe2331 storefront lesson).
2. **`Extort(businessId, amount, collectorCid, memo)`** → the amount actually
   taken (0 if the account can't cover it, business closed, or system dark).
   `enabled()`-gated + invoking-guarded. Uses the existing atomic guarded
   `debitAccount` (`WHERE account_balance >= amount` — **never overdraws, never
   mints**), writes an `extortion` ledger row, and notifies the owner if online.
   All-or-nothing at the protection-capped amount (no partial debit).
3. **`RefundExtortion(businessId, amount, memo)`** → bool. Compensating credit via
   the existing `creditAccount`, for the rare case the item hand-off fails after
   the debit. `enabled()`-gated + invoking-guarded.

No new `palm6_business` config, no `palm6_business` migration, no change to any
Phase-0 hot path. The business exports are capabilities that only the (dark-gated)
racket ever invokes.

## Turf-zone resolution (all inside palm6_protection)
Turf zones are sparse 3 m interaction points; there is no point-in-polygon and no
`GetZones` export. `palm6_protection` gets a **local mirror** of the six turf zone
centers (`Config.Zones`, documented "keep in sync with palm6_turf") plus
`Config.OwnedZoneRadius = 200.0`. A storefront belongs to the nearest zone whose
center is within that radius; if none, the shop is **off-turf and not shakeable**
(resolver returns nil → "no business here to lean on"). Ownership is then the
existing live `Bridge.GetZoneOwner(zoneId)` DB read. This adds no dependency on
`palm6_turf` beyond the soft cross-read it already uses.

## Cooldown / evidence reuse (no migration)
Reuse `palm6_protection_collections` (`business_id VARCHAR(50)`), namespacing owned
businesses as `owned:<id>` so their per-business cooldown never collides with a
hardcoded string id. Same 30-min gang-agnostic interval, same collect-lock, same
`ReportChance` → police alert + `palm6_evidence` case (label = the business name).

## Money-safety ordering (crash analysis)
Mirror the racket's "record the durable cooldown claim, then pay, void on
pay-failure" ordering:
1. Insert the collection row (durable cooldown claim).
2. `Extort` — atomic guarded debit (durable). Returns 0 if the account can't
   cover the capped amount (e.g. a concurrent withdraw emptied it) → delete the
   claim, "register's empty," no item minted.
3. `GiveItem(black_money, taken)`. On failure → `RefundExtortion` (credit back) +
   delete the claim.

Two narrow uncovered windows remain, both **deflationary only** (destroy money,
never mint/duplicate/overdraw), both accepted and documented rather than special-
cased — symmetric to, and safer than, the in-memory `ChargeBank→durable-write`
window the `palm6_business` README already documents:

1. A hard **process kill between the debit committing and `GiveItem`**: the
   business is debited, no `black_money` is minted, no refund runs. Cannot be
   triggered on demand by a player.
2. The **owner closes the business in the debit→`GiveItem` gap AND the item
   hand-off then fails** (audit `wf_8abe27e6`, low). `opClose` captures the
   already-reduced balance (it excludes the in-flight drain) and deletes the row,
   so `RefundExtortion`'s credit hits 0 rows and the drained amount is destroyed.
   `RefundExtortion` returns `false` and `cmdShakedown` **logs** the destroyed
   amount for economy observability (it does not silently swallow it).

Why not the `pending`-marker "fix" (make `opClose`'s `pending_amount = 0` guard
refuse mid-shakedown): the single pending marker is re-driven as a **bank credit**
by `reconcilePending` on boot. An item-payout marker would get re-credited to the
collector's *bank* on the next restart — a real **mint/dupe**, strictly worse than
the rare deflation. So the extortion debit deliberately uses the plain guarded
`debitAccount` (which does still guard `pending_amount = 0` so it can't interleave
with a withdraw/payroll settle), and the close race is an accepted deflation.

**Self-shakedown guard** (audit `wf_8abe27e6`, medium): `Extort` refuses when the
collector is a MEMBER (owner or employee) of the target business
(`getMembership(collectorCid).business_id == businessId`), mirroring `opRob` —
otherwise a non-owner employee in the controlling gang could drain the owner's
account into their own dirty pocket, bypassing the owner-only withdraw.

## Config added (palm6_protection/shared/config.lua)
`Config.ExtortOwned = false`, `Config.Zones` (6 centers mirror), `Config.OwnedZoneRadius = 200.0`,
`Config.OwnedRadius = 14.0` (proximity to the storefront), `Config.OwnedCutPct = 0.15`.

## Dark-off equivalence (the invariant to verify)
With `Config.ExtortOwned = false`: `ownedBusinessAt` returns nil on line 1, so
`/shakedown` control flow is exactly today's; hardcoded businesses mint exactly as
today; `/rackets` counts hardcoded blocks only (owned shops are never added to
`/rackets` in v1); the three `palm6_business` exports exist but nothing calls them.

## Test plan (no FXServer here — block-balance + logic/audit only)
- Lua block/bracket balance on all changed files (scratchpad luabal.js).
- Ultracode audit (money-safety / authz / dark-equivalence / crash dims ×
  adversarial verify).
- In-game feel-test (David, on enable): place a storefront in a turf zone → a
  rival gang that controls the zone runs `/shakedown` at it → its account drops
  (≤15%, never below the floor) → owner notified if online → ledger shows
  `extortion` → 30-min cooldown → off-turf shop is not shakeable → empty register
  yields nothing → flip `ExtortOwned=false` restores identical behavior.
