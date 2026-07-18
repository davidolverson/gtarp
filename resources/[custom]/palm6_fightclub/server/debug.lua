-- ============================================================================
-- palm6_fightclub/server/debug.lua
--
-- Ace-gated dev harness (spec §14). Drives the match lifecycle by calling the
-- money exports from server/main.lua (OpenMatch/GoLive/ResolveMatch/VoidMatch)
-- so betting (T3), progression (T5) and the HUD (T9) are exercisable BEFORE
-- fc_combat (T6) exists. Isolated in its own file so it never conflicts with
-- main.lua's rewrite.
--
-- Gating: NOT Bridge.RegisterCommand (which would leave restricted=false and
-- rely on nothing) — registered raw and gated in-handler with IsPlayerAceAllowed
-- against 'palm6_fc.debug'. Server console (src == 0) always passes the gate
-- (it also has no ped, so it never charges antes — the two fighter cids do).
--
-- ONLY /fcdebug open moves money: it charges BOTH antes up front (§10b) and
-- refunds BOTH if OpenMatch returns nil OR throws. The export call is pcall-
-- wrapped so a throw after the charge can never strand the antes.
-- ============================================================================

local FC_ACE = 'palm6_fc.debug'

-- Self-contained rate-limit (main.lua's rl() is a file-local, not visible here).
local lastDebug = {}
local function drl(src)
    local window = (Config.RateLimits and Config.RateLimits.fcdebug) or 1
    local t = os.time()
    if (lastDebug[src] or 0) + window > t then return false end
    lastDebug[src] = t
    return true
end

-- Default style/fighter live in fc_core (config authority). pcall-guarded with
-- literal fallbacks so the stub still opens matches if fc_core is momentarily
-- unstarted (boot-order race / isolated testing).
local function debugDefaults()
    local styleDef, fighterDef = 'brawler', 'house_ace'
    local ok, core = pcall(function() return exports.palm6_fc_core:Config() end)
    if ok and type(core) == 'table' then
        styleDef   = core.DefaultStyle   or styleDef
        fighterDef = core.DefaultFighter or fighterDef
    end
    return styleDef, fighterDef
end

-- /fcdebug open <cidA> <cidB>
local function subOpen(src, args)
    local cidA, cidB = args[2], args[3]
    if not cidA or not cidB then
        Bridge.Reply(src, { 'usage: /fcdebug open <cidA> <cidB>' })
        return
    end
    if cidA == cidB then
        Bridge.Reply(src, { 'fighters must be two different citizenids' })
        return
    end

    local stake = Config.Fight.EntryStake or 0

    -- Charge-before-grant (§10b). Antes come from the two fighter cids, never
    -- the invoker. Both must be online to be charged; refund A if B can't pay.
    if stake > 0 then
        local srcA = Bridge.GetSourceByCitizenId(cidA)
        local srcB = Bridge.GetSourceByCitizenId(cidB)
        if not srcA then
            Bridge.Reply(src, { ('cidA %s is offline — cannot charge the $%d ante'):format(cidA, stake) })
            return
        end
        if not srcB then
            Bridge.Reply(src, { ('cidB %s is offline — cannot charge the $%d ante'):format(cidB, stake) })
            return
        end
        if not Bridge.ChargeBank(srcA, stake, 'fightclub-entry') then
            Bridge.Reply(src, { ('cidA %s cannot cover the $%d ante'):format(cidA, stake) })
            return
        end
        if not Bridge.ChargeBank(srcB, stake, 'fightclub-entry') then
            Bridge.CreditBankByCitizenId(cidA, stake, 'fightclub-entry-refund')
            Bridge.Reply(src, { ('cidB %s cannot cover the $%d ante — refunded cidA'):format(cidB, stake) })
            return
        end
    end

    local styleDef, fighterDef = debugDefaults()
    local ok, matchId = pcall(function()
        return exports.palm6_fightclub:OpenMatch(cidA, cidB, styleDef, styleDef, fighterDef, fighterDef, stake)
    end)

    -- nil return (INSERT-fail) OR throw (export missing during rollout): refund
    -- BOTH antes — mirrors OpenMatch's own both-ante refund contract.
    if not ok or not matchId then
        if stake > 0 then
            Bridge.CreditBankByCitizenId(cidA, stake, 'fightclub-entry-refund')
            Bridge.CreditBankByCitizenId(cidB, stake, 'fightclub-entry-refund')
        end
        Bridge.Reply(src, { ('OpenMatch failed (%s) — both antes refunded')
            :format(ok and 'INSERT returned nil' or 'export threw') })
        return
    end

    Bridge.Reply(src, { ('opened match #%d: %s vs %s (style=%s fighter=%s stake $%d, betting %ds)')
        :format(matchId, cidA, cidB, styleDef, fighterDef, stake, Config.Betting.WindowSec) })
end

-- /fcdebug live <matchId>
local function subLive(src, args)
    local matchId = tonumber(args[2])
    if not matchId then Bridge.Reply(src, { 'usage: /fcdebug live <matchId>' }); return end
    local ok, res = pcall(function() return exports.palm6_fightclub:GoLive(matchId) end)
    if not ok then Bridge.Reply(src, { 'GoLive threw (is T3 merged?)' }); return end
    Bridge.Reply(src, { res
        and ('match #%d -> LIVE (betting closed)'):format(matchId)
        or  ('match #%d not in betting state — no-op'):format(matchId) })
end

-- /fcdebug resolve <matchId> <winnerCid>
local function subResolve(src, args)
    local matchId = tonumber(args[2])
    local winnerCid = args[3]
    if not matchId or not winnerCid then
        Bridge.Reply(src, { 'usage: /fcdebug resolve <matchId> <winnerCid>' })
        return
    end
    local ok, res = pcall(function() return exports.palm6_fightclub:ResolveMatch(matchId, winnerCid, 'ko') end)
    if not ok then Bridge.Reply(src, { 'ResolveMatch threw (is T3 merged?)' }); return end
    Bridge.Reply(src, { res
        and ('match #%d -> RESOLVED, winner %s (method=ko), settled'):format(matchId, winnerCid)
        or  ('match #%d not live — no-op'):format(matchId) })
end

-- /fcdebug void <matchId>
local function subVoid(src, args)
    local matchId = tonumber(args[2])
    if not matchId then Bridge.Reply(src, { 'usage: /fcdebug void <matchId>' }); return end
    local ok, res = pcall(function() return exports.palm6_fightclub:VoidMatch(matchId) end)
    if not ok then Bridge.Reply(src, { 'VoidMatch threw (is T3 merged?)' }); return end
    Bridge.Reply(src, { res
        and ('match #%d -> VOID (betting aborted, bets refunded)'):format(matchId)
        or  ('match #%d not in betting state — no-op'):format(matchId) })
end

RegisterCommand('fcdebug', function(src, args)
    -- Ace gate FIRST line (§14). Console (src == 0) bypasses the gate.
    if src ~= 0 and not IsPlayerAceAllowed(src, FC_ACE) then return end
    if src ~= 0 and not drl(src) then return end

    local sub = args[1]
    if sub == 'open' then
        subOpen(src, args)
    elseif sub == 'live' then
        subLive(src, args)
    elseif sub == 'resolve' then
        subResolve(src, args)
    elseif sub == 'void' then
        subVoid(src, args)
    else
        Bridge.Reply(src, {
            'fcdebug (ace: palm6_fc.debug) — dev lifecycle driver:',
            '  open <cidA> <cidB>        open a betting match (charges both antes)',
            '  live <matchId>            close betting -> LIVE',
            '  resolve <matchId> <cid>   resolve LIVE -> winner cid (method=ko)',
            '  void <matchId>            abort a BETTING match (refund bets)',
        })
    end
end, false)
