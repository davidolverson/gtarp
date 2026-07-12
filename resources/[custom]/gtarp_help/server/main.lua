-- ============================================================================
-- gtarp_help/server/main.lua
--
-- Pure logic. Calls Bridge.* (bridge/sv_framework.lua) for all framework /
-- native access. No direct framework / native calls here (Section 6 gate).
--
-- A CURATED, static in-game command reference so players can discover the Palm6
-- custom systems. This resource owns no table, writes NOTHING, and reads NO
-- database at all: every line comes from Config (shared/config.lua). Two forms:
--   /help          -> the category list plus a preview of each category
--   /help <topic>  -> the full command detail for one category
-- The Admin category is appended only for server console and ace holders.
--
-- Rate-limit / Reply / IsAdmin pattern mirrors gtarp_citystats and gtarp_season.
-- ============================================================================

local lastAction = {}   -- [src] = { [key] = ts }

local function now() return os.time() end

local function dbg(msg)
    if Config.Debug then print('[gtarp_help] ' .. msg) end
end

-- Per-source cooldown, one entry per command key (gtarp_citystats idiom).
local function rl(src, key)
    local window = Config.RateLimits[key] or 1
    lastAction[src] = lastAction[src] or {}
    local t = now()
    if (lastAction[src][key] or 0) + window > t then return false end
    lastAction[src][key] = t
    return true
end

-- The categories this caller may see: always the public ones, plus the admin
-- ones when the caller is console or holds the ace.
local function visibleCategories(src)
    local out = {}
    for _, cat in ipairs(Config.Categories) do
        out[#out + 1] = cat
    end
    if Bridge.IsAdmin(src) then
        for _, cat in ipairs(Config.AdminCategories or {}) do
            out[#out + 1] = cat
        end
    end
    return out
end

-- Find a category by its typed key among the caller-visible set (case-insensitive).
local function findCategory(src, key)
    key = tostring(key or ''):lower()
    for _, cat in ipairs(visibleCategories(src)) do
        if cat.key == key then return cat end
    end
    return nil
end

-- The top-level list: one line per visible category with a short preview of its
-- first Config.TopPerCategory command names.
local function listLines(src)
    local lines = {}
    lines[#lines + 1] = '=== Palm6 Command Help ==='
    lines[#lines + 1] = 'Type /help [topic] for the full list in a category.'

    local top = Config.TopPerCategory or 4
    for _, cat in ipairs(visibleCategories(src)) do
        local names = {}
        for i, row in ipairs(cat.commands) do
            if i > top then break end
            names[#names + 1] = row.cmd
        end
        local preview = #names > 0 and (' e.g. ' .. table.concat(names, ', ')) or ''
        if #cat.commands > top then
            preview = preview .. ', ...'
        end
        lines[#lines + 1] = ('[%s] %s: %s%s'):format(cat.key, cat.label, cat.blurb, preview)
    end
    return lines
end

-- The detail for one category: header, blurb, then every command row.
local function detailLines(cat)
    local lines = {}
    lines[#lines + 1] = ('=== Help: %s ==='):format(cat.label)
    lines[#lines + 1] = cat.blurb
    for _, row in ipairs(cat.commands) do
        lines[#lines + 1] = ('%s  %s'):format(row.cmd, row.blurb)
    end
    return lines
end

-- ---------------------------------------------------------------------------
-- /help [topic], any citizen (or console/admin), read-only, rate-limited.
-- ---------------------------------------------------------------------------
local function cmdHelp(src, args)
    if src ~= 0 and not rl(src, 'help') then
        return
    end

    local topic = args and args[1]
    if topic and tostring(topic) ~= '' then
        local cat = findCategory(src, topic)
        if not cat then
            Bridge.Reply(src, {
                ('No help topic named "%s". Type /help to see the topics.'):format(tostring(topic)),
            })
            return
        end
        Bridge.Reply(src, detailLines(cat))
        dbg(('help topic %s pulled by %s'):format(
            cat.key, src == 0 and 'console' or Bridge.GetPlayerName(src)))
        return
    end

    Bridge.Reply(src, listLines(src))
    dbg(('help list pulled by %s'):format(
        src == 0 and 'console' or Bridge.GetPlayerName(src)))
end

-- ---------------------------------------------------------------------------
-- Commands + boot
-- ---------------------------------------------------------------------------
Bridge.RegisterCommand('help', function(source, args) cmdHelp(source, args) end)

AddEventHandler('onResourceStart', function(resource)
    if resource ~= GetCurrentResourceName() then return end
    print('[gtarp_help] command reference online, /help (any citizen)')
end)
