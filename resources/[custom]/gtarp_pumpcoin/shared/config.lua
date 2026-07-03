-- ============================================================================
-- gtarp_pumpcoin/shared/config.lua — engine-agnostic tunables (Tier 1,
-- carries to VI). Curve math, fees, timings, and rules all live here; only
-- Config.Exchanges and the blip sprites are Tier 3 (Los Santos values).
--
-- IMPORTANT: BasePrice / CurveK are snapshotted per-coin at mint time.
-- Changing them here affects NEW coins only — live curves are never
-- retro-edited (that would silently reprice player holdings).
-- ============================================================================
Config = {}

Config.Debug = false

-- ---------------------------------------------------------------------------
-- Exchange terminals (Tier 3 — Los Santos coords, retune for VI).
-- Back-alley laptop spots. Deliberately unmarked by default: finding the
-- exchange is word-of-mouth RP.
-- ---------------------------------------------------------------------------
Config.Exchanges = {
    vector3(287.4, -1000.7, 29.4),   -- Pillbox Hill back alley
    vector3(-1179.5, -1483.5, 4.4),  -- Vespucci canals alley
    vector3(1195.0, -472.0, 66.2),   -- Mirror Park side street
}
Config.InteractRadius = 2.0

-- Optional map blips for the exchanges. OFF by default — it is a back-alley
-- exchange; players are meant to share the spots in RP.
Config.ExchangeBlip = {
    enabled = false,
    sprite = 606,      -- laptop-ish; tune to taste (Tier 3)
    colour = 2,        -- green
    scale = 0.7,
    label = 'Shady Hotspot',
}

-- ---------------------------------------------------------------------------
-- Bonding curve + economy.
-- price(s) = BasePrice * (1 + s / CurveK)^2, s = units on the curve.
-- Fills integrate the curve exactly (no per-unit loop), so big buys pay
-- their own slippage and big sells eat theirs.
-- ---------------------------------------------------------------------------
Config.MintCost = 5000          -- $ to launch a coin (economy sink)
Config.BasePrice = 2.0          -- $ per unit at zero supply
Config.CurveK = 500             -- curve steepness: bigger = flatter pumps
Config.MaxSupply = 25000        -- hard cap on units per coin
Config.TradeFeePct = 0.02       -- 2% exchange fee on buys AND sells (sink)
Config.MaxTradeUnits = 5000     -- max units per single fill

-- Hidden dev wallet premined to the creator at mint. Keep its curve value
-- (BasePrice*CurveK/3 * ((1+D/K)^3 - 1)) well under MintCost or minting
-- becomes a money printer at delist — the server prints a boot warning if
-- this is ever misconfigured. Defaults: premine is worth ~$792 of the $5000
-- mint fee.
Config.DevAllocationUnits = 250

-- ---------------------------------------------------------------------------
-- Rug mechanics.
-- ---------------------------------------------------------------------------
-- A single sell by the creator of >= this fraction of the original dev
-- allocation is a RUG: the sale executes, buys halt, holders get the RUGGED
-- broadcast. (Bleeding the wallet out in smaller clips is a "slow rug" —
-- intentionally legal and silent. Choosing between the two IS the gameplay.)
Config.RugThresholdPct = 0.80

-- Anonymity window after a rug before the creator's identity is broadcast
-- to the whole server (and written to the police evidence log).
Config.RevealDelaySec = 600     -- 10 minutes

-- Rug reveals write a fraud entry into the gtarp_evidence table for
-- detective RP (soft dependency — silently skipped if the table is absent).
Config.WriteEvidenceOnReveal = true

-- ---------------------------------------------------------------------------
-- Lifecycle.
-- ---------------------------------------------------------------------------
Config.CoinLifetimeDays = 7     -- coins auto-delist this many days after mint
-- On delist every remaining holder is auto-paid their pro-rata share of the
-- curve reserve (minus the exchange fee), online or offline. Forced endgame.

Config.SweepIntervalMs = 30000  -- reveal/delist/expiry housekeeping cadence

-- ---------------------------------------------------------------------------
-- Anti-spam / caps (server-enforced).
-- ---------------------------------------------------------------------------
Config.MintCooldownSec = 1800   -- per character
Config.MaxCoinsPerCreator = 2   -- live coins per character
Config.MaxLiveCoins = 25        -- global live-coin cap
Config.TradeCooldownSec = 2     -- per character, buys+sells
Config.DataCooldownSec = 1      -- market snapshot / chart request throttle

-- ---------------------------------------------------------------------------
-- Street shilling: the creator runs /shill TICKER, and for the window below
-- anyone who buys while physically near the creator gets the discount.
-- Rewards IRL-style shilling — and voluntarily leaks who the dev is.
-- ---------------------------------------------------------------------------
Config.ShillRadius = 12.0       -- metres from creator at moment of purchase
Config.ShillDurationSec = 60
Config.ShillCooldownSec = 300
-- Discount off the pre-fee cost. MUST stay below the round-trip fee
-- break-even 2*TradeFeePct/(1+TradeFeePct) (~3.92% at the 2% fee) or a
-- shill buy + immediate sell of the same units prints money for any alt or
-- accomplice near the creator. The server clamps the effective discount to
-- 80% of break-even regardless of what is set here (and warns at boot).
Config.ShillDiscountPct = 0.03  -- 3% off the pre-fee cost

-- ---------------------------------------------------------------------------
-- Billboard blips: /pumpboard TICKER drops a map blip at the creator's
-- position advertising the coin. Paid, temporary, rate-limited.
-- ---------------------------------------------------------------------------
Config.BillboardCost = 2500
Config.BillboardDurationSec = 1800  -- 30 minutes
Config.BillboardCooldownSec = 900
Config.BillboardBlipSprite = 590    -- Tier 3 — tune to taste
Config.BillboardBlipColour = 46     -- gold
Config.BillboardBlipScale = 0.9

-- ---------------------------------------------------------------------------
-- Verified badge (gtarp_turf synergy): if the creator's gang owns at least
-- this many turf zones at mint, the coin lists with a VERIFIED badge —
-- turf dominance as on-chain clout. Soft dependency; skipped if absent.
-- ---------------------------------------------------------------------------
Config.VerifiedEnabled = true
Config.VerifiedTurfZones = 2

-- ---------------------------------------------------------------------------
-- Mint input rules + chart.
-- ---------------------------------------------------------------------------
Config.NameMinLen = 3
Config.NameMaxLen = 24
Config.TickerMinLen = 2
Config.TickerMaxLen = 6
-- Emoji whitelist (also drives the NUI picker). Keeps arbitrary UTF-8 out
-- of broadcasts and the UI.
Config.Emojis = {
    '🚀', '🐸', '🐕', '🐈', '🦍', '💎', '🌙', '🔥', '💊', '🧠',
    '🍌', '🥶', '👑', '🤡', '🦴', '🧨', '🫡', '😼', '🐋', '🥩',
}

Config.ChartTradeLimit = 120    -- most recent fills sent to the NUI chart
