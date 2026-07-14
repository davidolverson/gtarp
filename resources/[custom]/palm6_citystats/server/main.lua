-- ============================================================================
-- palm6_citystats/server/main.lua
--
-- Pure logic. Calls Bridge.* (bridge/sv_framework.lua) for all framework /
-- native access. No direct framework / native calls here (Section 6 gate).
--
-- READ-ONLY civic visibility, the in-game twin of the website /city page
-- (palm6/web/src/lib/economy.ts). This resource creates NO tables and writes
-- NOTHING. It runs parameterized SELECT / COUNT / SUM aggregates over tables
-- OTHER resources own and prints them:
--   - palm6_gangs        (0041): COUNT(*) + SUM(vault_balance); top by rep.
--                        Confirmed columns: id, name, tag, vault_balance, rep.
--   - palm6_gang_members (0041): COUNT(*) affiliated citizens.
--                        Confirmed column: citizenid.
--   - palm6_drugs_sales  (0039): SUM(net_dirty) + COUNT(*) since a recent
--                        window on created_at. Confirmed columns: net_dirty,
--                        created_at.
--   - palm6_mdt_warrants (0023): COUNT(*) WHERE status = 'active'.
--                        Confirmed column: status.
--
-- /citystats [hours] is open to any citizen (server console and the
-- command.citystats ace may also run it), rate-limited, and read-only. Each
-- section is pcall-wrapped so a missing table degrades to an empty section
-- rather than erroring the whole command.
-- ============================================================================

local lastAction = {}   -- [src] = { [key] = ts }

local function now() return os.time() end

local function dbg(msg)
    if Config.Debug then print('[palm6_citystats] ' .. msg) end
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

-- Group US-style thousands separators onto a dollar amount for display.
local function money(n)
    local s = tostring(math.floor(tonumber(n) or 0))
    local sign = ''
    if s:sub(1, 1) == '-' then sign, s = '-', s:sub(2) end
    while true do
        local rep
        s, rep = s:gsub('^(%d+)(%d%d%d)', '%1,%2')
        if rep == 0 then break end
    end
    return sign .. s
end

-- ---------------------------------------------------------------------------
-- Read-only aggregate build. Every section is pcall-wrapped and gated on its
-- Config.Stats flag, so a disabled section, a missing table, or a missing
-- column yields an empty section rather than an error. Returns a plain table
-- (safe to hand to callers via the GetStats export).
-- ---------------------------------------------------------------------------
local function buildStats(hours)
    hours = clamp(math.floor(tonumber(hours) or Config.Window.DefaultHours),
        Config.Window.MinHours, Config.Window.MaxHours)

    local stats = {
        windowHours = hours,
        gangs    = { enabled = false, count = 0, cityVault = 0, top = {} },
        members  = { enabled = false, count = 0 },
        drugs    = { enabled = false, dirtyMoved = 0, saleCount = 0 },
        warrants = { enabled = false, active = 0 },
    }

    -- Gangs: registered count + combined city vault, plus the top gangs by
    -- reputation. Mirrors economy.ts getCityEconomy core aggregate + topGang.
    if Config.Stats.Gangs then
        stats.gangs.enabled = true
        pcall(function()
            local r = MySQL.single.await(
                'SELECT COUNT(*) AS c, COALESCE(SUM(vault_balance), 0) AS v FROM palm6_gangs')
            if r then
                stats.gangs.count = tonumber(r.c) or 0
                stats.gangs.cityVault = tonumber(r.v) or 0
            end
        end)
        pcall(function()
            stats.gangs.top = MySQL.query.await(
                'SELECT name, tag, rep FROM palm6_gangs ORDER BY rep DESC, name ASC LIMIT ?',
                { clamp(Config.TopGangs, 1, Config.MaxRows) }) or {}
        end)
    end

    -- Affiliated citizens = one row per gang membership.
    if Config.Stats.Members then
        stats.members.enabled = true
        pcall(function()
            local r = MySQL.single.await('SELECT COUNT(*) AS c FROM palm6_gang_members')
            stats.members.count = r and tonumber(r.c) or 0
        end)
    end

    -- Drug economy: dirty money moved + number of sales since the window.
    -- economy.ts sums all-time; the in-game surface windows on created_at, the
    -- same column palm6_drugs and palm6_season read.
    if Config.Stats.Drugs then
        stats.drugs.enabled = true
        pcall(function()
            local r = MySQL.single.await([[
                SELECT COUNT(*) AS c, COALESCE(SUM(net_dirty), 0) AS s
                FROM palm6_drugs_sales
                WHERE created_at >= NOW() - INTERVAL ? HOUR
            ]], { hours })
            if r then
                stats.drugs.saleCount = tonumber(r.c) or 0
                stats.drugs.dirtyMoved = tonumber(r.s) or 0
            end
        end)
    end

    -- Active warrants outstanding right now (point-in-time, ignores window).
    if Config.Stats.Warrants then
        stats.warrants.enabled = true
        pcall(function()
            local r = MySQL.single.await(
                "SELECT COUNT(*) AS c FROM palm6_mdt_warrants WHERE status = 'active'")
            stats.warrants.active = r and tonumber(r.c) or 0
        end)
    end

    return stats
end

-- Format a stats table into chat lines for /citystats.
local function statsLines(s)
    local lines = {}
    lines[#lines + 1] = '=== Palm6 City Stats ==='

    if s.gangs.enabled then
        lines[#lines + 1] = ('Gangs: %d registered, city vault $%s'):format(
            s.gangs.count, money(s.gangs.cityVault))
        if #s.gangs.top == 0 then
            lines[#lines + 1] = '  (no gangs founded yet)'
        else
            for i, g in ipairs(s.gangs.top) do
                lines[#lines + 1] = ('  %d. %s [%s], rep %d'):format(
                    i, trim(g.name ~= '' and g.name or '(unnamed)'),
                    trim(g.tag ~= '' and g.tag or '?'), tonumber(g.rep) or 0)
            end
        end
    end

    if s.members.enabled then
        lines[#lines + 1] = ('Affiliated citizens: %d'):format(s.members.count)
    end

    if s.drugs.enabled then
        lines[#lines + 1] = ('Dirty money moved (last %dh): $%s across %d sales'):format(
            s.windowHours, money(s.drugs.dirtyMoved), s.drugs.saleCount)
    end

    if s.warrants.enabled then
        lines[#lines + 1] = ('Active warrants: %d'):format(s.warrants.active)
    end

    if #lines == 1 then
        lines[#lines + 1] = '(no stats enabled)'
    end
    return lines
end

-- ---------------------------------------------------------------------------
-- /citystats [hours], any citizen (or console/admin), read-only, rate-limited
-- ---------------------------------------------------------------------------
local function cmdCityStats(src, args)
    if src ~= 0 and not rl(src, 'citystats') then
        Bridge.Notify(src, 'City Stats', 'Slow down a moment before checking again.', 'error')
        return
    end

    local hours = clamp(math.floor(tonumber(args[1]) or Config.Window.DefaultHours),
        Config.Window.MinHours, Config.Window.MaxHours)
    local s = buildStats(hours)
    Bridge.Reply(src, statsLines(s))
    dbg(('citystats pulled by %s over %dh'):format(
        src == 0 and 'console' or Bridge.GetPlayerName(src), hours))
end

-- ---------------------------------------------------------------------------
-- Commands + boot
-- ---------------------------------------------------------------------------
Bridge.RegisterCommand('citystats', function(source, args) cmdCityStats(source, args) end)

AddEventHandler('onResourceStart', function(resource)
    if resource ~= GetCurrentResourceName() then return end
    print('[palm6_citystats] read-only city stats online, /citystats (any citizen)')
end)

-- Read-only summary for devtest and future consumers. Signature frozen:
-- GetStats(hours) -> aggregate table (see buildStats).
exports('GetStats', function(hours)
    return buildStats(hours or Config.Window.DefaultHours)
end)
