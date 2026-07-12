-- ============================================================================
-- gtarp_ganginfo/server/main.lua
--
-- Pure logic. Calls Bridge.* (bridge/sv_framework.lua) for all framework /
-- native access. No direct framework / native calls here (Section 6 gate).
--
-- READ-ONLY public gang directory. This resource creates NO tables and writes
-- NOTHING. It runs parameterized SELECTs over tables other resources own and
-- prints the result to chat:
--   - gtarp_gangs        (0041 + 0043): id, name, tag, rep, created_at,
--                        description. Public identity of each player-run gang.
--   - gtarp_gang_members (0041): membership rows; member count is COUNT(*)
--                        grouped / filtered by gang_id.
--   - gtarp_turf         (0013): zone ownership; turf held is COUNT(*) WHERE
--                        owner_gang = the gang NAME string (owner_gang stores
--                        the gang's name, not its id, per gtarp_turf).
--
-- Two public, rate-limited commands, distinct from gtarp_gangs (which owns the
-- private /gang management menu and /gangweb):
--   /ganginfo <tag>   one gang's public profile.
--   /gangs [n]        the top gangs ranked by reputation.
-- Every section is pcall-wrapped, so a missing table or column yields an empty
-- section rather than an error.
-- ============================================================================

local lastAction = {}   -- [src] = { [key] = ts }

local function now() return os.time() end

local function dbg(msg)
    if Config.Debug then print('[gtarp_ganginfo] ' .. msg) end
end

-- Per-source, per-command cooldown. Console (source 0) is never limited.
local function rl(src, key)
    if src == 0 then return true end
    local window = Config.RateLimits[key] or 1
    lastAction[src] = lastAction[src] or {}
    local t = now()
    if (lastAction[src][key] or 0) + window > t then return false end
    lastAction[src][key] = t
    return true
end

local function clamp(v, lo, hi)
    if v < lo then return lo end
    if v > hi then return hi end
    return v
end

-- Trim a free-text field to a display-safe length.
local function trim(s)
    s = tostring(s or ''):gsub('%s+', ' '):gsub('^%s+', ''):gsub('%s+$', '')
    if #s > Config.TextClamp then
        return s:sub(1, Config.TextClamp - 1) .. '\226\128\166'  -- ellipsis
    end
    return s
end

-- Normalize a caller-supplied tag exactly the way gtarp_gangs sanitizeTag
-- stores it (alphanumerics only, uppercased), then cap the length so an absurd
-- argument can never bloat the bound parameter. Returns nil for empty input.
local function normalizeTag(raw)
    if type(raw) ~= 'string' then return nil end
    local tag = raw:gsub('[^%w]', ''):upper()
    if tag == '' then return nil end
    if #tag > 16 then tag = tag:sub(1, 16) end
    return tag
end

-- ---------------------------------------------------------------------------
-- Read helpers. Each is independently pcall-wrapped so one missing table or
-- column degrades to an empty / zero result instead of erroring the command.
-- ---------------------------------------------------------------------------

-- One gang's public row by (normalized) tag, or nil. founded is preformatted
-- in SQL; age_days is DATEDIFF so we never parse a timestamp string in Lua.
local function gangByTag(tag)
    local row
    pcall(function()
        row = MySQL.single.await([[
            SELECT id, name, tag, rep, description,
                   DATE_FORMAT(created_at, '%Y-%m-%d') AS founded,
                   DATEDIFF(NOW(), created_at) AS age_days
            FROM gtarp_gangs
            WHERE tag = ?
            LIMIT 1
        ]], { tag })
    end)
    return row
end

-- Member count for a gang id.
local function memberCount(gangId)
    local n = 0
    pcall(function()
        local r = MySQL.single.await(
            'SELECT COUNT(*) AS c FROM gtarp_gang_members WHERE gang_id = ?', { gangId })
        n = r and tonumber(r.c) or 0
    end)
    return n
end

-- Turf zones held. gtarp_turf.owner_gang stores the gang NAME string (see
-- gtarp_turf/server/main.lua: `z.owner_gang = gang.name`), so we bind the
-- gang's name, not its id. Guarded so an absent gtarp_turf yields 0.
local function turfHeld(gangName)
    local n = 0
    pcall(function()
        local r = MySQL.single.await(
            'SELECT COUNT(*) AS c FROM gtarp_turf WHERE owner_gang = ?', { gangName })
        n = r and tonumber(r.c) or 0
    end)
    return n
end

-- Top gangs ranked by reputation, with member count via a correlated subquery
-- so the whole leaderboard is one read. Returns a plain list (possibly empty).
local function topGangs(limit)
    local rows
    pcall(function()
        rows = MySQL.query.await([[
            SELECT g.id, g.name, g.tag, g.rep,
                   (SELECT COUNT(*) FROM gtarp_gang_members m WHERE m.gang_id = g.id) AS member_count
            FROM gtarp_gangs g
            ORDER BY g.rep DESC, g.id ASC
            LIMIT ?
        ]], { limit })
    end)
    return rows or {}
end

-- ---------------------------------------------------------------------------
-- Card builder + formatters (read-only; safe to reuse from the export).
-- ---------------------------------------------------------------------------

-- Assemble the public profile for one gang tag, or nil if no such gang.
local function buildCard(rawTag)
    local tag = normalizeTag(rawTag)
    if not tag then return nil end
    local g = gangByTag(tag)
    if not g then return nil end
    return {
        id       = g.id,
        name     = g.name or '(unnamed)',
        tag      = g.tag or tag,
        rep      = tonumber(g.rep) or 0,
        members  = memberCount(g.id),
        turf     = turfHeld(g.name),
        founded  = g.founded or 'unknown',
        ageDays  = tonumber(g.age_days) or 0,
        blurb    = (g.description and g.description ~= '') and trim(g.description) or nil,
    }
end

local function cardLines(c)
    local lines = {}
    lines[#lines + 1] = ('=== [%s] %s ==='):format(c.tag, c.name)
    lines[#lines + 1] = ('Reputation: %d   Members: %d   Turf zones held: %d'):format(
        c.rep, c.members, c.turf)
    lines[#lines + 1] = ('Founded: %s (%d day(s) ago)'):format(c.founded, c.ageDays)
    if c.blurb then
        lines[#lines + 1] = ('"%s"'):format(c.blurb)
    end
    return lines
end

local function leaderboardLines(rows, shown)
    local lines = {}
    lines[#lines + 1] = ('=== Top %d gangs by reputation ==='):format(shown)
    if #rows == 0 then
        lines[#lines + 1] = '  (no gangs registered yet)'
        return lines
    end
    for i, g in ipairs(rows) do
        lines[#lines + 1] = ('%d. [%s] %s   Rep: %d   Members: %d'):format(
            i, g.tag or '?', g.name or '(unnamed)', tonumber(g.rep) or 0, tonumber(g.member_count) or 0)
    end
    lines[#lines + 1] = 'Use /ganginfo <tag> for a full profile.'
    return lines
end

-- ---------------------------------------------------------------------------
-- Commands
-- ---------------------------------------------------------------------------

-- /ganginfo <tag>, public, rate-limited, read-only.
local function cmdGangInfo(src, args)
    if not rl(src, 'ganginfo') then return end
    local rawTag = args and args[1]
    if not rawTag or normalizeTag(rawTag) == nil then
        Bridge.Notify(src, 'Gangs', 'Usage: /ganginfo <tag>', 'error')
        if src == 0 then Bridge.Reply(src, { 'Usage: /ganginfo <tag>' }) end
        return
    end
    local card = buildCard(rawTag)
    if not card then
        Bridge.Notify(src, 'Gangs', ('No gang found with tag "%s".'):format(normalizeTag(rawTag)), 'error')
        if src == 0 then
            Bridge.Reply(src, { ('No gang found with tag "%s".'):format(normalizeTag(rawTag)) })
        end
        return
    end
    Bridge.Reply(src, cardLines(card))
    dbg(('ganginfo %s pulled by %s'):format(card.tag,
        src == 0 and 'console' or Bridge.GetPlayerName(src)))
end

-- /gangs [n], public, rate-limited, read-only.
local function cmdGangs(src, args)
    if not rl(src, 'gangs') then return end
    local n = clamp(math.floor(tonumber(args and args[1]) or Config.List.Top), 1, Config.List.MaxTop)
    local rows = topGangs(n)
    Bridge.Reply(src, leaderboardLines(rows, n))
    dbg(('gangs top %d pulled by %s'):format(n,
        src == 0 and 'console' or Bridge.GetPlayerName(src)))
end

-- ---------------------------------------------------------------------------
-- Boot
-- ---------------------------------------------------------------------------
Bridge.RegisterCommand('ganginfo', function(source, args) cmdGangInfo(source, args) end)
Bridge.RegisterCommand('gangs',    function(source, args) cmdGangs(source, args) end)

AddEventHandler('onResourceStart', function(resource)
    if resource ~= GetCurrentResourceName() then return end
    print('[gtarp_ganginfo] read-only public gang directory online: /ganginfo <tag>, /gangs [n]')
end)

-- ---------------------------------------------------------------------------
-- Read-only export for other resources (e.g. a future dashboard or devtest).
-- Signature frozen: GetGangCard(tag) -> card table, or nil if no such gang.
-- ---------------------------------------------------------------------------
exports('GetGangCard', function(tag)
    return buildCard(tag)
end)
