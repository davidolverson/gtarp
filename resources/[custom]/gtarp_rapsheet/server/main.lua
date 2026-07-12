-- ============================================================================
-- gtarp_rapsheet/server/main.lua
--
-- Pure logic. Calls Bridge.* (bridge/sv_framework.lua) for all framework /
-- native access. No direct framework / native calls here (Section 6 gate).
--
-- READ-ONLY justice record. This resource creates NO tables and writes
-- NOTHING. Every query is a parameterized SELECT / COUNT / SUM over tables
-- other resources own, and every section is pcall-wrapped so a missing table
-- or column degrades that section to empty rather than erroring the command:
--   - gtarp_citations      (0024): fine ledger. Outstanding = status in
--                           ('unpaid','escalated'); columns amount, reason,
--                           status, due_at.
--   - gtarp_mdt_bookings   (0023 + sealed_at from 0026): arrest paperwork.
--                           Sealed rows (sealed_at IS NOT NULL) are EXCLUDED
--                           per the expungement convention; columns charges,
--                           officer_name, booked_at, sealed_at.
--   - gtarp_mdt_warrants   (0023): open orders. Active = status 'active';
--                           columns reason, officer_name, status, created_at.
--   - gtarp_bounty_contracts (0027): wanted board. Active = status 'active'
--                           targeting the citizen; columns kind, amount,
--                           reason, target_citizenid, status, created_at.
--
-- /rapsheet  is self only (the caller's own citizenid).
-- /priors    is on-duty-police gated (server console and the command.priors
--            ace may also run it), resolves a target by online player id or
--            citizenid, and carries a privacy note in its header.
-- ============================================================================

local lastAction = {}   -- [src] = { [key] = ts }

local function now() return os.time() end

local function dbg(msg)
    if Config.Debug then print('[gtarp_rapsheet] ' .. msg) end
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

local function cap(n)
    return clamp(math.floor(tonumber(n) or 1), 1, Config.Lists.MaxRows)
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
-- Read-only record for one citizenid. Every section is pcall-wrapped so a
-- missing table or column yields an empty section rather than an error.
-- Returns a plain table (safe to hand to callers via the GetRecord export).
-- ---------------------------------------------------------------------------
local function buildRecord(cid)
    cid = tostring(cid or '')
    local rec = {
        citizenid = cid,
        citations = { count = 0, total = 0, recent = {} },
        bookings  = { count = 0, recent = {} },
        warrants  = { count = 0, recent = {} },
        bounties  = { count = 0, total = 0, recent = {} },
    }
    if cid == '' then return rec end

    -- Outstanding citations: count + dollar total owed (unpaid + escalated).
    pcall(function()
        local r = MySQL.single.await([[
            SELECT COUNT(*) AS n, COALESCE(SUM(amount), 0) AS total
            FROM gtarp_citations
            WHERE citizenid = ? AND status IN ('unpaid','escalated')
        ]], { cid })
        if r then
            rec.citations.count = tonumber(r.n) or 0
            rec.citations.total = tonumber(r.total) or 0
        end
    end)
    pcall(function()
        rec.citations.recent = MySQL.query.await([[
            SELECT id, amount, reason, status,
                   TIMESTAMPDIFF(HOUR, NOW(), due_at) AS hrs_left
            FROM gtarp_citations
            WHERE citizenid = ? AND status IN ('unpaid','escalated')
            ORDER BY id DESC LIMIT ?
        ]], { cid, cap(Config.Lists.Citations) }) or {}
    end)

    -- Booking / arrest history, EXCLUDING sealed rows (0026 expungement
    -- convention). The window count matches the same sealed exclusion.
    pcall(function()
        local r = MySQL.single.await([[
            SELECT COUNT(*) AS n
            FROM gtarp_mdt_bookings
            WHERE citizenid = ? AND sealed_at IS NULL
        ]], { cid })
        rec.bookings.count = r and tonumber(r.n) or 0
    end)
    pcall(function()
        rec.bookings.recent = MySQL.query.await([[
            SELECT id, charges, officer_name,
                   TIMESTAMPDIFF(HOUR, booked_at, NOW()) AS hrs_ago
            FROM gtarp_mdt_bookings
            WHERE citizenid = ? AND sealed_at IS NULL
            ORDER BY id DESC LIMIT ?
        ]], { cid, cap(Config.Lists.Bookings) }) or {}
    end)

    -- Active warrants naming the citizen.
    pcall(function()
        local r = MySQL.single.await([[
            SELECT COUNT(*) AS n
            FROM gtarp_mdt_warrants
            WHERE citizenid = ? AND status = 'active'
        ]], { cid })
        rec.warrants.count = r and tonumber(r.n) or 0
    end)
    pcall(function()
        rec.warrants.recent = MySQL.query.await([[
            SELECT id, reason, officer_name,
                   TIMESTAMPDIFF(HOUR, created_at, NOW()) AS hrs_ago
            FROM gtarp_mdt_warrants
            WHERE citizenid = ? AND status = 'active'
            ORDER BY id DESC LIMIT ?
        ]], { cid, cap(Config.Lists.Warrants) }) or {}
    end)

    -- Active bounties targeting the citizen: count + total on their head.
    pcall(function()
        local r = MySQL.single.await([[
            SELECT COUNT(*) AS n, COALESCE(SUM(amount), 0) AS total
            FROM gtarp_bounty_contracts
            WHERE target_citizenid = ? AND status = 'active'
        ]], { cid })
        if r then
            rec.bounties.count = tonumber(r.n) or 0
            rec.bounties.total = tonumber(r.total) or 0
        end
    end)
    pcall(function()
        rec.bounties.recent = MySQL.query.await([[
            SELECT id, kind, amount, reason,
                   TIMESTAMPDIFF(HOUR, created_at, NOW()) AS hrs_ago
            FROM gtarp_bounty_contracts
            WHERE target_citizenid = ? AND status = 'active'
            ORDER BY id DESC LIMIT ?
        ]], { cid, cap(Config.Lists.Bounties) }) or {}
    end)

    return rec
end

-- Format a record into chat lines. `header` labels whose sheet this is.
local function recordLines(rec, header)
    local lines = {}
    lines[#lines + 1] = header

    -- Outstanding citations
    local ci = rec.citations
    lines[#lines + 1] = ('Outstanding citations: %d ($%d owed)'):format(ci.count, ci.total)
    for _, c in ipairs(ci.recent) do
        local hrs = tonumber(c.hrs_left) or 0
        local state = c.status == 'escalated' and 'OVERDUE, WARRANT OUT'
            or (hrs >= 0 and ('due in %dh'):format(hrs) or 'OVERDUE')
        lines[#lines + 1] = ('  #%d $%d, %s [%s]'):format(
            c.id, tonumber(c.amount) or 0, trim(c.reason), state)
    end

    -- Booking / arrest history (sealed excluded)
    local bk = rec.bookings
    lines[#lines + 1] = ('Bookings on record: %d (sealed excluded)'):format(bk.count)
    for _, b in ipairs(bk.recent) do
        lines[#lines + 1] = ('  #%d [%dh ago] %s (by %s)'):format(
            b.id, tonumber(b.hrs_ago) or 0, trim(b.charges),
            trim(b.officer_name ~= '' and b.officer_name or '(unknown)'))
    end

    -- Active warrants
    local wr = rec.warrants
    lines[#lines + 1] = ('Active warrants: %d'):format(wr.count)
    for _, w in ipairs(wr.recent) do
        lines[#lines + 1] = ('  #%d [%dh ago] %s (by %s)'):format(
            w.id, tonumber(w.hrs_ago) or 0, trim(w.reason),
            trim(w.officer_name ~= '' and w.officer_name or '(unknown)'))
    end

    -- Active bounties targeting the citizen
    local bo = rec.bounties
    lines[#lines + 1] = ('Active bounties on you: %d ($%d total)'):format(bo.count, bo.total)
    for _, b in ipairs(bo.recent) do
        lines[#lines + 1] = ('  #%d [%s] $%d, %s'):format(
            b.id, trim(b.kind), tonumber(b.amount) or 0, trim(b.reason))
    end

    return lines
end

-- ---------------------------------------------------------------------------
-- /rapsheet, the caller's own justice record (self only), read-only,
-- rate-limited.
-- ---------------------------------------------------------------------------
local function cmdRapsheet(src)
    if src == 0 then
        Bridge.Reply(src, { '/rapsheet is a citizen command, run /priors <citizenid> from console.' })
        return
    end
    if not rl(src, 'rapsheet') then return end
    local cid = Bridge.GetCitizenId(src)
    if not cid then
        Bridge.Notify(src, 'Record', 'Could not read your citizen id.', 'error')
        return
    end
    local rec = buildRecord(cid)
    Bridge.Reply(src, recordLines(rec, '=== Your justice record ==='))
    dbg(('rapsheet self-pull by %s'):format(cid))
end

-- ---------------------------------------------------------------------------
-- /priors <playerid|citizenid>, on-duty police (or console/admin), read-only,
-- rate-limited. Carries a privacy note in the header.
-- ---------------------------------------------------------------------------
local function cmdRecord(src, args)
    if src ~= 0 and not rl(src, 'record') then return end
    if not (Bridge.IsAdmin(src) or Bridge.IsOnDutyPolice(src)) then
        Bridge.Notify(src, 'Record', 'You need to be on duty as police.', 'error')
        return
    end

    local query = tostring(args[1] or '')
    if query == '' then
        Bridge.Notify(src, 'Record', 'Usage: /priors [player id or citizenid]', 'error')
        return
    end

    local cid, name = Bridge.ResolveTarget(query)
    if not cid then
        Bridge.Notify(src, 'Record', 'No citizen matches that player id or citizenid.', 'error')
        return
    end

    local rec = buildRecord(cid)
    local header = ('=== Record: %s (%s) | official police lookup, keep confidential ==='):format(
        trim(name ~= '' and name or '(unknown)'), cid)
    Bridge.Reply(src, recordLines(rec, header))
    dbg(('record on %s pulled by %s'):format(
        cid, src == 0 and 'console' or Bridge.GetPlayerName(src)))
end

-- ---------------------------------------------------------------------------
-- Commands + boot
-- ---------------------------------------------------------------------------
Bridge.RegisterCommand('rapsheet', function(source) cmdRapsheet(source) end)
Bridge.RegisterCommand('priors', function(source, args) cmdRecord(source, args) end)

AddEventHandler('onResourceStart', function(resource)
    if resource ~= GetCurrentResourceName() then return end
    print('[gtarp_rapsheet] read-only justice record online, /rapsheet (self), /priors (police)')
end)

-- Read-only record for devtest and future consumers. Signature frozen:
-- GetRecord(citizenid) -> record table (see buildRecord). Never writes.
exports('GetRecord', function(citizenid)
    return buildRecord(citizenid)
end)
