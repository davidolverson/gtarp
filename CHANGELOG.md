# Changelog — Horizon (gtarp server)

All notable changes to the Horizon RP server's custom layer. **This is the
source of truth we post from** — every entry has an internal/technical list for
tracking *and* a ready-to-post **📣 Public** blurb (player-facing, no jargon) for
the Discord `#「📝」updates` channel, the website, and public announcements.

Format: newest first. Dates are EDT.

---

## 2026-07-10 — Economy anti-exploit hardening + coord retune

A server-wide adversarial audit of the money-handling systems (find →
independently verify → fix), plus real-location retuning of placeholder coords
and a continued bridge-pattern rollout. **8 confirmed-exploitable bugs fixed;
the other 12 audited resources came back clean.**

**Tracking (internal):**
- 🔴 **gtarp_courier** — fixed a **critical double-payout race**: `complete` now
  atomically gates the `UPDATE` on `status='taken' AND courier_citizenid` and only
  pays when rows-affected == 1. Same guard on cancel-refund and both lifetime sweeps.
- **gtarp_insurance** — policy is now consumed on claim (one payout per policy);
  no-scene damage claims are hard-denied instead of trusting client health.
- **gtarp_chopshop** — closed a free-money faucet: ambient/NPC cars (no
  `player_vehicles` row, no active stolen report) can no longer be sold.
- **gtarp_bounty** — fixed a city-money faucet: captured state contracts update in
  place (`status IN ('active','claimed')`) instead of re-posting every sweep.
- **gtarp_mechanic** — repairs now require a **customer consent handshake**
  (offer → confirm → accept, re-validated server-side) plus a per-customer cooldown;
  a mechanic can no longer force-charge a non-consenting nearby player.
- 🧩 **Bridge pattern** — extended to `ox_inventory_overrides` (isolated its
  `ox_inventory`/`ox_target`/native calls behind `bridge/`), per GTA6-readiness. The
  other candidate resources already had adapters.
- 📍 **Coord retune** — replaced Tier-3 placeholder map coords with real Los Santos
  locations across bounty, fightclub, gunrunning, laundering, loanshark, numbers,
  protection, and robbery. All flagged `VERIFY IN-GAME`.
- Audited clean (no fixes needed): laundering, numbers, loanshark, protection,
  seizure, smuggling, pumpcoin, economy, ransom, gunrunning, counterfeit, grind.

**📣 Public:**
> 🔧 **Server maintenance — economy hardening**
> We ran a full security sweep of the crime economy and patched several money
> exploits (courier payouts, insurance claims, chop-shop, bounties). Repairs from
> mechanics now ask for your approval before charging you. Plus we moved a bunch of
> racket locations to their real spots around the city. Cleaner, fairer hustle. 💰

## 2026-07-10 — 🌿 New: `gtarp_drugs` (Schedule I-style) — MVP Phase 1 built

The missing drug supply chain — a faithful adaptation of **Schedule I**. Design
locked in `docs/DRUGS-SPEC.md`; **MVP (weed only) built**: grow → mix a custom
branded product with stacking effects + quality → sell → dirty cash → laundering
+ heat/evidence. Not yet wired into `custom.cfg` (operator step).

**Tracking (internal):**
- 🌱 **Grow loop** — buy `weed_seed` + `soil` (+ optional grow additive), plant at
  an ox_target grow plot, water over **wall-clock DB timers resolved on
  interaction** (restart-safe, no client ticks), harvest `weed_bud` with
  `{strain,quality,effects,dried}` metadata. Neglect (water → 0%) drops quality/yield.
- 🌬️ **Drying rack → Heavenly** — hang a stack of fresh `weed_bud` on the rack
  (ox_target) to dry it over a **wall-clock `drugs_processes` timer** (`kind='dry'`,
  epoch seconds, resolved on interaction like the grow timers). On collect the buds
  come back **bumped to Heavenly (tier 4, ×1.30)** with `dried=true`, and the price
  engine applies the markup on any later mix/sell. One run per rack slot (UNIQUE
  `(kind,station_id)`); server-owned by its starter; **atomic `running→collecting`
  collect claim**; a crash-stranded run reverts to `running` at boot (never lost).
  No new item — the rack is a world station.
- 🧪 **Mixing station** — pick a base stack + one additive; the **server** resolves
  effects (append-if-absent, 8-cap, order kept), recomputes quality + unit price
  via the spec §5 formula, sanitizes a player brand, mints one `weed_product`
  (`{brand,base,effects[],quality,unit_value,batch_id,producer}`). Bad-mix roll can
  inflict a junk effect. Named recipes saved to `drugs_recipes` for one-click repeat.
- 💵 **Selling** — real players via ox_inventory trade, plus one **rate-limited NPC
  street-buyer** paying DIRTY `black_money` priced from the item's real metadata,
  bounded by a **per-character daily faucet cap**. Logged to `drugs_sales`.
- 🚔 **Heat/evidence (basic)** — sales warm a per-dealer heat model; a hot dealer or
  witness roll (and the odd big harvest) trips a native police alert +
  `gtarp_evidence` case. Every unit carries `batch_id`+`producer` for audit.
- 🧱 **Full §1–5 config** — 4 weed strains, 16 additives→effects, all 34 effect
  multipliers, 5 quality tiers, and the server-authoritative `Config.Price` helper.
- 🛡️ **Server-authoritative** — never trusts client price/effects/quality/amount;
  recomputes from config + metadata; consumes inputs before granting outputs;
  proximity re-derived server-side; all SQL parameterized. 12 net events registered
  in `gtarp_eventguard`. New items added to `ox_inventory_overrides` (replacing the
  earlier generic `cannabis_leaf`/`weed_baggie` draft). SQL: `drugs_plants`,
  `drugs_recipes`, `drugs_progression`, `drugs_sales` (`sql/0039_drugs.sql`) +
  `drugs_processes` (the drying-rack timer, `sql/0040_drugs_drying.sql`).
- ⏭️ **Deferred to Phase 2/3:** meth/shrooms/coke, NPC customers + hired dealers,
  the order-dependent reaction table, and rank/XP-gated properties.

**📣 Public:**
> 🌿 **New hustle incoming — grow, cook, and brand your own product**
> Plant strains, keep them watered, then take your buds to the mixing bench and
> cut them with additives to build custom effects and quality — then slap your own
> brand on it. Better product, better payout. Sell to other players or move it fast
> to a street buyer for dirty cash you'll need to launder. Bring heat if you get
> greedy. 💨

<!-- Template:
## YYYY-MM-DD — <title>
**Tracking (internal):**
- <change> (`resource`)
**📣 Public:**
> 🎮 <player-facing line(s)>
-->
