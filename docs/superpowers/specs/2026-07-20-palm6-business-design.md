# palm6_business — Player-Owned Businesses (Phase 0 design)

Date: 2026-07-20
Status: APPROVED (David: "Approve + add capped NPC income"). Ships DARK.
Part of: PALM6 GTA RP / FiveM server. Sibling of `palm6_gangs` (org pattern),
`palm6_drugs` (faucet-cap pattern), `palm6_fightclub` (dark-ship pattern).

## 1. Why this exists

The marketing site (`/beta`, `/life`, homepage Systems, `/store`) repeatedly
promises **player-owned businesses** that the server does NOT yet have:

- "Own a business — legit front (shop, garage, service); employ citizens, meet payroll" (`/life`)
- "Business Ledger — track revenue, expenses & payroll" (homepage Systems)
- "OWN THE ROOM — turn a venue into an institution" (`/beta`, Nightlife & Power)
- "A business can outlive a crew" (`/beta`, The City Record)
- Careers: Restaurant Owner, Nightlife Promoter, Dealership Owner (homepage BandEnter)
- Store SKU **Business Starter Pack $29.99** — storefront skins, custom business
  nameplate, Discord business-registry badge (the cosmetics upsell a system that
  must exist underneath)

`qbx_management` (base recipe) provides society bank accounts + boss menus for the
whitelisted *jobs* (police/EMS/mechanic). It does NOT provide **player-ownable
businesses** with a registry, employees, payroll, revenue, and a ledger as a
civilian career. That is this resource's scope — built as a NEW custom-layer
resource on the proven `palm6_gangs` player-run-org pattern.

## 2. Core model & the money-safety spine

A business is a **pooled real-money account** (exactly like a gang cash vault),
NOT a money printer. The site's flagship economic claim is *"every dollar comes
from another citizen — money is never spawned."* The design honors that:

Money enters a business account through only these paths:
1. **Owner deposit** — owner personal bank → business (redistribution, zero mint)
2. **Customer charge** — a player pays the business (player → business, zero mint)
3. **NPC walk-in income** — the ONE faucet (see §6), tightly capped and gated on a
   clean-money cost basis so net minting is bounded.

Money leaves through:
1. **Owner withdraw** — business → owner personal bank
2. **Payroll / wages** — business → employees (redistribution)
3. **Stock purchase** — owner personal bank → supply units (a clean-money SINK)

### Money invariants (the audit will check these)
- **Registration fee** charged from owner BANK; business row created ONLY if the
  charge confirms. Clean-money SINK.
- **Deposit**: `ChargeBank(owner)` → business balance. Charge-before-credit;
  business is credited nothing the player did not lose.
- **Withdraw**: atomic guarded debit
  `UPDATE ... SET account_balance = account_balance - ? WHERE id = ? AND account_balance >= ?`
  (check affectedRows) THEN `CreditBankByCitizenId(owner)`. On credit failure,
  refund the account (add the amount back). Debit-account-before-credit-player.
- **Charge (customer)**: `ChargeBank(payer)` (payer confirms via prompt) → credit
  business balance. Zero mint. Payer must actually hold + lose the money.
- **Stock purchase**: `ChargeBank(owner)` → `supply_units += n`. SINK (the money
  leaves the economy; supply is a consumable, not currency).
- **NPC serve** (§6): consumes 1 supply unit + credits business balance by
  `ServePayout`. Net city mint per serve = `ServePayout` (the supply cost was a
  prior sink). Bounded by: cost basis (must buy supply first), per-business daily
  cap, per-employee cooldown, a clocked-in worker requirement.
- **Payroll**: per-employee `business → employee` credit, each capped at the live
  account balance, atomic. Never pays more than the account holds.
- All amounts sanitized to a finite positive integer BEFORE any guard
  (`n ~= n` rejects NaN, `math.huge` rejects Inf) — the lottery/drugs NaN lesson.
- Every money move writes a `palm6_business_ledger` row (action, amount,
  balance_after, memo) — this IS the "Business Ledger" promise.

## 3. Data model (dbmigrate 0068, all idempotent CREATE IF NOT EXISTS)

### `palm6_businesses`
| col | type | notes |
|---|---|---|
| id | INT UNSIGNED PK AUTO_INCREMENT | |
| owner_cid | VARCHAR(64) NOT NULL | current owner citizenid |
| name | VARCHAR(48) NOT NULL | UNIQUE, sanitized |
| biz_type | VARCHAR(24) NOT NULL | key into Config.Types |
| account_balance | BIGINT UNSIGNED NOT NULL DEFAULT 0 | pooled real money |
| supply_units | INT UNSIGNED NOT NULL DEFAULT 0 | NPC-serve stock (cost basis) |
| day_key | VARCHAR(10) NOT NULL DEFAULT '' | UTC yyyy-mm-dd for the NPC cap |
| day_npc_income | INT UNSIGNED NOT NULL DEFAULT 0 | NPC income minted today |
| created_at | TIMESTAMP DEFAULT CURRENT_TIMESTAMP | |
| updated_at | TIMESTAMP ... ON UPDATE | |
| UNIQUE uniq_palm6_business_name (name) | | |
| INDEX idx_palm6_business_owner (owner_cid) | | |

### `palm6_business_members`
| col | type | notes |
|---|---|---|
| citizenid | VARCHAR(64) PK | one job per character (MVP) |
| business_id | INT UNSIGNED NOT NULL | |
| role | TINYINT UNSIGNED NOT NULL DEFAULT 1 | 1=employee, 3=owner |
| wage | INT UNSIGNED NOT NULL DEFAULT 0 | per-payroll-run wage |
| clocked_in | TINYINT(1) NOT NULL DEFAULT 0 | |
| last_serve_at | BIGINT UNSIGNED NOT NULL DEFAULT 0 | per-employee serve cooldown |
| name | VARCHAR(64) NULL | roster display |
| hired_at | TIMESTAMP DEFAULT CURRENT_TIMESTAMP | |
| INDEX idx_palm6_business_members_biz (business_id) | | |

### `palm6_business_ledger`
| col | type | notes |
|---|---|---|
| id | INT UNSIGNED PK AUTO_INCREMENT | |
| business_id | INT UNSIGNED NOT NULL | |
| actor_cid | VARCHAR(64) NOT NULL | who triggered it ('__NPC__' for walk-ins) |
| action | VARCHAR(16) NOT NULL | register/deposit/withdraw/charge/npc_sale/stock/payroll |
| amount | BIGINT NOT NULL | signed relative to the account |
| balance_after | BIGINT UNSIGNED NOT NULL | |
| memo | VARCHAR(128) NULL | |
| created_at | TIMESTAMP DEFAULT CURRENT_TIMESTAMP | |
| INDEX idx_palm6_business_ledger_biz (business_id, created_at) | | |

Persistence: businesses live in the DB → survive restarts ("a business can outlive
a crew"). No in-memory-only money/escrow state (the restart-integrity lesson).

## 4. Server API (exports, server-only)
- `exports.palm6_business:GetBusinessOf(citizenid)` → summary or nil
- `exports.palm6_business:Charge(businessId, payerCid, amount, memo)` → bool
  (the generic revenue seam other resources / a POS can call; always player→business)
- `exports.palm6_business:GetAccountBalance(businessId)` → int
These let `palm6_protection` (Phase 1) extort a real player-owned business and let
future POS/vending call into business revenue without re-implementing money rules.

## 5. Net events (all registered in palm6_eventguard with a per-event budget)
`register`, `openMenu`, `deposit`, `withdraw`, `buyStock`, `serve`, `clock`,
`hireNearest`, `acceptHire`, `fire`, `setWage`, `runPayroll`, `chargeNearest`,
`acceptCharge`, `viewLedger`, `rename`, `resign`. Server re-validates role,
ownership, affordability, and radius on EVERY event; the client supplies intent
only (mirrors the gang invite model: the server picks the nearest eligible target
from real ped positions — the client never names who to hire/charge).

## 6. NPC walk-in income — the ONE faucet, and how it is bounded

Goal (David): businesses feel "alive" with walk-in customers, not just dependent on
other online players. Risk: passive/NPC income mints money. Controls (defense in
depth — ALL must pass for a serve to pay):

1. **Cost basis (primary limiter):** NPC income requires `supply_units > 0`, and
   supply is bought with the owner's clean bank money (`StockUnitCost` each = a
   SINK). Each serve consumes 1 unit. You cannot earn without first spending. Net
   margin per unit = `ServePayout - StockUnitCost` and is bounded and small.
2. **Active-work gate:** a serve requires an employee/owner who is **clocked in**
   and performs the serve action (an ox_lib skill-check / progress moment) — no
   idle/AFK minting.
3. **Per-employee cooldown:** `ServeCooldownSec` between serves per worker
   (GetGameTimer ms), persisted in `last_serve_at`.
4. **Per-business daily cap:** `DailyNpcIncome` cap on `day_npc_income` (reset when
   `day_key` rolls, UTC). A full day of serving cannot exceed the cap.
5. Sanitize/clamp all amounts; fail-closed on any nil (worker/business/supply).

Net effect: NPC income is a bounded **margin business** that requires active play
and up-front clean-money spend — structurally the same faucet control as
`palm6_drugs` (buy precursors → active sell → daily-capped dirty income), here in
clean money and even more conservative (hard daily cap + cost basis + cooldown).

Config defaults (tunable): `StockUnitCost=120`, `ServePayout=300`,
`ServeCooldownSec=45`, `DailyNpcIncome=15000`, `MaxSupplyUnits=500`.

## 7. Client (ox_lib menu via bridge, no world coords — MVP is abstract)
- Command `/business` (alias `/biz`) opens the menu. `bridge/cl_game.lua` wraps
  ox_lib (`Game.OpenMenu/InputDialog/Confirm/ShowReport/Notify` — copied from
  `palm6_gangs`). `client/main.lua` drives flow, calls `Game.*` only.
- **No member** → "Register a business" (type picker + name input).
- **Owner** → Account (balance, deposit, withdraw), Employees (hire nearest / fire
  / set wage / run payroll), Operations (buy stock, serve a customer, charge a
  nearby customer), Ledger (view), Rename, (Resign/close deferred to Phase 1).
- **Employee** → Clock in/out, Serve a customer, Charge a nearby customer, View
  ledger (read-only).
- Physical storefront location (owner-set via a `/coords`-style capture + a blip)
  is DEFERRED to Phase 1 — MVP operates from the menu so it is buildable and
  testable now without blocking on in-game coord capture.

## 8. Config & dark-ship
- `Config.Enabled = false` — master gate. Every command + net event early-returns
  when disabled (the racing/fightclub dark-ship idiom). Ships prod-inert; goes live
  only when David flips it true + redeploys, batched with a feel-test.
- `Config.Types` — business catalog: `restaurant`, `bar` (venue/nightlife),
  `garage` (service), `retail` (front), `dealership` (front). Label + optional
  flavor. Extensible.
- `Config.RegistrationCost = 75000` (clean-money sink, on the gang-creation scale).
- `Config.MaxEmployees = 10`, `Config.MaxPerAction = 1000000` (deposit/withdraw
  clamp), name 3-48 chars sanitized, shared profanity/impersonation blocklist
  (reuse the gang blocklist values).
- One character = one business membership (MVP). Owner cannot also be an employee
  elsewhere.

## 9. Integration seams (DEFERRED to Phase 1, designed so they drop in)
- `palm6_protection`: extort a player-owned business via `exports.palm6_business`
  (the account is a real target). 
- Store SKU cosmetics: business nameplate + storefront skin = cosmetic flags on the
  business row; Discord business-registry badge = a `palm6_discord`/`cityfeed` hook
  on register. All additive, no money impact.
- Website `/business` directory page (mirror of `/gangs`) reading the businesses
  table — a web-repo follow-up, not this resource.

## 10. Testing gates (FiveM — no pytest)
- Every `.lua` block-balance clean (comment-stripped node balance check;
  `npx luaparse` hangs on this box).
- Boots clean behind `Config.Enabled=false` (resource loads, registers nothing
  player-facing, 0 script error → FiveM keeps it loaded = pass).
- dbmigrate 0068 statements idempotent (CREATE IF NOT EXISTS) → re-run safe.
- Money paths desk-checked against §2 invariants; a post-build ultracode faucet
  audit (charge-before-credit, NPC-income mint bound, atomic withdraw, NaN
  sanitize) before enable.
- In-game feel-test (David) after enable: register → deposit → hire → buy stock →
  serve (NPC income within cap) → charge a player → run payroll → withdraw →
  ledger reflects every move.

## 11. Rollout
Build DARK on branch `feat/defjam-fightclub-phase0` (current working branch),
commit, NO deploy. Enable batched with David's next feel-test deploy (flip
`Config.Enabled=true`, ensure in custom.cfg, dbmigrate 0068 lands on restart).
Revert = flip false.

## 12. Durability & crash-recovery (post-build ultracode audit hardening, 2026-07-20)
A 7-dimension adversarial audit (wf_67b9a43f, 12 candidates → 9 confirmed) drove
these hardenings, applied before enable:
- **Recoverable account→bank payouts (withdraw/payroll).** The account debit is
  immediately durable but the qbx bank credit is in-memory until the next
  player-save, so a hard crash in that window could strand money — the archetype
  the repo's 2026-07-16 payout-recoverability sweep fixed for every other
  bank-payout resource. Added the same idiom, adapted to the account→bank
  direction: `debitAccountWithPending` sets a single per-business pending marker
  (`pending_cid`/`pending_amount`/`pending_at`, dbmigrate 0068) atomically WITH
  the debit (guarded `AND pending_amount = 0` so it can't overwrite an unsettled
  one); `settlePayout` is **claim-before-credit** (atomically clear the marker,
  then credit — a crash after the claim can never double-pay); a boot
  `reconcilePending()` re-drives any `pending_amount > 0` on start. Loss is bounded
  to the deflationary claim→credit window (never a mint, never a double-pay),
  matching the sibling resources.
- **Accepted in-memory window (deposit/charge/buyStock).** The player-side debit
  is qbx in-memory while our account credit is durable; a hard crash between them
  could keep the account gain without the player's debit. This is the SAME window
  every `ChargeBank`→durable-write path in the codebase carries (lottery,
  flashdrop, …); a graceful deploy-restart saves players first, so it is safe.
  Documented and accepted codebase-wide, not special-cased.
- **Server-side least-privilege:** `pushMenu` attaches the roster (coworker
  citizenids/wages) and account balance ONLY for the owner — the server, not the
  client render gate, decides what a non-owner receives.
- **Roster-cap race:** hire-accept is an atomic conditional insert (COUNT inside
  the statement, derived-table wrapped) — no check-then-insert TOCTOU.
- **Dark-ship completeness:** `pushMenu` and the read-only exports
  `GetBusinessOf`/`GetAccountBalance` early-return when disabled, matching every
  op and `Charge`.
- **Dead code:** removed the unproduced `palm6_business:openMenu` net event + its
  eventguard budget (the command opens the menu server-side; Phase 1's ped/target
  will re-add a produced event).
- **Ledger `balance_after`** is a best-effort read-back snapshot (cosmetic under
  simultaneous same-business writes); `account_balance` itself is always exact.
