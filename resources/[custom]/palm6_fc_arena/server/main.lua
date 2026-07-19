-- ============================================================================
-- palm6_fc_arena/server/main.lua
-- Pure logic. Calls Bridge.* for framework access. Presentation + fight-mark
-- geometry only — no money, no DB, no HP/winner/rep authority.
--
-- Consumes T6 server-internal seams: fc:match:opened / :countdown / :teardown.
-- Produces: GetFightMarks export, palm6_fc_arena:bettingOpen / :squareUp.
-- ============================================================================

local function dbg(msg) if Config.Debug then print('[palm6_fc_arena] ' .. msg) end end

local function coreConfig()
    local ok, c = pcall(function() return exports.palm6_fc_core:Config() end)
    return ok and c or nil
end

local function coreStateKeys()
    local ok, k = pcall(function() return exports.palm6_fc_core:StateKeys() end)
    return ok and k or nil
end

local function enabled()
    local c = coreConfig()
    return c and c.Enabled and true or false
end

-- Two opposing marks around the ring center on the X axis, each facing the
-- other. mark A at +X faces west (heading 90 => -X); mark B at -X faces east
-- (heading 270 => +X). Stateless: safe to call from the export or a handler.
local function computeMarks()
    local c = coreConfig()
    local ring = c and c.Ring
    if not ring or not ring.coords then return nil end
    local o = Config.FightMarkOffset or 1.25
    local ctr = ring.coords
    return {
        a = { x = ctr.x + o, y = ctr.y, z = ctr.z, heading = 90.0 },
        b = { x = ctr.x - o, y = ctr.y, z = ctr.z, heading = 270.0 },
    }
end

-- Server-authoritative fight marks — T6 reads these at COUNTDOWN for the
-- finisher origin. Pure geometry, so it answers even when disabled.
exports('GetFightMarks', function(_matchId)
    return computeMarks()
end)

-- A match entered BETTING (T6 fired the seam after OpenMatch): tell the server
-- (arena-wide reach = -1) so spectators discover it and can /fcbet.
AddEventHandler('fc:match:opened', function(d)
    if not enabled() then return end
    if type(d) ~= 'table' or not d.matchId then return end
    local c = coreConfig()
    local minb = (c and c.Betting and c.Betting.MinBet) or 50
    local maxb = (c and c.Betting and c.Betting.MaxBet) or 5000
    local betCmd = ('/fcbet %d [1|2] [$%d-%d]'):format(d.matchId, minb, maxb)
    TriggerClientEvent('palm6_fc_arena:bettingOpen', -1, {
        matchId = d.matchId,
        f1name = d.f1name or 'Fighter 1',
        f2name = d.f2name or 'Fighter 2',
        betCmd = betCmd,
    })
    dbg(('bettingOpen broadcast for match #%d'):format(d.matchId))
end)

-- COUNTDOWN: square both fighters up on opposing marks (each on their OWN ped).
AddEventHandler('fc:match:countdown', function(d)
    if not enabled() then return end
    if type(d) ~= 'table' or not d.matchId then return end
    local marks = computeMarks()
    if not marks then return end
    local srcA = d.cidA and Bridge.GetSourceByCitizenId(d.cidA)
    local srcB = d.cidB and Bridge.GetSourceByCitizenId(d.cidB)
    if srcA then
        TriggerClientEvent('palm6_fc_arena:squareUp', srcA, {
            matchId = d.matchId,
            coords = { x = marks.a.x, y = marks.a.y, z = marks.a.z },
            heading = marks.a.heading,
        })
    end
    if srcB then
        TriggerClientEvent('palm6_fc_arena:squareUp', srcB, {
            matchId = d.matchId,
            coords = { x = marks.b.x, y = marks.b.y, z = marks.b.z },
            heading = marks.b.heading,
        })
    end
    dbg(('squareUp sent for match #%d (A=%s B=%s)'):format(d.matchId, tostring(srcA), tostring(srcB)))
end)

-- Teardown seam: arena holds NO per-match server state (computeMarks is
-- stateless), so this is a defensive no-op hook kept for the seam contract.
AddEventHandler('fc:match:teardown', function(d)
    if type(d) ~= 'table' then return end
    dbg(('teardown seam observed for match #%s'):format(tostring(d.matchId)))
end)

-- ---------------------------------------------------------------------------
-- Ace-gated dev driver — exercises the FULL arena visual path before T6 combat
-- exists (§14 stub philosophy). Fires the three seams + a fake LIVE statebag +
-- the client teardown, so crowd/repel/cam/squareUp/betting-hint are all
-- testable with only fc_core present. NOT a production path.
-- ---------------------------------------------------------------------------
RegisterCommand('fcarenatest', function(src, args)
    if src ~= 0 and not IsPlayerAceAllowed(src, 'palm6_fc.debug') then return end
    local cidA, cidB = args[1], args[2]
    local matchId = 0  -- sentinel id; never collides with a real match row
    TriggerEvent('fc:match:opened', { matchId = matchId, f1name = 'Test A', f2name = 'Test B', betWindowSec = 60 })
    CreateThread(function()
        Wait(2000)
        TriggerEvent('fc:match:countdown', { matchId = matchId, cidA = cidA, cidB = cidB })
        Wait(1000)
        local keys = coreStateKeys()
        local key = (keys and keys.matchKey and keys.matchKey(matchId)) or ('fc:match:%d'):format(matchId)
        GlobalState:set(key, {
            status = 'live', roundStarted = true,
            slot = {
                [1] = { hp = 100, stam = 100, blazin = 0, name = 'Test A', model = 'mp_m_freemode_01' },
                [2] = { hp = 100, stam = 100, blazin = 0, name = 'Test B', model = 'mp_m_freemode_01' },
            },
        }, true)
        Wait((Config.CrowdTestSec or 10) * 1000)
        GlobalState:set(key, nil, true)
        TriggerClientEvent('palm6_fc_combat:teardown', -1, { matchId = matchId })
        print('[palm6_fc_arena] fcarenatest complete for match #0')
    end)
end, false)
