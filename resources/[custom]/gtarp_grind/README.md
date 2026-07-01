# gtarp_grind

Legal solo grind loops — **fishing, mining, hunting**. Buy a tool, gather at
world spots, sell the yield to a buyer for cash. XP per activity scales both
yield (a small bonus every 5 levels) and sale price (+5%/level).

Self-contained and **solo-testable** — one player can run the whole loop, so
it's ideal for the first in-game smoke test.

Bridge-pattern (see `docs/GTA6-READINESS.md`): all logic in `server/` +
`client/`; every qbx/ox_inventory/native/ox_lib call lives in `bridge/`. The
`grind_skill` XP table is our own schema and stays in the logic.

## The loop

1. **Buy a tool** at the Hardware Store (Sandy Shores / Paleto) — Fishing Rod
   $250, Pickaxe $350, Hunting Knife $300.
2. **Gather** — go to a spot (blip-less; see coords in `shared/config.lua`),
   `[E]`, complete the progress bar. Requires the tool; server checks tool +
   proximity + an 8s cooldown, then grants the yield and XP.
3. **Sell** — go to the buyer (blipped) and `[E]`: sells your whole stack of
   that yield for cash at the level-scaled price.

| Activity | Tool | Yields | Buyer |
| --- | --- | --- | --- |
| Fishing | fishing_rod | raw_fish | Fish Market (Del Perro) |
| Mining | pickaxe | raw_ore | Ore Buyer (Cypress Flats) |
| Hunting | hunting_knife | raw_meat, animal_pelt (chance) | Butcher (Paleto) |

## Depends on

- Items + tool prices added to `ox_inventory_overrides` (`data/items.lua`,
  `data/shops.lua`).
- `sql/0011_grind.sql` (grind_skill table).
- `ensure gtarp_grind` in `custom.cfg` (after `gtarp_housing`).

## GTA VI notes (Tier 3)

Gather spots + sell-point coords are Los Santos points (see
`docs/GTA6-TIER3-RETUNE.md`). Tools, yields, prices, and the XP curve are
Tier 1 and carry.

## Deferred to v2

- Processing step (raw -> refined) for higher-value sales.
- Per-spot depletion/respawn and rarer nodes at higher levels.
- Animations/props during gather (v1 uses a plain progress bar).
- A skill HUD showing current level/next-level XP.
