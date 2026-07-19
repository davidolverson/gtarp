-- ============================================================================
-- palm6_fc_progression/server/main.lua
--
-- Rep / rank / unlock ledger for the fight club. Consumes the server-internal
-- seam fc:match:resolved (fired by palm6_fightclub after settleMatch). Rep is
-- DISPLAY/RANK ONLY — it pays no cash and unlocks only cosmetic/name variants
-- (styles are stat-identical, §8/§9), so farm->money is severed at the source.
--
-- Money-safety idioms mirror palm6_fightclub's settleMatch:
--   * atomic claim-before-credit: UPDATE ... SET rep_awarded=1 WHERE
--     rep_awarded=0 AND is_pve=0 (affected==1 gates) — exactly one award ever.
--   * a crash in the claim->credit window strands ONE award (never double-pays).
--   * boot reconcile re-drives status='resolved' AND rep_awarded=0 rows.
-- The is_pve=0 gate is load-bearing: PvP (this file) and the PvE §19.5 path
-- share ONE seam + ONE rep_awarded column; without it a CPU win would mint the
-- full RepPerPvpWin past every cap and try to credit the '__CPU__' sentinel.
-- ============================================================================

-- Rank bands (rep -> rank_tier). Resource-internal + tunable in feel-test; rep
-- is cash-neutral so these bands only drive the HUD career badge (T9).
local RANK_THRESHOLDS = { 300, 800, 1600, 3000, 5000 }

-- Config (from fc_core, isolated Lua state -> read via export). Cached on first
-- award; loadConf is idempotent and cheap.
local RepPerPvpWin, RepCooldownSec, DailyRepCap, DailyDistinctOpponentCap, LoserConsolation

local function loadConf()
    local ok, FC = pcall(function() return exports.palm6_fc_core:Config() end)
    if not ok or type(FC) ~= 'table' then
        -- fc_core not up yet: fall back to the spec anchors so a claim never
        -- silently no-ops on missing config (still cash-neutral).
        RepPerPvpWin, RepCooldownSec = 100, 3600
        DailyRepCap, DailyDistinctOpponentCap, LoserConsolation = 5, 4, 0
        return
    end
    local R = FC.Rep or {}
    RepPerPvpWin             = tonumber(FC.RepPerPvpWin) or 100
    RepCooldownSec           = tonumber(R.RepCooldownSec) or 3600
    DailyRepCap              = tonumber(R.DailyRepCap) or 5
    DailyDistinctOpponentCap = tonumber(R.DailyDistinctOpponentCap) or 4
    LoserConsolation         = tonumber(R.LoserConsolation) or 0
end

local function dbg(msg)
    print('[palm6_fc_progression] ' .. msg)
end

-- Reserved sentinel guard: reject any non-string cid or a '__'-prefixed cid
-- (e.g. '__CPU__') so a mis-plumbed seam can never create a phantom row.
local function isReserved(cid)
    return type(cid) ~= 'string' or cid == '' or cid:sub(1, 2) == '__'
end

local function rankForRep(rep)
    rep = tonumber(rep) or 0
    local tier = 0
    for i = 1, #RANK_THRESHOLDS do
        if rep >= RANK_THRESHOLDS[i] then tier = i else break end
    end
    return tier
end

local function scalarCount(sql, params)
    local n = 0
    pcall(function()
        local r = MySQL.single.await(sql, params)
        if r then n = tonumber(r.n) or 0 end
    end)
    return n
end

-- ---------------------------------------------------------------------------
-- Ledger writers (upsert; row may not exist yet)
-- ---------------------------------------------------------------------------
local function bumpWin(cid)
    pcall(function()
        MySQL.insert.await([[
            INSERT INTO palm6_fc_progression (citizenid, rep, wins, losses, rank_tier)
            VALUES (?, 0, 1, 0, 0)
            ON DUPLICATE KEY UPDATE wins = wins + 1
        ]], { cid })
    end)
end

local function bumpLoss(cid)
    pcall(function()
        MySQL.insert.await([[
            INSERT INTO palm6_fc_progression (citizenid, rep, wins, losses, rank_tier)
            VALUES (?, 0, 0, 1, 0)
            ON DUPLICATE KEY UPDATE losses = losses + 1
        ]], { cid })
    end)
end

-- rep += amount, then recompute rank_tier off the new total.
local function addRep(cid, amount)
    if not amount or amount <= 0 then return end
    pcall(function()
        MySQL.insert.await([[
            INSERT INTO palm6_fc_progression (citizenid, rep, wins, losses, rank_tier)
            VALUES (?, ?, 0, 0, 0)
            ON DUPLICATE KEY UPDATE rep = rep + VALUES(rep)
        ]], { cid, amount })
    end)
    local newRep = amount
    pcall(function()
        local r = MySQL.single.await("SELECT rep FROM palm6_fc_progression WHERE citizenid = ?", { cid })
        if r then newRep = tonumber(r.rep) or amount end
    end)
    pcall(function()
        MySQL.update.await("UPDATE palm6_fc_progression SET rank_tier = ? WHERE citizenid = ?",
            { rankForRep(newRep), cid })
    end)
end

-- Shared cross-mode daily counter (contract-mandated for the future PvE path).
-- Incremented BEFORE the rep credit so a crash biases against the grinder.
local function bumpDaily(winnerCid)
    pcall(function()
        MySQL.insert.await([[
            INSERT INTO palm6_fc_daily (citizenid, day_bucket, pvp_rep_wins, pve_rep_wins, distinct_opponents)
            VALUES (?, ?, 1, 0, 0)
            ON DUPLICATE KEY UPDATE pvp_rep_wins = pvp_rep_wins + 1
        ]], { winnerCid, os.date('!%Y-%m-%d') })
    end)
end

-- ---------------------------------------------------------------------------
-- Anti-farm reads — all off palm6_fightclub_matches.resolved_at (true rolling
-- window; the current match is excluded by id, since we already claimed it
-- rep_awarded=1 before these run).
-- ---------------------------------------------------------------------------
local function wonAgainstWithin(matchId, winnerCid, loserCid, seconds)
    local row
    pcall(function()
        row = MySQL.single.await([[
            SELECT id FROM palm6_fightclub_matches
             WHERE id <> ? AND status = 'resolved' AND is_pve = 0 AND rep_awarded = 1
               AND winner_citizenid = ?
               AND (fighter1_citizenid = ? OR fighter2_citizenid = ?)
               AND resolved_at >= (NOW() - INTERVAL ? SECOND)
             LIMIT 1
        ]], { matchId, winnerCid, loserCid, loserCid, seconds })
    end)
    return row ~= nil
end

-- Returns (repAmount, reason). repAmount==0 => capped (reason logged/notified).
local function repToAward(matchId, winnerCid, loserCid)
    -- (b) same-opponent 1h cooldown
    if wonAgainstWithin(matchId, winnerCid, loserCid, RepCooldownSec) then
        return 0, 'cooldown'
    end
    -- (d) daily rep cap — rolling 24h count of this winner's rep-granted PvP wins
    local wins24 = scalarCount([[
        SELECT COUNT(*) AS n FROM palm6_fightclub_matches
         WHERE id <> ? AND status = 'resolved' AND is_pve = 0 AND rep_awarded = 1
           AND winner_citizenid = ?
           AND resolved_at >= (NOW() - INTERVAL 24 HOUR)
    ]], { matchId, winnerCid })
    if wins24 >= DailyRepCap then return 0, 'daily-cap' end
    -- (d) distinct-opponent cap — only blocks a NEW opponent (a re-beat inside
    -- 24h is already governed by wins24 above).
    if not wonAgainstWithin(matchId, winnerCid, loserCid, 86400) then
        local distinctOpp = scalarCount([[
            SELECT COUNT(DISTINCT CASE WHEN fighter1_citizenid = ?
                        THEN fighter2_citizenid ELSE fighter1_citizenid END) AS n
              FROM palm6_fightclub_matches
             WHERE id <> ? AND status = 'resolved' AND is_pve = 0 AND rep_awarded = 1
               AND winner_citizenid = ?
               AND resolved_at >= (NOW() - INTERVAL 24 HOUR)
        ]], { winnerCid, matchId, winnerCid })
        if distinctOpp >= DailyDistinctOpponentCap then return 0, 'distinct-cap' end
    end
    return RepPerPvpWin, 'ok'
end

-- ---------------------------------------------------------------------------
-- Award driver — atomic claim, authoritative re-read, ledger, gated rep.
-- Called by the seam handler AND boot reconcile (seam payload ignored for
-- everything money-adjacent; DB row is authority).
-- ---------------------------------------------------------------------------
local function awardRep(matchId)
    loadConf()

    -- 1. atomic claim: PvP only, exactly once. Gates re-fire + PvE rows.
    local claimed = false
    pcall(function()
        claimed = MySQL.update.await(
            "UPDATE palm6_fightclub_matches SET rep_awarded = 1 WHERE id = ? AND rep_awarded = 0 AND is_pve = 0",
            { matchId }) == 1
    end)
    if not claimed then return end

    -- 2. authoritative resolved row
    local m
    pcall(function()
        m = MySQL.single.await([[
            SELECT winner_citizenid, method, fighter1_citizenid, fighter2_citizenid
              FROM palm6_fightclub_matches WHERE id = ? AND status = 'resolved'
        ]], { matchId })
    end)
    if not m then return end

    local winnerCid = m.winner_citizenid
    local method    = m.method or ''
    -- (c) decisive-only: draw/void produce no winner; forfeit has a winner but
    -- pays NO rep (spec §9c) AND (F10) NO win/loss ledger bump — a forfeit is
    -- uncapped (no pairing-cooldown / daily gate in front of it), so bumping the
    -- ledger on it lets an alt/collusion forfeit-loop farm the win/loss stats.
    local decisive = winnerCid and (method == 'ko' or method == 'finisher' or method == 'forfeit')
    if not decisive then return end
    if isReserved(winnerCid) then
        dbg(('match #%d: winner cid reserved (%s) — no rep'):format(matchId, tostring(winnerCid)))
        return
    end

    local loserCid = (m.fighter1_citizenid == winnerCid) and m.fighter2_citizenid or m.fighter1_citizenid

    -- ledger: ONLY the clean decisive results (ko/finisher). Never forfeit (F10).
    -- Rank is rep-derived, so skipping the forfeit bump keeps rank honest too.
    if method == 'ko' or method == 'finisher' then
        bumpWin(winnerCid)
        if loserCid and not isReserved(loserCid) then bumpLoss(loserCid) end
    end

    -- rep only on a clean decisive result (never forfeit/draw/void)
    if method == 'forfeit' or not loserCid or isReserved(loserCid) then return end

    local repAmount, reason = repToAward(matchId, winnerCid, loserCid)
    if repAmount > 0 then
        bumpDaily(winnerCid)          -- increment-before-credit
        addRep(winnerCid, repAmount)
        local ws = Bridge.GetSourceByCitizenId(winnerCid)
        if ws then
            Bridge.Notify(ws, 'Fight Club',
                ('+%d rep for the win.'):format(repAmount), 'success')
        end
        dbg(('match #%d: %s +%d rep (win over %s)'):format(matchId, winnerCid, repAmount, loserCid))
    else
        local ws = Bridge.GetSourceByCitizenId(winnerCid)
        if ws then
            Bridge.Notify(ws, 'Fight Club',
                'Win recorded — no rep (' .. reason .. ').', 'inform')
        end
        dbg(('match #%d: %s win recorded, rep skipped (%s)'):format(matchId, winnerCid, reason))
    end

    -- optional loser consolation (0 in MVP; same-opponent gated per spec §9b)
    if LoserConsolation > 0 and not wonAgainstWithin(matchId, winnerCid, loserCid, RepCooldownSec) then
        addRep(loserCid, LoserConsolation)
    end
end

-- ---------------------------------------------------------------------------
-- Seam consumer — server-internal event, NEVER RegisterNetEvent.
-- ---------------------------------------------------------------------------
AddEventHandler('fc:match:resolved', function(d)
    if type(d) ~= 'table' then return end
    local matchId = tonumber(d.matchId)
    if not matchId then return end
    awardRep(matchId)
end)

-- ---------------------------------------------------------------------------
-- Boot reconcile — re-drive post-deploy matches whose rep award never landed
-- (crash between the seam fire and the credit). Idempotent via the claim gate.
-- Delayed so palm6_dbmigrate has created the tables + columns (mirror
-- fightclub's Wait(8000)); DEFAULT 1 on rep_awarded backfills history as done.
-- ---------------------------------------------------------------------------
AddEventHandler('onResourceStart', function(resource)
    if resource ~= GetCurrentResourceName() then return end
    CreateThread(function()
        Wait(8000)
        local pending = {}
        pcall(function()
            pending = MySQL.query.await(
                "SELECT id FROM palm6_fightclub_matches WHERE status = 'resolved' AND rep_awarded = 0 AND is_pve = 0") or {}
        end)
        for _, row in ipairs(pending) do
            awardRep(row.id)
        end
        if #pending > 0 then
            print(('[palm6_fc_progression] boot reconcile awarded rep for %d match(es)'):format(#pending))
        end
    end)
end)

-- ---------------------------------------------------------------------------
-- Exports (server-only) — consumed by T9 HUD career panel + future unlock UI.
-- ---------------------------------------------------------------------------
exports('GetRep', function(citizenid)
    local r
    pcall(function()
        r = MySQL.single.await("SELECT rep FROM palm6_fc_progression WHERE citizenid = ?", { citizenid })
    end)
    return r and tonumber(r.rep) or 0
end)

exports('GetRank', function(citizenid)
    local r
    pcall(function()
        r = MySQL.single.await("SELECT rank_tier FROM palm6_fc_progression WHERE citizenid = ?", { citizenid })
    end)
    return r and tonumber(r.rank_tier) or 0
end)

exports('HasUnlock', function(citizenid, unlockId)
    local r
    pcall(function()
        r = MySQL.single.await(
            "SELECT 1 AS ok FROM palm6_fc_unlocks WHERE citizenid = ? AND unlock_id = ? LIMIT 1",
            { citizenid, unlockId })
    end)
    return r ~= nil
end)
