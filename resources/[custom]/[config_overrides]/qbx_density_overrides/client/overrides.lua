-- ============================================================================
-- config_overrides/qbx_density/client/overrides.lua
--
-- Applies our Config.Density values to the recipe-deployed qbx_density.
--
-- MECHANISM (traced from Qbox-project/qbx_density client/main.lua):
--   qbx_density keeps an in-memory `density` table seeded from its
--   config/client.lua, and a per-frame thread feeds it into the GTA
--   population natives. Its export `SetDensity(type, value)` mutates that
--   table for the live session. We therefore call the export once per client,
--   after qbx_density has started, to override the recipe defaults — without
--   touching the recipe resource itself.
--
--   This runs per client (client-side resource), which is correct: the GTA
--   density natives are inherently client/frame-scoped.
-- ============================================================================

local DENSITY_RESOURCE = 'qbx_density'

-- Valid qbx_density density types (from its SetDensity switch). We only push
-- keys it recognises; anything else is ignored by qbx_density.
local VALID_TYPES = {
    parked = true,
    vehicle = true,
    randomvehicles = true,
    peds = true,
    scenario = true,
}

local function clamp01(value)
    if type(value) ~= 'number' then return nil end
    if value < 0.0 then return 0.0 end
    if value > 1.0 then return 1.0 end
    return value
end

local function apply()
    if GetResourceState(DENSITY_RESOURCE) ~= 'started' then
        print(('[qbx_density_overrides] %s is not started; skipping.'):format(DENSITY_RESOURCE))
        return
    end

    if not Config or not Config.Density then
        print('[qbx_density_overrides] Config.Density missing; skipping.')
        return
    end

    local applied = {}
    for densityType, value in pairs(Config.Density) do
        if VALID_TYPES[densityType] then
            local v = clamp01(value)
            if v then
                exports[DENSITY_RESOURCE]:SetDensity(densityType, v)
                applied[densityType] = v
            else
                print(('[qbx_density_overrides] ignored %s (not a number): %s')
                    :format(densityType, tostring(value)))
            end
        else
            print(('[qbx_density_overrides] ignored unknown density type: %s')
                :format(tostring(densityType)))
        end
    end

    print(('[qbx_density_overrides] peds=%s vehicles=%s randomvehicles=%s parked=%s scenarios=%s')
        :format(
            tostring(applied.peds),
            tostring(applied.vehicle),
            tostring(applied.randomvehicles),
            tostring(applied.parked),
            tostring(applied.scenario)
        ))
end

-- Apply once qbx_density's export is live. On a fresh client join both
-- resources start together, so wait briefly for qbx_density to be ready.
CreateThread(function()
    local tries = 0
    while GetResourceState(DENSITY_RESOURCE) ~= 'started' and tries < 50 do
        tries = tries + 1
        Wait(100)
    end
    apply()
end)

-- Re-apply if qbx_density restarts at runtime (its restart re-seeds the table
-- back to its own config/client.lua defaults, wiping our override).
AddEventHandler('onClientResourceStart', function(resource)
    if resource == DENSITY_RESOURCE then
        apply()
    end
end)
