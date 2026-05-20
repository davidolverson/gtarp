-- ============================================================================
-- config_overrides/qbx_density/config.lua
--
-- Server-owner-controlled world-population tuning for the recipe-deployed
-- qbx_density. We do NOT vendor or edit qbx_density (it ships in the qbox-lean
-- recipe under [qbx]) — configure-over-build.
--
-- HOW qbx_density WORKS (Qbox-project/qbx_density, recipe ver 1.0.x)
-- ------------------------------------------------------------------
-- It is a CLIENT-side resource. client/main.lua loads config/client.lua and
-- runs a per-frame thread that feeds the values straight into the vanilla GTA
-- population natives:
--     SetParkedVehicleDensityMultiplierThisFrame(parked)
--     SetVehicleDensityMultiplierThisFrame(vehicle)
--     SetRandomVehicleDensityMultiplierThisFrame(randomvehicles)
--     SetPedDensityMultiplierThisFrame(peds)
--     SetScenarioPedDensityMultiplierThisFrame(scenario, scenario)
-- Its config/client.lua ships every key at 0.8. The ONLY runtime lever it
-- exposes is the client export:  exports.qbx_density:SetDensity(type, value).
-- There are NO convars and NO server-side API. So this override resource
-- applies our values from a client script that calls that export on spawn
-- (see client/overrides.lua).
--
-- RANGE for every lever: 0.0 (none) .. 1.0 (GTA Online populate rate).
-- Values outside that range are clamped by client/overrides.lua.
--
-- PERFORMANCE
-- -----------
-- Population density is a direct CPU/onesync cost: every extra ped and vehicle
-- is simulated and (under onesync) network-relevant. This box is an 8GB tier
-- with a small expected player count, so these values intentionally stay below
-- 1.0 to leave headroom. If you see server hitches / client frame drops in
-- busy areas (Legion Square, freeways), lower `vehicle` and `scenario` first
-- in ~0.1 steps — moving traffic and scenario crowds are the heaviest.
-- ============================================================================

Config = {}

-- Each key maps 1:1 to a qbx_density density type (the `type` arg of
-- SetDensity). Names match qbx_density's config/client.lua exactly.
Config.Density = {
    -- Walking civilians / random peds. RP worlds read as "alive" mostly from
    -- people on foot, so we push this slightly above the 0.8 recipe default.
    -- Safe range 0.0-1.0; sensible RP range 0.8-1.0.
    peds = 0.9,

    -- Moving (driving) traffic. Kept BELOW peds on purpose: RP cities feel
    -- off when there are more cars than pedestrians, and dense moving traffic
    -- is the single biggest perf cost. Sensible RP range 0.6-0.8.
    vehicle = 0.7,

    -- "Random"/unique ambient vehicles (the rarer model pool). Pair with
    -- `vehicle`; keep them in step. Sensible RP range 0.6-0.8.
    randomvehicles = 0.7,

    -- Parked vehicles lining streets. Cheap visual win for "lived-in" streets
    -- (static, low simulation cost), so we keep it at the recipe default.
    -- Sensible RP range 0.7-0.9.
    parked = 0.8,

    -- Scenario peds (bench-sitters, smokers, bikers, gangsters — the scripted
    -- "doing something" crowd). Slightly trimmed for perf; they cluster and
    -- can spike in hotspots. Sensible RP range 0.6-0.8.
    scenario = 0.7,
}
