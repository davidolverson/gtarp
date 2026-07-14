# palm6_pumpcoin — the back-alley memecoin exchange

Players launch their own coins, pump them, shill them in the street, and rug
their own holders. Price is a **server-side bonding curve of real player
supply and demand** — no real-world price feeds, no external APIs, no
real-money mechanics anywhere. The other 47 players *are* the liquidity.

Every crypto script on the market fakes a BTC chart from a real-world API.
This one is pump.fun as a 48-slot social deathmatch: mathematically honest
pump-and-dump that generates its own RP storylines — rug reveals, street
shilling, detective fraud cases, gang-flexed "verified" launches.

Bridge-pattern (see `docs/GTA6-READINESS.md`): all logic is in `server/` and
`client/`; every qbx/native/NUI-focus call lives in `bridge/`.

## The loop

1. **Mint** — any player pays **$5,000** at a back-alley exchange laptop to
   launch a coin (name, ticker, emoji). Coins are **anonymous**: the board
   shows `anon-042`, not who minted it.
2. **Pump** — price follows `price = base × (1 + supply/k)²`. Fills integrate
   the curve exactly, so big orders pay/eat their own slippage. Early buyers
   only profit if later buyers come in. That's the whole game.
3. **Shill** — the creator runs `/shill TICKER`: for 60s, anyone who buys
   while physically within 12m of the creator gets **5% off** (checked
   server-side at the moment of purchase). Street shilling works — and
   voluntarily risks leaking who the dev is. `/pumpboard TICKER` drops a paid
   map-blip billboard at the creator's position for 30 minutes.
4. **Rug** — the creator holds a hidden **dev wallet** (250 units premined at
   mint). Dumping ≥80% of it in a single clip is a **RUG**: the sale executes,
   buys halt forever, every holder gets the 🚨 RUGGED broadcast, and after a
   **10-minute anonymity window** the creator's identity is revealed
   server-wide and a **fraud entry is written to the police evidence log**
   (`palm6_evidence`). Robbable/chargeable under server rules from there.
   Bleeding the wallet out in small clips instead is a silent "slow rug" —
   intentionally legal. Choosing your exit is the gameplay.
5. **Endgame** — coins auto-delist **7 days** after mint. Every remaining
   holder (online or offline) is auto-paid their pro-rata share of the curve
   reserve, minus the fee. No bags held forever; every coin ends in a story.

The exchange takes a **2% fee on every fill** plus the $5k mint — a pure
economy sink against the cash that grind/courier scripts inject.

## Economy honesty (why this can't print money)

- Buys remove bank money; sells/settlements return **at most** what the curve
  collected. Over a coin's full life the server nets: mint cost + all fees +
  rounding (buys round up, payouts round down).
- Curve parameters are **snapshotted per coin at mint** — retuning the config
  never repricies live holdings.
- Guard: the dev premine's curve value must stay below `MintCost` (defaults:
  ~$792 vs $5,000). The server prints a boot warning if you misconfigure this.

## Commands / interactions

| Interaction | Who | Effect |
| --- | --- | --- |
| `[E]` at an exchange laptop | anyone | open the exchange NUI (board, chart, buy/sell, mint) |
| `/shill TICKER` | coin creator | 60s street-shill window, 5% proximity discount, 5-min cooldown |
| `/pumpboard TICKER` | coin creator | $2,500 map-blip billboard at your position, 30 min, 15-min cooldown |

## Server authority

Everything that matters is enforced server-side: exchange proximity on every
open/trade/mint, price/fee/discount computation, bank charges before state
changes (with refunds on DB failure), holdings checks inside a per-coin lock
(no double-fill races across DB awaits), per-character cooldowns on minting
(30 min), trading (2s), and data requests (1s), input sanitization with an
emoji whitelist, ticker uniqueness, per-player and global live-coin caps, and
a max order size. The NUI only ever sends intents (coin id + unit count).

## Config (`shared/config.lua`)

- `Exchanges`, `InteractRadius`, `ExchangeBlip` — terminal locations (Tier 3
  coords; blips off by default, the exchange is word-of-mouth).
- `MintCost`, `BasePrice`, `CurveK`, `MaxSupply`, `TradeFeePct`,
  `MaxTradeUnits` — curve + economy.
- `DevAllocationUnits`, `RugThresholdPct`, `RevealDelaySec`,
  `WriteEvidenceOnReveal` — dev wallet + rug mechanics.
- `CoinLifetimeDays`, `SweepIntervalMs` — lifecycle.
- `MintCooldownSec`, `MaxCoinsPerCreator`, `MaxLiveCoins`, `TradeCooldownSec`,
  `DataCooldownSec` — anti-spam caps.
- `Shill*` — radius, window, cooldown, discount.
- `Billboard*` — cost, duration, cooldown, blip look.
- `VerifiedEnabled`, `VerifiedTurfZones` — palm6_turf synergy.
- `Name*`/`Ticker*` limits, `Emojis` whitelist, `ChartTradeLimit`.

## Install

1. `ensure palm6_pumpcoin` in `custom.cfg` (after `qbx_core`, `ox_lib`,
   `oxmysql`).
2. Apply `sql/0014_pumpcoin.sql` — creates `palm6_pumpcoin_coins`,
   `palm6_pumpcoin_holdings`, `palm6_pumpcoin_trades`.
3. Tune `shared/config.lua` (at minimum, check the exchange coords fit your
   map edits).

No external APIs, no keys, no custom assets — config coordinates only.

## Synergies (all soft dependencies — degrade silently if absent)

- **palm6_turf** — if the creator's gang owns ≥2 turf zones at mint, the coin
  lists with a **VERIFIED** badge. Turf dominance as buyer confidence.
- **palm6_evidence** — rug reveals write an automated fraud entry for
  detective RP (`/evidence` shows it).
- **Renewed-Banking / qbx money** — all settlement is the framework bank via
  the bridge; offline holders get delist payouts through the same offline
  credit path palm6_courier uses.
- **palm6_grind / palm6_courier** — the 2% fee + mint cost sink the cash
  those scripts inject.

## Performance

No unconditional per-frame client loops: the exchange prompt loop idles at
1000ms and only tightens while standing on a terminal (same pattern as
palm6_evidence). Server housekeeping is one 30s sweep. Trades are 3 queries
inside a per-coin lock — trivial at 48 slots.

## GTA VI notes

`Config.Exchanges` and the two blip sprites are Tier 3 (add to
`docs/GTA6-TIER3-RETUNE.md`). The curve math, rug lifecycle, settlement, NUI,
and SQL are Tier 1/2 and carry — porting is the standard two-bridge-file
rewrite.

## Deferred to v2

- No coin-gated perks (holder-only doors/discounts) — coins are pure
  speculation this version.
- No staff/admin delist command — delisting is time-based only for now.
- No limit orders or price alerts; the tape is market-orders only.
- Shill/billboard state is in-memory — an active 60s shill window or map
  billboard does not survive a server restart (coins, holdings, rug reveals,
  and delist timers all do — they're DB-backed).
- One global exchange book; no per-location books.
