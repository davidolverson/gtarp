# palm6_smuggling

Standalone multi-modal contraband runs. Grab a shipment, run it across the map
under a deadline while police try to intercept, get paid **dirty**.

Pick up a shipment at a hidden contact, get assigned a random drop, and race it
there within the window. The drop's **mode** — land / sea / air — sets the risk
and the pay: an airstrip run pays far more than a roadside lay-by because it
needs a plane and a longer exposed leg. Delivery pays **`black_money`**, which
then has to be laundered (`palm6_laundering`) and can be forfeited if police
catch you dirty (`palm6_seizure`).

## Commands

- **`/smuggle`** — at the docks contact, start a run. One shipment at a time,
  per-character cooldown. Police get a dispatch ping the moment you load up.
- **`/deliver`** — at your assigned drop, within the window, make the drop and
  get paid.
- **`/smugglerun`** — read-only: your drop, its mode, the pay, and time left.

## Distinct from `qbx_drugs` deliveries (the distinctness contract)

`qbx_drugs` also does timed contraband transport, so this deliberately does not
overlap it:

1. **No dealer coupling** — a standalone hidden pickup, no door-knock, no
   dealer-rep progression (qbx_drugs gates its runs behind the dealer loop).
2. **Pays `black_money`, not `markedbills`** (qbx_drugs' item) — that's what
   wires it into this server's dirty-money economy (launder/seize).
3. **Multi-modal drops (land/sea/air)** — qbx_drugs is a plain ground drop; the
   mode split (and the vehicles each needs) is the mechanical differentiator.
4. **Generic shipment, no drug items** — and critically **no new ox item at
   all**: the run is server-tracked STATE, so there's nothing to register (no
   `patch-ox-items` step on deploy) and nothing a client can forge.
5. **Real dispatch + a `palm6_evidence` trail** on delivery, not qbx_drugs'
   random police-alert ping.

## Anti-abuse (all server-side)

- Pickup/drop proximity is read from the caller's **server-side** ped position;
  the client sends nothing but the command. Payout is server-config (per drop,
  by mode); the deadline is a server `expires_at`.
- One active run per citizen (re-checked under a per-citizen lock); per-character
  start cooldown set before the first DB yield.
- Delivery is **claimed atomically** with a guarded `UPDATE ... WHERE
  status='active' AND expires_at > NOW()` before any payout, so a second
  `/deliver` or the expiry sweep can't double-pay; if the payout hand-over fails
  the run is restored rather than lost. An expiry sweep tidies abandoned runs.

## Data

`palm6_smuggling_runs` (`sql/0038_smuggling.sql`) — one row per run: dropoff_id,
mode, payout, status (active/delivered/expired), evidence_case_id, expires_at.
Export `GetSummary()` → `{ dropSites, delivered, active, dirtyPaid }`.

## Tuning (`shared/config.lua`)

`Config.Pickup`, `Config.Dropoffs` (id → mode → coords → payout range; Tier-3
placeholders — retune in-game), `DeliverRadius`, `RunTimeLimitSec`, `CooldownSec`.
