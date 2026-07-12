-- ============================================================================
-- gtarp_wanted/server/main.lua
--
-- Pure logic. Calls Bridge.* (bridge/sv_framework.lua) for all framework /
-- native access. No direct framework / native calls here (Section 6 gate).
--
-- READ-ONLY, PLAYER-FACING civic visibility. This resource creates NO tables
-- and writes NOTHING. It runs parameterized, LIMIT-capped SELECTs over tables
-- other resources own and presents them:
--   - gtarp_mdt_warrants     (0023): open orders naming a citizen. Columns
--                            citizenid, citizen_name, reason, status
--                            ENUM('active','served','dropped'), created_at.
--                            (Warrants have no 'charges' column, the free-text
--                            field is 'reason'.)
--   - gtarp_bounty_contracts (0027): posted bounties. Columns kind
--                            ENUM('state','private'), target_citizenid,
--                            target_name, amount, reason, status
--                            ENUM('active','claimed','cancelled','expired'),
--                            created_at.
--   - gtarp_mdt_bolos        (0022): be-on-the-lookout notices. Columns
--                            citizenid, body, created_at, expires_at,
--                            resolved_at. Active = resolved_at IS NULL AND
--                            expires_at > NOW() (BOLOs have no name column, so
--                            they surface only in the caller's own self-check,
--                            keyed by the caller's citizenid, never on the
--                            public board).
--
-- /wanted    : public most-wanted board, no gate, rate-limited, read-only.
-- /amiwanted : the caller's own records only (scoped by their citizenid),
--              rate-limited, read-only.
-- Every section is pcall-wrapped so a missing table/column yields an empty
-- section rather than an error.
-- ============================================================================

local lastAction = {}   -- [src] = { [key] = ts }

local function now() return os.time() end

local function dbg(msg)
    if Config.Debug then print('[gtarp_wanted] ' .. msg) end
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

-- A display name for the public board, honouring the Config.ShowNames flag.
local function publicName(name)
    if not Config.ShowNames then return Config.WithheldLabel end
    name = tostring(name or ''):gsub('^%s+', ''):gsub('%s+$', '')
    if name == '' then return '(unknown)' end
    return trim(name)
end

-- Money for display. amount is an unsigned int in the schema.
local function money(v)
    return ('$%d'):format(math.floor(tonumber(v) or 0))
end

-- ---------------------------------------------------------------------------
-- Public most-wanted board. Read-only aggregate, each section pcall-wrapped.
-- Returns a plain table (safe to hand to callers via the GetBoard export).
-- ---------------------------------------------------------------------------
local function buildBoard()
    local board = {
        warrants = {},
        bounties = {},
    }

    -- Top active warrants, newest first (warrants carry no amount to rank by).
    pcall(function()
        board.warrants = MySQL.query.await([[
            SELECT id, citizen_name, reason,
                   TIMESTAMPDIFF(HOUR, created_at, NOW()) AS age_h
            FROM gtarp_mdt_warrants
            WHERE status = 'active'
            ORDER BY created_at DESC, id DESC
            LIMIT ?
        ]], { clamp(Config.Board.Warrants, 1, Config.Board.MaxRows) }) or {}
    end)

    -- Top active bounties, highest amount first.
    pcall(function()
        board.bounties = MySQL.query.await([[
            SELECT id, target_name, amount, reason, kind,
                   TIMESTAMPDIFF(HOUR, created_at, NOW()) AS age_h
            FROM gtarp_bounty_contracts
            WHERE status = 'active'
            ORDER BY amount DESC, created_at DESC, id DESC
            LIMIT ?
        ]], { clamp(Config.Board.Bounties, 1, Config.Board.MaxRows) }) or {}
    end)

    return board
end

-- Format the public board into chat lines for /wanted.
local function boardLines(b)
    local lines = {}
    lines[#lines + 1] = ('=== %s ==='):format(Config.Framing.BoardTitle)

    lines[#lines + 1] = ('%s (%d):'):format(Config.Framing.WarrantsTitle, #b.warrants)
    if #b.warrants == 0 then
        lines[#lines + 1] = '  (no active warrants)'
    else
        for _, w in ipairs(b.warrants) do
            lines[#lines + 1] = ('  #%d %s, %s [%dh ago]'):format(
                w.id, publicName(w.citizen_name), trim(w.reason), tonumber(w.age_h) or 0)
        end
    end

    lines[#lines + 1] = ('%s (%d):'):format(Config.Framing.BountiesTitle, #b.bounties)
    if #b.bounties == 0 then
        lines[#lines + 1] = '  (no open bounties)'
    else
        for _, y in ipairs(b.bounties) do
            lines[#lines + 1] = ('  #%d %s, %s (%s)%s'):format(
                y.id, publicName(y.target_name), money(y.amount),
                (y.kind == 'state') and 'state' or 'private',
                (y.reason and y.reason ~= '') and (' - ' .. trim(y.reason)) or '')
        end
    end

    return lines
end

-- ---------------------------------------------------------------------------
-- Personal self-check. Scoped to the caller's own citizenid. Read-only, each
-- section pcall-wrapped. Returns a plain table.
-- ---------------------------------------------------------------------------
local function buildSelf(citizenid)
    local self = {
        warrants = {},
        bounties = {},
        bolos    = {},
    }

    pcall(function()
        self.warrants = MySQL.query.await([[
            SELECT id, reason,
                   TIMESTAMPDIFF(HOUR, created_at, NOW()) AS age_h
            FROM gtarp_mdt_warrants
            WHERE citizenid = ? AND status = 'active'
            ORDER BY created_at DESC, id DESC
            LIMIT ?
        ]], { citizenid, clamp(Config.Self.Warrants, 1, Config.Self.MaxRows) }) or {}
    end)

    pcall(function()
        self.bounties = MySQL.query.await([[
            SELECT id, amount, reason, kind,
                   TIMESTAMPDIFF(HOUR, created_at, NOW()) AS age_h
            FROM gtarp_bounty_contracts
            WHERE target_citizenid = ? AND status = 'active'
            ORDER BY amount DESC, created_at DESC, id DESC
            LIMIT ?
        ]], { citizenid, clamp(Config.Self.Bounties, 1, Config.Self.MaxRows) }) or {}
    end)

    pcall(function()
        self.bolos = MySQL.query.await([[
            SELECT id, body,
                   TIMESTAMPDIFF(HOUR, created_at, NOW()) AS age_h
            FROM gtarp_mdt_bolos
            WHERE citizenid = ? AND resolved_at IS NULL AND expires_at > NOW()
            ORDER BY created_at DESC, id DESC
            LIMIT ?
        ]], { citizenid, clamp(Config.Self.Bolos, 1, Config.Self.MaxRows) }) or {}
    end)

    return self
end

-- Format the self-check into chat lines for /amiwanted.
local function selfLines(s)
    local lines = {}
    lines[#lines + 1] = ('=== %s ==='):format(Config.Framing.SelfTitle)

    local total = #s.warrants + #s.bounties + #s.bolos
    if total == 0 then
        lines[#lines + 1] = '  ' .. Config.Framing.Clean
        return lines
    end

    lines[#lines + 1] = ('Warrants (%d):'):format(#s.warrants)
    for _, w in ipairs(s.warrants) do
        lines[#lines + 1] = ('  #%d %s [%dh ago]'):format(
            w.id, trim(w.reason), tonumber(w.age_h) or 0)
    end

    lines[#lines + 1] = ('Bounties on you (%d):'):format(#s.bounties)
    for _, y in ipairs(s.bounties) do
        lines[#lines + 1] = ('  #%d %s (%s)%s'):format(
            y.id, money(y.amount),
            (y.kind == 'state') and 'state' or 'private',
            (y.reason and y.reason ~= '') and (' - ' .. trim(y.reason)) or '')
    end

    lines[#lines + 1] = ('BOLOs (%d):'):format(#s.bolos)
    for _, o in ipairs(s.bolos) do
        lines[#lines + 1] = ('  #%d %s [%dh ago]'):format(
            o.id, trim(o.body), tonumber(o.age_h) or 0)
    end

    return lines
end

-- ---------------------------------------------------------------------------
-- /wanted, public most-wanted board. No gate, rate-limited, read-only.
-- ---------------------------------------------------------------------------
local function cmdWanted(src, _args)
    if src ~= 0 and not rl(src, 'wanted') then return end
    local b = buildBoard()
    Bridge.Reply(src, boardLines(b))
    dbg(('board pulled by %s'):format(src == 0 and 'console' or Bridge.GetPlayerName(src)))
end

-- ---------------------------------------------------------------------------
-- /amiwanted, the caller's own wanted status. Needs a citizenid, so the server
-- console (no character) cannot run it. Rate-limited, read-only.
-- ---------------------------------------------------------------------------
local function cmdAmIWanted(src, _args)
    if src == 0 then
        print('[gtarp_wanted] /amiwanted is a character self-check, run it in-game.')
        return
    end
    if not rl(src, 'amiwanted') then return end
    local citizenid = Bridge.GetCitizenId(src)
    if not citizenid then
        Bridge.Notify(src, 'Wanted', 'Could not read your character. Try again in a moment.', 'error')
        return
    end
    local s = buildSelf(citizenid)
    Bridge.Reply(src, selfLines(s))
    dbg(('self-check pulled by %s'):format(Bridge.GetPlayerName(src)))
end

-- ---------------------------------------------------------------------------
-- Commands + boot
-- ---------------------------------------------------------------------------
Bridge.RegisterCommand('wanted', function(source, args) cmdWanted(source, args) end)
Bridge.RegisterCommand('amiwanted', function(source, args) cmdAmIWanted(source, args) end)

AddEventHandler('onResourceStart', function(resource)
    if resource ~= GetCurrentResourceName() then return end
    print('[gtarp_wanted] read-only wanted board online, /wanted (public), /amiwanted (self)')
end)

-- Read-only public board for devtest and future consumers. Signature frozen:
-- GetBoard() -> { warrants = {...}, bounties = {...} } (see buildBoard).
exports('GetBoard', function()
    return buildBoard()
end)
