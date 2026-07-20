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

## Player commands
- `/business` (alias `/biz`) — opens the menu. Non-members can register; owners
  get Account / Employees / Operations / Ledger / Rename; employees get Clock
  in/out / Serve / Charge / Ledger / Resign.

## Server exports (seams for Phase 1)
- `exports.palm6_business:GetBusinessOf(citizenid)` → summary | nil
- `exports.palm6_business:Charge(businessId, payerCid, amount, memo)` → bool
  (generic player→business revenue; used by `palm6_protection` extortion later)
- `exports.palm6_business:GetAccountBalance(businessId)` → int

## Tables (dbmigrate 0068)
`palm6_businesses`, `palm6_business_members`, `palm6_business_ledger`. All
idempotent `CREATE IF NOT EXISTS` in `palm6_dbmigrate`.

## Deferred to Phase 1
Physical storefront location + blip (owner-set via `/coords` capture),
`palm6_protection` extortion of owned businesses, store-SKU cosmetics (nameplate,
storefront skin, Discord business-registry badge), a manager delegate role, and
a website `/business` directory page.
