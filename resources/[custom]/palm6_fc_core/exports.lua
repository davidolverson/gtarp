-- ============================================================================
-- palm6_fc_core/exports.lua — export surface + boot data-integrity asserts.
-- The ONLY logic in this resource: pure lookups + load-time validation. No
-- events, threads, or gameplay behavior. Loads in BOTH realms.
-- ============================================================================

-- O(1) fighter index (Config.Fighters is an array; GetFighter looks up by id).
local FighterById = {}
for _, f in ipairs(Config.Fighters) do
    FighterById[f.id] = f
end

local function getFighter(fighterId) return FighterById[fighterId] end
local function getStyle(styleId)      return Config.Styles[styleId] end
local function getMove(moveId)        return Config.Moves[moveId] end

-- ---- boot data-integrity asserts (load-time; a bad row fails LOUD at boot,
-- ---- never silently ships a half-valid roster) ----
local MOVE_KEYS = { 'moveId', 'kind', 'damage', 'staminaCost', 'cooldownMs', 'activeWindowMs', 'reach', 'chipPct', 'blockStamCost' }

local function fcAssert(cond, msg)
    if not cond then error('[palm6_fc_core] CONFIG INVALID: ' .. msg, 0) end
end

-- 1) defaults resolve to real rows
fcAssert(getFighter(Config.DefaultFighter) ~= nil, 'DefaultFighter "' .. tostring(Config.DefaultFighter) .. '" is not a Config.Fighters id')
fcAssert(getStyle(Config.DefaultStyle) ~= nil,      'DefaultStyle "' .. tostring(Config.DefaultStyle) .. '" is not a Config.Styles id')

-- 2) every fighter references a real style
for _, f in ipairs(Config.Fighters) do
    fcAssert(getStyle(f.styleId) ~= nil, 'fighter "' .. tostring(f.id) .. '" has unknown styleId "' .. tostring(f.styleId) .. '"')
end

-- 3) every move row is complete + self-consistent
for id, m in pairs(Config.Moves) do
    fcAssert(m.moveId == id, 'move "' .. tostring(id) .. '" moveId mismatch (' .. tostring(m.moveId) .. ')')
    for _, k in ipairs(MOVE_KEYS) do
        fcAssert(m[k] ~= nil, 'move "' .. tostring(id) .. '" missing field "' .. k .. '"')
    end
end

-- 4) every dark-PvE CPU fighter references a real style
for _, c in ipairs(Config.Pve.CpuFighters) do
    fcAssert(getStyle(c.styleId) ~= nil, 'PvE CpuFighter "' .. tostring(c.id) .. '" has unknown styleId "' .. tostring(c.styleId) .. '"')
end

-- 5) §19.5 guarantee: a full rolling-day of TOP-tier PvE wins < one PvP win.
--    sum_{n=1..cap} PveTierRepFrac.T5 * DimFactor^(n-1) < 1.0  (fraction of RepPerPvpWin)
do
    local frac, dim, cap = Config.Pve.PveTierRepFrac.T5, Config.Pve.DimFactor, Config.Pve.PveDailyRepGrantCap
    local sum, term = 0.0, frac
    for _ = 1, cap do
        sum  = sum + term
        term = term * dim
    end
    fcAssert(sum < 1.0, string.format('PvE top-tier daily rep sum %.4f >= 1.0 (a full PvE day must be worth < one PvP win)', sum))
end

-- ---- exports (callable from every fc resource, BOTH realms) ----
exports('Config',     function() return Config end)
exports('GetFighter', function(fighterId) return getFighter(fighterId) end)
exports('GetStyle',   function(styleId)   return getStyle(styleId) end)
exports('GetMove',    function(moveId)    return getMove(moveId) end)
exports('StateKeys',  function() return FcStateKeys end)

-- ---- boot self-test: the visible boot-verify signal; smokes every resolver
-- ---- path + the statebag key builder. Printed server-side only (IsDuplicity-
-- ---- Version), but the asserts above run in BOTH realms. ----
do
    local nF = #Config.Fighters
    local nS, nM = 0, 0
    for _ in pairs(Config.Styles) do nS = nS + 1 end
    for _ in pairs(Config.Moves)  do nM = nM + 1 end
    assert(getMove('jab').damage == 6)
    assert(getFighter(Config.DefaultFighter).styleId ~= nil)
    assert(getStyle(Config.DefaultStyle).movementClipset ~= nil)
    assert(FcStateKeys.matchKey(7) == 'fc:match:7')
    if IsDuplicityVersion() then
        print(('[palm6_fc_core] data OK: %d fighters, %d styles, %d moves (Enabled=%s)'):format(nF, nS, nM, tostring(Config.Enabled)))
    end
end
