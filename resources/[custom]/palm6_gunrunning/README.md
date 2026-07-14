# palm6_gunrunning — black-market weapon dealer + ballistics tracing

Sells serialized, off-the-books weapons and hooks the recipe's own
ballistics forensics so a gun bought here can actually be traced back to
the buyer if it's fired at a crime scene. Real forensics already exist in
`qbx_police` (shell casings carry the weapon's `ox_inventory`
`metadata.serial`, collectible and readable) — but they're entirely
ephemeral. Nothing records who a serial belongs to. This resource is that
registry.

## Player surface

Server-only resource (no client script — every interaction is a
server-validated chat command, matching the `palm6_bounty`/`palm6_mdt`/
`palm6_ransom` precedent):

- `/buyweapon [#]` — buy off the catalog while standing at the dealer's
  drop point (`Config.DropPoint`). No arg, or a bad index, prints the
  catalog with prices. Cash comes straight from the buyer's bank; the
  weapon is handed over with a synthetic serial baked into its
  `ox_inventory` metadata.

There is no sell-back, no restock timer, no scarcity model — a fixed
config-driven catalog, kept intentionally simple (MVP scope, same as
`palm6_ransom`'s flat `Config.Ransom`).

## The ballistics hook — why this is real, not cosmetic

`qbx_police/server/main.lua` registers `evidence:server:CreateCasing` —
fired whenever a weapon goes off, carrying the shooter's current weapon's
`metadata.serial`. This resource registers a **second** handler on the
same event (FiveM fires every registered handler independently — the
recipe's own handler is untouched, not reimplemented). On every casing
event this resource:

1. Re-derives the shooter's true weapon serial itself
   (`Bridge.GetCurrentWeaponSerial`, wrapping
   `exports.ox_inventory:GetCurrentWeapon(source).metadata.serial`) —
   **never** trusts the event's own `serial` parameter, which a modified
   client controls. If there's no serial (a non-serialized default
   weapon), there's nothing to check and the handler returns immediately.
2. Looks the real serial up against `palm6_gunrunning_sales`.
3. On a match, opens/appends a `palm6_evidence` case (frozen v2 API) and
   links the buyer as a suspect via `LinkSuspect` — a ballistics match.

Deliberately **no auto-warrant** here (unlike `palm6_ransom`, which does
auto-issue one). A ballistics match to a sale record is circumstantial
investigative evidence — it proves someone bought the gun, not that they
committed whatever the casing was found at. Staff/RP decide what happens
with the lead; this resource just makes the lead exist.

## Money safety

`/buyweapon` charges the bank, then writes the sale row (`INSERT` with a
`UNIQUE(serial)` guard, retried up to 5 times on a synthetic-serial
collision — vanishingly unlikely given the random space, but never an
unbounded retry), then grants the item. Either failure point refunds and
rolls back cleanly:

- Sale-row insert fails after charging → refund, no item ever granted.
- Item grant fails (e.g. full inventory) after the sale row is written →
  refund **and** delete the now-orphaned sale row, so a failed purchase
  never leaves a phantom registry entry a real ballistics match could
  wrongly hang off later.

## Design notes

- Bridge-pattern (see `docs/GTA6-READINESS.md`): all logic in `server/`;
  every qbx/ox/native call lives in `bridge/sv_framework.lua`.
- `palm6_evidence` integration uses only the frozen four exports
  (`EnsureCase`/`AppendEntry`/`LinkSuspect`/`GetCase`) — never touches its
  tables directly.
- `/buyweapon` is a chat command, not a net event — `palm6_eventguard`'s
  `Config.Events` only guards `RegisterNetEvent` handlers (confirmed this
  session), so it doesn't need an entry there; it has its own
  `Config.BuyCooldownSec` rate limit instead. The one real net event this
  resource registers (the second `evidence:server:CreateCasing` handler)
  **does** get an eventguard budget, as defense-in-depth on top of the
  "only writes on a real serial match" gate already inside the handler.
- `Config.DropPoint.coords` is a Tier-3 placeholder (see
  `docs/GTA6-READINESS.md` §2) — retune once a real MLO/prop is picked.
- Exports: `GetSummary() -> { totalSales, totalRevenue }`.

## Dup-gate (2026-07-08)

`grep -riE "weapon.?deal|gunrunning|black.?market|serial|ballistic"` across
both `resources/[custom]` (every existing `palm6_*` resource) and the
deployed recipe's full `[qbx]` tree returns hits only in
`qbx_police/client/evidence.lua` + `qbx_police/server/main.lua` (the
recipe's real but ephemeral shell-casing/serial forensics) and
`palm6_counterfeit`'s README (a different concept — fake cash, not guns).
No existing `palm6_*` resource sells weapons or tracks serial provenance.
Same shape as every other gap closed this session: the recipe owns the
physical verb (a serial exists, can be dusted and read), the custom layer
owns the registry that makes that serial mean something.
