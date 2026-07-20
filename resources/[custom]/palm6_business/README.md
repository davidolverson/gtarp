# palm6_business — player-owned businesses

The civilian **business-ownership** layer that neither Qbox nor `qbx_management`
ships. `qbx_management` gives society bank accounts + boss menus for the
whitelisted *jobs* (police/EMS/mechanic); this gives a player a business they
**register and run** as a career: a registry, a pooled account, employees,
payroll, walk-in revenue, and a full ledger.

Delivers the site's repeated promises: "Own a business — employ citizens, meet
payroll", "Business Ledger (revenue/expenses/payroll)", "OWN THE ROOM — turn a
venue into an institution", "a business can outlive a crew", and the
Restaurant/Nightlife/Dealership owner careers.

Built on the `palm6_gangs` player-run-org pattern (own tables + a framework
bridge + an ox_lib menu). Design spec:
`docs/superpowers/specs/2026-07-20-palm6-business-design.md`.

## Ships DARK
`Config.Enabled = false` (shared/config.lua). Prod-inert: `/business` refuses,
every net event early-returns, nothing player-facing registers. Flip `true` +
redeploy to go live (batched with a feel-test). Revert = flip `false`.

## Money safety (the whole point)
A business account is **pooled real money, never minted** — the site's core
economic claim. Money enters ONLY via:
- owner **deposit** (owner bank → business, `ChargeBank` charge-before-credit)
- customer **charge** (player bank → business, the payer confirms)
- **NPC walk-in income** — the ONE faucet, bounded four ways (below)

Money leaves via **withdraw** / **payroll** (business → player, atomic guarded
debit that can't overdraw) and **stock purchase** (owner bank → supply, a SINK).
Every move writes a `palm6_business_ledger` row. All client amounts are
NaN/Inf-sanitized before any guard.

### The NPC-income faucet, bounded
1. **Cost basis** — NPC income needs `supply_units > 0`; supply is bought with
   the owner's clean bank money (`StockUnitCost` each = a sink). Margin/unit =
   `ServePayout - StockUnitCost`, bounded and small. You can't earn without first
   spending.
2. **Active work** — a serve needs a **clocked-in** worker doing a skill-check;
   no AFK minting.
3. **Per-worker cooldown** — `ServeCooldownSec` between serves.
4. **Per-business daily cap** — `DailyNpcIncome` (UTC `day_key` reset), enforced
   atomically in the serve UPDATE.

## Per-type mechanics (ships DARK behind `Config.PerTypeMechanics`)
Each business type gets its own **economic identity + themed serve** instead of
all five sharing the Phase-0 numbers — resolved per type by `serviceOf(bizType)`:
- **Restaurant / Retail** — fast, cheap, high-volume (serve a plate / ring up a
  sale; easy skill-check).
- **Bar** — medium rounds.
- **Garage** — slow, high-value repairs (harder skill-check, pricier parts).
- **Dealership** — slow, big-ticket sales (few, large, long cooldown).

Each type sets its own `payout / stockCost / cooldown / dailyCap / maxSupply` +
labels (`verb / serveNoun / supplyNoun`) + `skill` spec in `Config.Types[].service`.
**Same four faucet bounds, different numbers** — no new faucet, no new exploit
surface. While the gate is off, `serviceOf` returns the GLOBAL `Config.*` values
and the Phase-0 wording, so the **live economy is byte-for-byte unchanged**. Flip
`Config.PerTypeMechanics = true` + redeploy after a per-type feel-test.

## Player commands
- `/business` (alias `/biz`) — opens the menu. Non-members can register; owners
  get Account / Employees / Operations / Ledger / Rename; employees get Clock
  in/out / Serve / Charge / Ledger / Resign.

## Manager delegate role (ships DARK behind `Config.ManagerRole`)
An owner can promote an employee to **Manager** (role 2, the reserved slot) to run
the day-to-day without handing over the keys. Authority matrix:

| Action | Employee | **Manager** | Owner |
|---|:-:|:-:|:-:|
| serve / charge / clock / ledger / resign | ✅ | ✅ | ✅ |
| hire · fire (ranks below only) · run payroll · buy supply | — | ✅ | ✅ |
| **set wage** · deposit · **withdraw** · rename · storefront · promote/demote | — | — | ✅ |

- **`setWage` is deliberately owner-only** — that closes the one account-drain a
  delegate could otherwise pull (inflate a wage, then run payroll). A manager runs
  payroll only at wages the owner already set.
- A manager can fire/act on ranks **strictly below** them (employees), never a peer
  manager or the owner — enforced in the SQL (`role < actorRole`), not just the UI.
- `Config.MaxManagers` caps appointments (enforced atomically inside the promote
  UPDATE). Owner promotes/demotes; the roster shows each member's role.
- **Gating** — while `Config.ManagerRole = false`, promote/demote refuse and every
  management op falls back to **owner-only**, so the live behaviour is unchanged (no
  manager has ever been assigned). Flip `true` + redeploy after a delegate feel-test.

## Phase 1 — physical storefronts (ships DARK behind `Config.Phase1Enabled`)
Turns a business from a menu-anywhere into a **place**.
- **Owner marks a location** from the menu (*Storefront → Place / Move here*). The
  server captures the owner's **real ped coords + heading** — never a
  client-supplied coordinate. A public **map blip** + a **walk-up interaction
  point** spawn there for everyone.
- **Blip cosmetics** — the owner picks an icon + colour from
  `Config.Storefront.Sprites` / `.Colors`; the server rejects anything outside
  those allowlists.
- **Proximity gate** — once a storefront is placed, day-to-day management (account,
  employees, operations, clock, ledger) and **NPC serving** require being **within
  `Config.Storefront.Radius`** of it. *Registering* and *placing / moving /
  removing* the storefront are always reachable, so **an owner can never lock
  themselves out.**
- **Walk-up** — staff opening the target get the management menu (still gated by
  proximity); a passerby gets a read-only info card (name / type / owner) — no
  roster or balance leak.
- **Gating** — requires **both** `Config.Enabled` **and** `Config.Phase1Enabled`.
  With Phase 1 off, a business with no storefront row behaves exactly as Phase 0.
- **No money** moves anywhere in the storefront layer — it is presentation +
  location only; the account/faucet invariants are untouched.

`Config.Phase1Enabled = false` by default — flip `true` + redeploy after the
Phase-1 feel-test.

## Ownership lifecycle — transfer / close (ships DARK behind `Config.OwnershipLifecycle`)
Closes the documented gap where an owner was stuck forever (`opResign` refuses an
owner). Both owner-only.
- **Transfer** (from an employee's action menu) — hand the business to a roster
  member: they become owner, the old owner drops to employee. The target is
  **promoted first under an affected-row guard**, so if they just resigned the
  transfer aborts before the old owner steps down — the business can never end up
  ownerless. No money moves.
- **Close** (root menu, typed-name confirmation) — the remaining account balance is
  refunded to the OWNER's bank via the **crash-safe pending idiom** (one atomic
  `SET pending_amount = account_balance, account_balance = 0` captures the exact
  balance and zeroes the account so no serve can race money in), settled once, and
  only THEN are the roster + business row deleted. The ledger is kept as an orphan
  audit trail; ids are never reused. Delete happens only after a confirmed refund —
  a failed refund keeps the business intact.
- **Gating** — while `Config.OwnershipLifecycle = false`, both ops refuse and the
  menu items are hidden; the live system is unchanged. Neither op can mint or
  overdraw (transfer moves nothing; close returns the owner their own money).

## Register robbery (ships DARK behind `Config.Robbery`)
Makes a placed storefront a target. A **non-member** at the storefront runs
`/robstore`, passes a skill-check, and cracks the register for a **capped** cut of
the account — paid to their bank.
- **Money-safe** — a single atomic UPDATE debits the account (guarded `balance >=
  amount AND pending_amount = 0`) and stamps the per-business cooldown in one
  statement, so it can't overdraw, can't mint, and can't be double-robbed (the
  second robber fails the cooldown guard the instant the first stamps it). On a
  bank-credit failure the take is put back and the cooldown cleared.
- **Bounded** — `Rob.Pct` (25%) of the account, hard-capped at `Rob.Max` ($5k),
  only if the account holds at least `Rob.Min` ($2k); a long per-business cooldown
  (`Rob.CooldownSec`, 45 min) + a per-robber cooldown (`Rob.RobberCooldownSec`)
  set before any DB yield. Fires a soft police alert + pings the owner.
- **Requires a placed storefront** (Phase 1a) and server-side proximity; you can't
  rob your own business. `getMembership` hot path untouched. New migration `0072`
  = `last_robbed_at` on `palm6_businesses` (nullable). Gate off → `/robstore`
  refuses, nothing changes.

## Server exports (seams for later phases)
- `exports.palm6_business:GetBusinessOf(citizenid)` → summary | nil
- `exports.palm6_business:Charge(businessId, payerCid, amount, memo)` → bool
  (generic player→business revenue; used by `palm6_protection` extortion later)
- `exports.palm6_business:GetAccountBalance(businessId)` → int
- `exports.palm6_business:GetStorefront(businessId)` → `{x,y,z,h}` | nil (Phase 1;
  for a future greeter ped / delivery target / extortion "shake down the shop")

## Tables (dbmigrate 0068 + 0070)
`palm6_businesses`, `palm6_business_members`, `palm6_business_ledger` (0068).
Phase 1 adds `loc_x/loc_y/loc_z/loc_h` + `blip_sprite/blip_color` to
`palm6_businesses` via `0070` (`ADD COLUMN IF NOT EXISTS`, all nullable). All
idempotent in `palm6_dbmigrate`.

## Still deferred (Phase 2)
Heavier type-specific *systems* beyond the service profiles above — a dealership
**vehicle lot** (spawn + ownership transfer), a bar **venue/DJ revenue window**,
garage **repairs** wired to vehicle damage — each needs its own audit (vehicle
sales touch real money + ownership). Also: `palm6_protection` extortion of owned
businesses, store-SKU cosmetics (nameplate, storefront skin, Discord
business-registry badge), a manager delegate role, and a website `/business`
directory page.
