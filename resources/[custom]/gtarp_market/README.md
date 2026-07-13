# gtarp_market — Palm6 Commodity Exchange

A server-authoritative **supply/demand market** for the legal economy's raw
goods. It gives `gtarp_grind`'s outputs a living price instead of a flat vendor
rate, and it is the **only buyer** for `animal_pelt` (which `gtarp_grind` mints
as a hunting drop but ships no buyer for).

## The loop

Gather raw goods with `gtarp_grind` (fish / ore / meat / pelts), then bring them
to the **Commodity Exchange** and press **E** to sell everything sellable at the
current live price. Check prices any time with **`/market`** (a branded panel).

- **`raw_fish`, `raw_ore`, `raw_meat`** can be sold at *either* their fixed
  `gtarp_grind` buyer (the safe floor, which also has the grind XP bonus) *or*
  here at the fluctuating exchange price — a genuine sell-now-or-time-it choice.
- **`animal_pelt`** can only be sold here.

## Price model (server-authoritative, wall-clock, no ticks)

Each commodity's price is a **pure function** of its last persisted
`{price, timestamp}` and the current time:

- **Recovery:** price climbs back toward its rested `base` at
  `RecoverPctPerMin` of base per minute (capped at base).
- **Impact:** every unit sold pushes the price down by `ImpactPct` of base,
  applied **marginally within a single sale** — dumping a big stack crashes the
  price as it sells, so there is no selling 500 units at the top.
- **Floor:** price never drops below `floorPct` of base.

Because price is recomputed from persisted state on every read, the market is
**restart- and relog-safe** with zero client ticks — the same discipline as the
grow / dry / cook timers in `gtarp_drugs`.

## Money safety

- Atomic per-player sell **cooldown set before any yield** (a same-tick double
  fire can't bypass it).
- **Server-side proximity** check — the client is never trusted that it's at the
  counter; it sends no items, amounts or prices.
- **Consume before grant** — items are removed before cash is paid, and the
  market price only moves on a real, completed sale (a failed `RemoveItem`
  neither pays nor moves the market).
- Trade ledger insert is **best-effort** and never blocks or undoes a sale.

## Refining tier (v2) — the value-add sink

The **Palm6 Refinery** turns stacks of raw goods into higher-value **refined
goods**, which then sell through the *same* dynamic exchange curve. Gather at
`gtarp_grind`, refine here, sell refined at the exchange — a reason to hold and
add labour rather than dump raws flat.

Bring raws to the refinery and press **E**. Conversion is **instant and
integer-batched** (leftovers below a full batch stay in your pockets):

| Raw | → Refined | Ratio | Refined base |
|-----|-----------|-------|--------------|
| `raw_ore` | `refined_metal` | 3 : 1 | $400 |
| `animal_pelt` | `cured_leather` | 2 : 1 | $270 |
| `raw_fish` | `fillet` | 2 : 1 | $170 |
| `raw_meat` | `cured_meat` | 2 : 1 | $210 |

Each refined `base` is `raw_base * ratio * ~1.4` — the ~40% premium is the
**labour reward**. Refined goods are just more `Config.Commodities`, so they
ride the identical **marginal-crash + slow-recovery** sell curve.

**Why it is not a money printer.** The only chain is *gather raw
(`gtarp_grind`, gather cooldown) → refine (instant) → sell refined (crashing
curve)*. `gtarp_market` is **sell-only** (no buy-back) so there is no
round-trip arbitrage. Refine→sell grosses the labour premium over raw→sell —
the intended value tier — bounded by (1) the unchanged gather cooldown capping
raw supply, (2) the refined sell curve crashing ~2%/unit to a 40-45% floor and
recovering slowly, so heavy refining drives the refined price *below* the
equivalent raw value, and (3) no buy-side to re-acquire cheap inputs.

**Money safety (refine path).** Instant conversion is safe here because the
brake is the sell side, not the conversion — but the refine handler still
mirrors every sell-path guard: **atomic per-player cooldown before any yield**,
**server-side proximity** to the refinery, **consume raws before granting
refined**, and a **refund ladder** (raws restored) if the grant fails. Refined
goods are **never minted on a client callback** — the client sends no args.

**Self-disable.** Refined items must be registered in `ox_inventory`. At boot
the resource presence-checks each refined def; any missing one **disables the
refinery loudly** (a red console line naming the item) while the exchange keeps
running — the same soft-gate discipline as `gtarp_drugs`' cook chain.

New `ox_inventory` item defs required (add to
`ox_inventory_overrides/data/items.lua`): `refined_metal`, `cured_leather`,
`fillet`, `cured_meat`.

The refinery coords in `shared/config.lua` are a **Tier-3 placeholder — VERIFY
IN-GAME** and reposition freely.

## Files / wiring

- `sql/0046_market.sql` — `gtarp_market_state` (price state) + `gtarp_market_trades` (ledger). The refining tier adds **no table** — refined commodities reuse `gtarp_market_state`, defaulted to `base` by `seedState()`.
- `gtarp_eventguard` budgets `gtarp_market:sell` **and `gtarp_market:refine`**.
- `gtarp_economy` shows an informational **clean-cash** line via the
  `GetSummary` export (`{ commodities, unitsSold, totalPaid }`).
- Exchange coords in `shared/config.lua` are a **Tier-3 placeholder — VERIFY
  IN-GAME** and reposition freely.

## Bridge pattern (GTA VI portability)

All framework/native access is isolated in `bridge/sv_framework.lua` (items,
cash, coords, panel reply) and `bridge/cl_game.lua` (blip, prompt, interact).
`server/main.lua` and `client/main.lua` call only `Bridge.*` / `Game.*`, so a
port rewrites the two bridge files. See `docs/GTA6-READINESS.md` §3.

## Deferred (v3)

- **Refining tier** — shipped in v2 (see above).
- **Scarcity premium:** let a long-untouched commodity drift *above* base.
