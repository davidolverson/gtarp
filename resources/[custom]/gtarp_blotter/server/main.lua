-- ============================================================================
-- gtarp_blotter/server/main.lua
--
-- Pure logic. Calls Bridge.* (bridge/sv_framework.lua) for all framework /
-- native access. No direct framework / native calls here (Section 6 gate).
--
-- READ-ONLY civic visibility. This resource creates NO tables and writes
-- NOTHING. It runs parameterized, windowed SELECTs over tables other
-- resources own and aggregates them:
--   - gtarp_citations   (0024): fine ledger, status in unpaid/paid/escalated,
--                        columns amount, status, created_at.
--   - gtarp_mdt_bookings (0023 + sealed_at from 0026): arrest paperwork,
--                        columns citizen_name, officer_name, charges,
--                        booked_at, sealed_at.
--   - gtarp_mdt_calls   (0025): 911 dispatch log, columns text, src_label,
--                        created_at.
--
-- /blotter is on-duty-police gated (server console and the command.blotter
-- ace may also run it), rate-limited, and read-only. The optional weekly
-- Discord digest is OFF by default and posts through the soft Bridge.Announce
-- guard on the reused 'police' feed.
-- ============================================================================

local lastAction = {}   -- [src] = { [key] = ts }

local function now() return os.time() end

local function dbg(msg)
    if Config.Debug then print('[gtarp_blotter] ' .. msg) end
end

local function rl(src, key)
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

-- ---------------------------------------------------------------------------
-- Read-only aggregate over the last `hours`. Every section is pcall-wrapped
-- so a missing table or column yields an empty section rather than an error.
-- Returns a plain table (safe to hand to callers via the GetSummary export).
-- ---------------------------------------------------------------------------
local function buildSummary(hours)
    hours = clamp(math.floor(tonumber(hours) or Config.Window.DefaultHours), 1, Config.Window.MaxHours)

    local summary = {
        windowHours = hours,
        citations = {
            unpaid    = { count = 0, total = 0 },
            paid      = { count = 0, total = 0 },
            escalated = { count = 0, total = 0 },
        },
        bookings = { count = 0, recent = {} },
        calls    = { count = 0, recent = {} },
    }

    -- Citations grouped by status: counts + dollar totals over the window.
    pcall(function()
        local rows = MySQL.query.await([[
            SELECT status, COUNT(*) AS n, COALESCE(SUM(amount), 0) AS total
            FROM gtarp_citations
            WHERE created_at >= NOW() - INTERVAL ? HOUR
            GROUP BY status
        ]], { hours }) or {}
        for _, r in ipairs(rows) do
            local bucket = summary.citations[r.status]
            if bucket then
                bucket.count = tonumber(r.n) or 0
                bucket.total = tonumber(r.total) or 0
            end
        end
    end)

    -- Recent bookings/arrests. Sealed rows leave the rap-sheet surface
    -- (0026 legal), so they are excluded from the listed records; the window
    -- count below counts unsealed bookings the same way for consistency.
    pcall(function()
        local r = MySQL.single.await([[
            SELECT COUNT(*) AS n
            FROM gtarp_mdt_bookings
            WHERE booked_at >= NOW() - INTERVAL ? HOUR AND sealed_at IS NULL
        ]], { hours })
        summary.bookings.count = r and tonumber(r.n) or 0
    end)
    pcall(function()
        summary.bookings.recent = MySQL.query.await([[
            SELECT id, citizen_name, officer_name, charges,
                   TIMESTAMPDIFF(MINUTE, booked_at, NOW()) AS age_m
            FROM gtarp_mdt_bookings
            WHERE booked_at >= NOW() - INTERVAL ? HOUR AND sealed_at IS NULL
            ORDER BY id DESC LIMIT ?
        ]], { hours, clamp(Config.Lists.Bookings, 1, Config.Lists.MaxRows) }) or {}
    end)

    -- Recent 911 calls. gtarp_mdt_calls has no status column, so "recent" is
    -- the time window, matching how gtarp_mdt and gtarp_ems read it.
    pcall(function()
        local r = MySQL.single.await([[
            SELECT COUNT(*) AS n
            FROM gtarp_mdt_calls
            WHERE created_at >= NOW() - INTERVAL ? HOUR
        ]], { hours })
        summary.calls.count = r and tonumber(r.n) or 0
    end)
    pcall(function()
        summary.calls.recent = MySQL.query.await([[
            SELECT id, text, src_label,
                   TIMESTAMPDIFF(MINUTE, created_at, NOW()) AS age_m
            FROM gtarp_mdt_calls
            WHERE created_at >= NOW() - INTERVAL ? HOUR
            ORDER BY id DESC LIMIT ?
        ]], { hours, clamp(Config.Lists.Calls, 1, Config.Lists.MaxRows) }) or {}
    end)

    return summary
end

-- Format a summary into chat lines for /blotter.
local function summaryLines(s)
    local c = s.citations
    local lines = {}
    lines[#lines + 1] = ('=== LSPD Blotter, last %dh ==='):format(s.windowHours)
    lines[#lines + 1] = ('Citations: %d unpaid ($%d), %d escalated ($%d), %d paid ($%d)'):format(
        c.unpaid.count, c.unpaid.total,
        c.escalated.count, c.escalated.total,
        c.paid.count, c.paid.total)

    lines[#lines + 1] = ('Bookings: %d in window'):format(s.bookings.count)
    if #s.bookings.recent == 0 then
        lines[#lines + 1] = '  (no recent bookings)'
    else
        for _, b in ipairs(s.bookings.recent) do
            lines[#lines + 1] = ('  #%d [%dm ago] %s, %s (by %s)'):format(
                b.id, tonumber(b.age_m) or 0,
                trim(b.citizen_name ~= '' and b.citizen_name or '(unknown)'),
                trim(b.charges), trim(b.officer_name ~= '' and b.officer_name or '(unknown)'))
        end
    end

    lines[#lines + 1] = ('911 calls: %d in window'):format(s.calls.count)
    if #s.calls.recent == 0 then
        lines[#lines + 1] = '  (no recent calls)'
    else
        for _, k in ipairs(s.calls.recent) do
            lines[#lines + 1] = ('  #%d [%dm ago] %s%s'):format(
                k.id, tonumber(k.age_m) or 0, trim(k.text),
                (k.src_label and k.src_label ~= '') and (' (' .. trim(k.src_label) .. ')') or '')
        end
    end
    return lines
end

-- ---------------------------------------------------------------------------
-- /blotter [hours], on-duty police (or console/admin), read-only, rate-limited
-- ---------------------------------------------------------------------------
local function cmdBlotter(src, args)
    if src ~= 0 and not rl(src, 'blotter') then return end
    if not (Bridge.IsAdmin(src) or Bridge.IsOnDutyPolice(src)) then
        Bridge.Notify(src, 'Blotter', 'You need to be on duty as police.', 'error')
        return
    end

    local hours = clamp(math.floor(tonumber(args[1]) or Config.Window.DefaultHours), 1, Config.Window.MaxHours)
    local s = buildSummary(hours)
    Bridge.Reply(src, summaryLines(s))
    dbg(('blotter pulled by %s over %dh'):format(
        src == 0 and 'console' or Bridge.GetPlayerName(src), hours))
end

-- ---------------------------------------------------------------------------
-- OPTIONAL weekly Discord digest. OFF by default (Config.Digest.Enabled). One
-- timer thread, guarded twice: the config flag and gtarp_discord being
-- started (soft, via Bridge.Announce). Posts a single embed on the reused
-- 'police' feed. Reads only, exactly like /blotter.
-- ---------------------------------------------------------------------------
local function digestPayload(s)
    local c = s.citations
    local function block(rows, empty, fmt)
        if #rows == 0 then return empty end
        local out = {}
        for _, r in ipairs(rows) do out[#out + 1] = fmt(r) end
        return table.concat(out, '\n')
    end

    return {
        title = ('LSPD Weekly Blotter, last %dh'):format(s.windowHours),
        description = ('%d unpaid citations ($%d), %d escalated ($%d), %d paid ($%d). %d bookings, %d 911 calls.'):format(
            c.unpaid.count, c.unpaid.total,
            c.escalated.count, c.escalated.total,
            c.paid.count, c.paid.total,
            s.bookings.count, s.calls.count),
        fields = {
            {
                name = 'Recent bookings',
                value = block(s.bookings.recent, 'None in window', function(b)
                    return ('#%d %s, %s'):format(b.id,
                        trim(b.citizen_name ~= '' and b.citizen_name or '(unknown)'), trim(b.charges))
                end),
            },
            {
                name = 'Recent 911 calls',
                value = block(s.calls.recent, 'None in window', function(k)
                    return ('#%d %s'):format(k.id, trim(k.text))
                end),
            },
        },
    }
end

CreateThread(function()
    if not Config.Digest.Enabled then
        dbg('weekly digest disabled')
        return
    end
    Wait(Config.Digest.BootDelayMs or 60000)
    while true do
        if Config.Digest.Enabled and Bridge.ResourceStarted('gtarp_discord') then
            local s = buildSummary(Config.Digest.WindowHours)
            local sent = Bridge.Announce(Config.Digest.Feed, digestPayload(s))
            dbg(('weekly digest %s'):format(sent and 'posted' or 'skipped (feed off or absent)'))
        end
        Wait((Config.Digest.IntervalHours or 168) * 3600 * 1000)
    end
end)

-- ---------------------------------------------------------------------------
-- Commands + boot
-- ---------------------------------------------------------------------------
Bridge.RegisterCommand('blotter', function(source, args) cmdBlotter(source, args) end)

AddEventHandler('onResourceStart', function(resource)
    if resource ~= GetCurrentResourceName() then return end
    print(('[gtarp_blotter] read-only civic blotter online, /blotter (police); weekly digest %s')
        :format(Config.Digest.Enabled and 'ARMED (police feed)' or 'off'))
end)

-- Read-only summary for devtest and future consumers. Signature frozen:
-- GetSummary(hours) -> aggregate table (see buildSummary).
exports('GetSummary', function(hours)
    return buildSummary(hours or Config.Window.DefaultHours)
end)
