# gtarp_yard — Bolingbroke prison economy

Layers a player-facing economy on top of **xt-prison** (the only jail system in
the recipe). Three server-authoritative surfaces:

| Surface | What it does | Retention hook |
|---|---|---|
| **Labor** | Shave your OWN sentence by working yard tasks. | Highest — touches the player's grievance (time). |
| **Commissary** | Buy-only cash shop (markup + daily cap). | Medium — decays once the player is flush. |
| **Bail** | Superlinear pretrial release; re-issues an mdt warrant. | The escape hatch, priced as a deterrent. |

## Server-authoritative invariants
- The sentence clock is xt-prison's: `Player(src).state.jailTime` (MINUTES),
  persisted to `xt_prison(identifier, jailtime)` keyed to **citizenid**. Disconnect
  freezes it; relog re-imprisons; only a real release (timer expiry, paid bail,
  admin) clears it.
- The client NEVER sends a shave amount, a price, an amount, coordinates, or an
  "I am free" claim. Labor/bail send an empty payload; commissary sends only
  `{item, qty}`. The server re-owns the price, the daily cap, the proximity, and
  the clock.
- **Labor shave is capped at 50% of the sentence baseline** — jail always costs.
- **Bail** = `Base + floor(remainingSeconds^1.15 * K)`, floored at `Floor` (above
  a typical crime payout). Releasing re-issues `gtarp_mdt:IssueWarrant`; on the
  next 180s sweep `gtarp_bounty` auto-posts a city-funded state contract — we
  wire nothing there.

## Money-safety
- Atomic per-player cooldown set BEFORE any yield (in-memory same-tick guard +
  a **persisted** `gtarp_yard_labor.last_task_at` gate that survives relog).
- Server-side proximity re-derived from the caller's ped.
- Consume-before-grant: bail/commissary remove money BEFORE releasing/granting,
  with a refund ladder on any post-debit failure.
- NaN/negative guards on every number; all SQL parameterized.

## Architecture (§6 bridge gate)
- `server/main.lua` / `client/main.lua` = **logic only**, calling `Bridge.*` /
  `Game.*`. `MySQL.*` for the resource's own `gtarp_yard_*` tables is allowed in
  server logic.
- `bridge/sv_framework.lua` — the ONLY server file touching qbx_core,
  ox_inventory, the xt-prison export/statebag, gtarp_mdt, and natives.
- `bridge/cl_game.lua` — the ONLY client file touching natives / ox_target /
  ox_lib.

## Tables (all `gtarp_`-prefixed) — migration `sql/0047_yard.sql`
`gtarp_yard_sentence`, `gtarp_yard_labor`, `gtarp_yard_commissary_log`,
`gtarp_yard_bail`.

## New ox_inventory items (owned by this resource)
`yard_pruno`, `yard_commissary_snack`, `yard_soap`. They are NOT edited into
`items.lua` by this resource — the orchestrator adds them. **gtarp_yard
self-disables loudly at boot if any is missing** (mirrors gtarp_drugs).

## Config coords
`Config.Coords` are **Tier-3 placeholders at Bolingbroke** — verify in-game and
move. `Config.Bail.Account` is `bank`; commissary is `cash`.
