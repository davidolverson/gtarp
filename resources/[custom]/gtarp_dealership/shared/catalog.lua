-- ============================================================================
-- gtarp_dealership/shared/catalog.lua
--
-- The CANONICAL Palm6 vehicle catalog. Pure data — the single source of truth
-- for which base-game cars Palm6 sells, at what price, from which lot. Two
-- consumers read this:
--   1. server/main.lua       — validates it and prints a summary at boot.
--   2. tools/patch-vehicle-prices.sh — at deploy, rewrites the `price =` field
--      in the LIVE qbx_core/shared/vehicles.lua for each model below to
--      TierPrices[tier]. It touches NOTHING else (no coords, categories, hashes,
--      or non-listed models).
--
-- Prices are tuned to the real Palm6 economy: $1,500 onboarding starter cash and
-- the qbx_economy paycheck ladder. A commuter is a few days of honest work; a
-- super is a long-term goal. Retune by editing TierPrices — one number moves a
-- whole class.
--
-- IMPORTANT — parseability: the patch script parses this file with simple
-- regexes, so keep the strict one-per-line shapes:
--   TierPrices:  <tier> = <integer>,
--   Vehicles:    { model = '<spawn>', tier = '<tier>', shop = '<pdm|luxury>' },
-- Every `model` MUST be a real base-game spawn name that exists as a key in
-- qbx_core/shared/vehicles.lua, and every `tier` MUST exist in TierPrices.
-- `shop` is documentation for a later shop-assignment patch; the price patch
-- ignores it.
-- ============================================================================
Catalog = {}

Catalog.TierPrices = {
    economy      = 9000,
    commuter     = 16000,
    sedan        = 30000,
    suv          = 48000,
    sport        = 90000,
    performance  = 200000,
    super        = 750000,
    motorcycle   = 24000,
    offroad      = 42000,
    utility      = 32000,
}

-- shop: 'pdm' = Palm6 Motors (standard lot) · 'luxury' = Bayside Prestige Motors.
Catalog.Vehicles = {
    -- economy
    { model = 'blista',     tier = 'economy',     shop = 'pdm' },
    { model = 'panto',      tier = 'economy',     shop = 'pdm' },
    { model = 'dilettante', tier = 'economy',     shop = 'pdm' },
    { model = 'prairie',    tier = 'economy',     shop = 'pdm' },
    { model = 'rhapsody',   tier = 'economy',     shop = 'pdm' },
    { model = 'brioso',     tier = 'economy',     shop = 'pdm' },
    -- commuter
    { model = 'asea',       tier = 'commuter',    shop = 'pdm' },
    { model = 'premier',    tier = 'commuter',    shop = 'pdm' },
    { model = 'ingot',      tier = 'commuter',    shop = 'pdm' },
    { model = 'regina',     tier = 'commuter',    shop = 'pdm' },
    { model = 'stanier',    tier = 'commuter',    shop = 'pdm' },
    { model = 'stratum',    tier = 'commuter',    shop = 'pdm' },
    -- sedan
    { model = 'asterope',   tier = 'sedan',       shop = 'pdm' },
    { model = 'fugitive',   tier = 'sedan',       shop = 'pdm' },
    { model = 'primo',      tier = 'sedan',       shop = 'pdm' },
    { model = 'warrener',   tier = 'sedan',       shop = 'pdm' },
    { model = 'intruder',   tier = 'sedan',       shop = 'pdm' },
    { model = 'tailgater',  tier = 'sedan',       shop = 'pdm' },
    -- suv
    { model = 'baller',     tier = 'suv',         shop = 'pdm' },
    { model = 'cavalcade',  tier = 'suv',         shop = 'pdm' },
    { model = 'granger',    tier = 'suv',         shop = 'pdm' },
    { model = 'patriot',    tier = 'suv',         shop = 'pdm' },
    { model = 'dubsta',     tier = 'suv',         shop = 'pdm' },
    { model = 'rocoto',     tier = 'suv',         shop = 'pdm' },
    -- sport
    { model = 'sultan',     tier = 'sport',       shop = 'pdm' },
    { model = 'kuruma',     tier = 'sport',       shop = 'pdm' },
    { model = 'buffalo',    tier = 'sport',       shop = 'pdm' },
    { model = 'elegy2',     tier = 'sport',       shop = 'pdm' },
    { model = 'futo',       tier = 'sport',       shop = 'pdm' },
    { model = 'penumbra',   tier = 'sport',       shop = 'pdm' },
    -- performance (luxury lot)
    { model = 'comet2',     tier = 'performance', shop = 'luxury' },
    { model = 'banshee',    tier = 'performance', shop = 'luxury' },
    { model = 'feltzer2',   tier = 'performance', shop = 'luxury' },
    { model = 'jester',     tier = 'performance', shop = 'luxury' },
    { model = 'massacro',   tier = 'performance', shop = 'luxury' },
    { model = 'sentinel',   tier = 'performance', shop = 'luxury' },
    -- super (luxury lot)
    { model = 'adder',      tier = 'super',       shop = 'luxury' },
    { model = 'zentorno',   tier = 'super',       shop = 'luxury' },
    { model = 't20',        tier = 'super',       shop = 'luxury' },
    { model = 'entityxf',   tier = 'super',       shop = 'luxury' },
    { model = 'osiris',     tier = 'super',       shop = 'luxury' },
    { model = 'turismor',   tier = 'super',       shop = 'luxury' },
    -- motorcycle
    { model = 'akuma',      tier = 'motorcycle',  shop = 'pdm' },
    { model = 'sanchez',    tier = 'motorcycle',  shop = 'pdm' },
    { model = 'pcj',        tier = 'motorcycle',  shop = 'pdm' },
    { model = 'vader',      tier = 'motorcycle',  shop = 'pdm' },
    { model = 'bagger',     tier = 'motorcycle',  shop = 'pdm' },
    { model = 'nemesis',    tier = 'motorcycle',  shop = 'pdm' },
    -- offroad
    { model = 'rebel2',     tier = 'offroad',     shop = 'pdm' },
    { model = 'sandking',   tier = 'offroad',     shop = 'pdm' },
    { model = 'blazer',     tier = 'offroad',     shop = 'pdm' },
    { model = 'bifta',      tier = 'offroad',     shop = 'pdm' },
    { model = 'kalahari',   tier = 'offroad',     shop = 'pdm' },
    { model = 'dune',       tier = 'offroad',     shop = 'pdm' },
    -- utility / work
    { model = 'rumpo',      tier = 'utility',     shop = 'pdm' },
    { model = 'burrito',    tier = 'utility',     shop = 'pdm' },
    { model = 'bison',      tier = 'utility',     shop = 'pdm' },
    { model = 'mule',       tier = 'utility',     shop = 'pdm' },
    { model = 'boxville',   tier = 'utility',     shop = 'pdm' },
    { model = 'speedo',     tier = 'utility',     shop = 'pdm' },
}
