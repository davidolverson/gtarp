-- ============================================================================
-- palm6_tips/server/main.lua
--
-- Pure logic. Calls Bridge.* (bridge/sv_framework.lua) for all framework /
-- native access. No direct framework / native calls here (§6 gate).
--
-- Anonymous payphone tips. /tip [text] works only within reach of a
-- configured payphone (server-checked position); the tip lands on the
-- police 911 log via palm6_mdt's LogCall export with NO identity
-- attached — deliberately. The cost of anonymity is physical: you have
-- to walk to the phone, and anyone watching the street sees you make
-- the call. Cooldowns are per-citizen (in memory only — nothing about
-- the tipper is ever written anywhere).
-- ============================================================================

local lastAction = {}   -- [src] = ts, anti-spam floor
local lastTip = {}      -- [citizenid] = ts, the real cooldown

local function now() return os.time() end

local function dbg(msg)
    if Config.Debug then print('[palm6_tips] ' .. msg) end
end

local function nearestPayphone(pos)
    local best, bestDist
    for _, p in ipairs(Config.Payphones) do
        local d = Bridge.Distance(pos, p)
        if d <= Config.PayphoneRadius and (not bestDist or d < bestDist) then
            best, bestDist = p, d
        end
    end
    return best
end

local function cmdTip(src, args)
    if src == 0 then return end
    local t = now()
    if (lastAction[src] or 0) + Config.RateLimits.tip > t then return end
    lastAction[src] = t

    local cid = Bridge.GetCitizenId(src)
    if not cid then return end
    if not Bridge.ResourceStarted('palm6_mdt') then
        Bridge.Notify(src, 'Payphone', 'The line is dead.', 'error')
        return
    end

    local pos = Bridge.GetCoords(src)
    local phone = pos and nearestPayphone(pos)
    if not phone then
        Bridge.Notify(src, 'Payphone', 'You need to be at a payphone to call in a tip.', 'error')
        return
    end

    if (lastTip[cid] or 0) + Config.Tip.PerCitizenCd > t then
        Bridge.Notify(src, 'Payphone', 'The line clicks — the tip desk needs a breather. Try later.', 'error')
        return
    end

    local text = table.concat(args, ' '):gsub('^%s+', ''):gsub('%s+$', '')
    if #text < Config.Tip.MinChars or #text > Config.Tip.MaxChars then
        Bridge.Notify(src, 'Payphone',
            ('A tip needs %d-%d characters. Usage: /tip [what you saw]')
            :format(Config.Tip.MinChars, Config.Tip.MaxChars), 'error')
        return
    end

    -- The log entry carries the PAYPHONE's coords (where the call came
    -- from), never the tipper's identity.
    local logged = false
    pcall(function()
        logged = exports.palm6_mdt:LogCall(Config.Tip.Prefix .. text, phone, 'anonymous') == true
    end)
    if not logged then
        Bridge.Notify(src, 'Payphone', 'The line is dead.', 'error')
        return
    end
    lastTip[cid] = t

    Bridge.Notify(src, 'Payphone', 'You hang up. The tip is in.', 'success')
    if Config.Tip.NotifyPolice then
        Bridge.NotifyPolice('Tip line', 'A tip just came in — /calls to read it.', 'inform')
    end
    dbg('tip logged')
end

-- ---------------------------------------------------------------------------
-- Commands + boot
-- ---------------------------------------------------------------------------
Bridge.RegisterCommand('tip', function(source, args) cmdTip(source, args) end)

AddEventHandler('onResourceStart', function(resource)
    if resource ~= GetCurrentResourceName() then return end
    print(('[palm6_tips] tip line open — %d payphone(s); 911 log %s')
        :format(#Config.Payphones,
            Bridge.ResourceStarted('palm6_mdt') and 'ONLINE' or 'offline'))
end)

---Payphone count for devtest (this resource keeps no state of its own —
---tips live in palm6_mdt's call log, anonymously).
exports('GetSummary', function()
    return { payphones = #Config.Payphones }
end)
