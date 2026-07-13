-- ============================================================================
-- gtarp_market/shared/config.lua
--
-- The Palm6 Commodity Exchange: a server-authoritative, supply/demand market
-- for the LEGAL economy's raw goods (gtarp_grind outputs). Prices move —
-- every unit sold pushes a commodity's price down, and it recovers toward its
-- rested `base` over wall-clock time. The exchange is also the ONLY buyer for
-- animal_pelt (gtarp_grind mints it as a hunting drop but ships no buyer).
--
-- The DESIGN (commodities, price model, tuning) is Tier 1 and carries to
-- GTA VI. The coords (exchange location) are Tier 3 — Los Santos map data,
-- VERIFY IN-GAME and reposition freely.
-- ============================================================================

Config = {}

Config.Debug = false

-- The exchange location. Tier-3 placeholder near the LS port/warehouse
-- district — VERIFY IN-GAME and move to taste.
Config.Exchange = {
    label  = 'Palm6 Commodity Exchange',
    coords = vector3(-40.00, -2530.00, 6.00),
    blip   = { sprite = 52, colour = 2, scale = 0.9 },
}

-- Interaction radius (metres) for the exchange counter. Matches gtarp_grind.
Config.InteractRadius = 2.5

-- Seconds between sells per player (server-enforced, atomic).
Config.SellCooldown = 3

-- Seconds between refines per player (server-enforced, atomic). Mirrors
-- SellCooldown. Conversion is INSTANT — the real throttle is the dynamic SELL
-- side (gather cooldown + marginal price crash on the refined commodity), not
-- the refine, so this is a light anti-spam guard, not the economic brake.
Config.RefineCooldown = 5

-- ---------------------------------------------------------------------------
-- Refining tier (v2). A value-add SINK: convert stacks of raw goods into a
-- higher-value refined good, then sell the refined good through the SAME
-- dynamic exchange curve below. Conversion is instant and lossless-by-ratio
-- (integer batches only). Refined goods are added to Config.Commodities so
-- they sell through the identical marginal-crash sell handler with no special
-- casing. There is no buy-back, so no round-trip arbitrage; the only edge is
-- refine->sell grossing the labour premium over raw->sell, which is bounded by
-- (1) the unchanged gather cooldown, (2) the refined sell curve crashing
-- faster than it recovers under heavy dumping, and (3) no cheap re-acquisition.
--
-- ratio is raws-consumed-per-1-refined (research: 2:1..3:1). Refined `base`
-- (in Config.Commodities) is raw_base * ratio * ~1.4 (a 30-60% labour premium).
-- ---------------------------------------------------------------------------
Config.RefineStation = {
    label = 'Palm6 Refinery',
    -- Tier-3 placeholder near the Ore Buyer / industrial zone — VERIFY IN-GAME
    -- and reposition freely (same discipline as the exchange coords).
    coords = vector3(1075.00, -2005.00, 32.00),
    blip   = { sprite = 402, colour = 47, scale = 0.85 },
    ped    = { model = `s_m_y_construct_01`, heading = 270.0 },
}

Config.Refine = {
    { raw = 'raw_ore',     refined = 'refined_metal', ratio = 3 },
    { raw = 'animal_pelt', refined = 'cured_leather', ratio = 2 },
    { raw = 'raw_fish',    refined = 'fillet',        ratio = 2 },
    { raw = 'raw_meat',    refined = 'cured_meat',    ratio = 2 },
}

-- ---------------------------------------------------------------------------
-- Price model (server-authoritative, wall-clock, computed lazily on read):
--   * price recovers toward `base` at RecoverPctPerMin of base per minute
--     (capped at base — base is the rested ceiling)
--   * each unit sold pushes that commodity's price down by ImpactPct of base,
--     applied MARGINALLY within a single sale so dumping a big stack crashes
--     the price mid-sale (no selling 500 units at the top price)
--   * price is floored at floorPct of base
-- Nothing is a client tick and nothing is stored per-frame: price is a pure
-- function of {last persisted price, last persisted timestamp, now}, so it is
-- restart- and relog-safe exactly like the grow/dry/cook timers in gtarp_drugs.
-- ---------------------------------------------------------------------------
Config.ImpactPct        = 0.02   -- -2% of base per unit sold (marginal)
Config.RecoverPctPerMin = 2.5    -- +2.5% of base per minute, back toward base

-- Safety ceiling on how many units one sale will price-walk (anti-DoS on the
-- marginal loop; real stacks on a 48-slot server are far below this).
Config.MaxUnitsPerSale = 2000

-- Commodities the exchange buys. `base` is the rested price; `grindFloor` is
-- gtarp_grind's fixed buyer price, shown on /market for comparison (nil means
-- the exchange is the only buyer — animal_pelt).
Config.Commodities = {
    { item = 'raw_fish',    label = 'Raw Fish',    base = 60, floorPct = 0.40, grindFloor = 45 },
    { item = 'raw_ore',     label = 'Raw Ore',     base = 95, floorPct = 0.40, grindFloor = 70 },
    { item = 'raw_meat',    label = 'Raw Meat',    base = 72, floorPct = 0.40, grindFloor = 55 },
    { item = 'animal_pelt', label = 'Animal Pelt', base = 90, floorPct = 0.45, grindFloor = nil },

    -- Refined goods (v2). Sold ONLY here (no grind buyer). `base` = raw_base *
    -- ratio * ~1.4 (labour premium), rounded. They ride the identical marginal
    -- crash + recovery curve, so heavy refining crashes the refined price
    -- faster than it recovers — the intended self-limiting value tier.
    { item = 'refined_metal', label = 'Refined Metal', base = 400, floorPct = 0.40, grindFloor = nil },  -- 95*3*1.40 = 399
    { item = 'cured_leather', label = 'Cured Leather', base = 270, floorPct = 0.45, grindFloor = nil },  -- 90*2*1.50 = 270
    { item = 'fillet',        label = 'Fish Fillet',   base = 170, floorPct = 0.40, grindFloor = nil },  -- 60*2*1.42 = 170
    { item = 'cured_meat',    label = 'Cured Meat',    base = 210, floorPct = 0.40, grindFloor = nil },  -- 72*2*1.45 = 209
}

-- gtarp_ui panel styling for the /market price board (money green).
Config.Panel = { tag = 'MARKET', color = { 88, 196, 122 } }

-- The public command that prints the live price board.
Config.Command = 'market'
