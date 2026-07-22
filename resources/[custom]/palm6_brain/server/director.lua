-- ============================================================================
-- palm6_brain/server/director.lua — Phase 2b: THE AI DIRECTOR (spine, dry-run).
--
-- ONE batched, low-frequency, server-side LLM call assigns every NPC a single
-- goal from a CLOSED action enum. The model only ever picks a verb + typed args;
-- three validation layers (shape → referential → legality) run BEFORE anything
-- happens, so the model literally cannot name an action or target we did not
-- define. See docs/AI-NPC-ROADMAP.md §"On-rails AI".
--
-- 🔒 WHAT THIS FILE DOES *NOT* DO (by design, this slice):
--   • It never spawns or moves a ped        (actuation = a later gated slice)
--   • It never moves money                   (Config.Director.MoneyEnabled gate)
--   • It never calls police dispatch         (Config.Director.CrimeEnabled gate)
-- It is the PLANNING + GOAL-STATE spine. In DRY-RUN (the default) accepted
-- actions are logged — "Tony WOULD goTo Legion Square" — and discarded. With
-- DryRun off they are COMMITTED to the goal store (one per NPC, TTL-expiring) and
-- broadcast on `palm6_brain:goal` for a future client executor to actuate — but
-- that broadcast has no consumer yet, so even then no ped moves. Only gate-passed
-- verbs are ever committed, so the store can never hold a money/crime goal while
-- those gates are off. This proves the batched-LLM → schema → validate → commit →
-- degrade pipeline end-to-end before any actuation, money, or dispatch exists.
--
-- The ACTIONS registry below is the SINGLE SOURCE OF TRUTH: the LLM prompt and
-- the validator are both generated from it, so they can never drift apart.
-- ============================================================================

-- ── ACTION REGISTRY — the closed enum ───────────────────────────────────────
-- Per verb:
--   desc   : one-line meaning, injected verbatim into the LLM prompt.
--   target : referential contract for the `target` arg —
--              'none'   → target must be ABSENT
--              'place'  → target must be a known scene label (Config.Scenes)
--              'place?' → optional; if present, a known scene label
--              'agent'  → a known roster NPC id, or the literal 'player'
--   gate   : capability gate the legality layer requires —
--              nil      → always allowed (pure theater / no side effect)
--              'money'  → requires Config.Director.MoneyEnabled
--              'crime'  → requires Config.Director.CrimeEnabled
--   amount : { max = N } if the verb accepts a clamped money `amount`, else nil.
local ACTIONS = {
    idle             = { desc = 'stand where you are and do nothing notable',            target = 'none',   gate = nil },
    wander           = { desc = 'stroll around your area with no goal',                  target = 'place?', gate = nil },
    goTo             = { desc = 'walk to a named place',                                 target = 'place',  gate = nil },
    queueAt          = { desc = 'go wait in line / linger as a customer at a venue',     target = 'place',  gate = nil },
    talkTo           = { desc = 'approach and start a conversation with someone',        target = 'agent',  gate = nil },
    flee             = { desc = 'run away from danger',                                  target = 'none',   gate = nil },
    complyWithPolice = { desc = 'stop and put your hands up for police',                 target = 'none',   gate = nil },
    orderAt          = { desc = 'buy something as a paying customer at a venue',         target = 'place',  gate = 'money', amount = { max = 2000 } },
    buyFrom          = { desc = 'purchase goods from another person',                    target = 'agent',  gate = 'money', amount = { max = 5000 } },
    deal             = { desc = 'sell illicit goods to someone',                         target = 'agent',  gate = 'crime' },
    rob              = { desc = 'rob someone at threat',                                 target = 'agent',  gate = 'crime' },
    attack           = { desc = 'attack someone',                                        target = 'agent',  gate = 'crime' },
}

-- ── Referential context builders ─────────────────────────────────────────────
-- The set of NPC ids the Director may direct, capped to MaxRoster. Named NPCs
-- are the grounded roster for this slice (they have stable ids + roles); the
-- virtualized-population layer plugs in here later without touching the validator.
local function buildRoster()
    local roster, ids = {}, {}
    local cap = (Config.Director and Config.Director.MaxRoster) or 20
    for _, n in ipairs(Config.NamedNpcs or {}) do
        if #roster >= cap then break end
        roster[#roster + 1] = { id = n.id, name = n.name, role = n.role }
        ids[n.id] = true
    end
    return roster, ids
end

-- The set of valid `place` targets = scene labels (the world's known venues).
local function buildPlaces()
    local places = {}
    for _, s in ipairs(Config.Scenes or {}) do
        if s.label then places[s.label] = true end
    end
    return places
end

-- ── THE VALIDATOR — pure, no side effects, no globals mutated ─────────────────
-- validateAction(action, ctx) -> ok:boolean, reason:string, clean:table|nil
--   ctx = { npcIds=set, places=set, moneyOn=bool, crimeOn=bool }
-- `clean` (on success) is the action with its amount clamped to the verb cap.
-- Three layers, in order; the FIRST failure returns. This function is the whole
-- safety contract — everything the model produces flows through it.
local function isInt(v)
    if type(v) ~= 'number' then return false end
    return v == math.floor(v)
end

local function validateAction(action, ctx)
    -- ---- Layer 1: SHAPE / TYPE -------------------------------------------
    if type(action) ~= 'table' then return false, 'not-an-object' end
    local verb = action.verb
    if type(verb) ~= 'string' then return false, 'verb-not-string' end
    local spec = ACTIONS[verb]
    if not spec then return false, 'unknown-verb:' .. tostring(verb):sub(1, 24) end
    if type(action.npc) ~= 'string' or #action.npc == 0 or #action.npc > 64 then
        return false, 'bad-npc-id'
    end
    if action.target ~= nil then
        if type(action.target) ~= 'string' or #action.target > 64 then return false, 'bad-target-type' end
    end
    local amount = action.amount
    if amount ~= nil then
        if not spec.amount then return false, 'amount-not-allowed-for:' .. verb end
        if not isInt(amount) then return false, 'amount-not-integer' end
        local outer = (Config.Director and Config.Director.MaxAmount) or 100000
        if amount < 0 or amount > outer then return false, 'amount-out-of-bounds' end
    end

    -- ---- Layer 2: REFERENTIAL --------------------------------------------
    if not ctx.npcIds[action.npc] then return false, 'npc-not-in-roster:' .. action.npc end
    local tk = spec.target
    if tk == 'none' then
        if action.target ~= nil then return false, 'target-not-allowed-for:' .. verb end
    elseif tk == 'place' then
        if not action.target then return false, 'target-required' end
        if not ctx.places[action.target] then return false, 'unknown-place:' .. action.target end
    elseif tk == 'place?' then
        if action.target and not ctx.places[action.target] then return false, 'unknown-place:' .. action.target end
    elseif tk == 'agent' then
        if not action.target then return false, 'target-required' end
        if action.target ~= 'player' and not ctx.npcIds[action.target] then
            return false, 'unknown-agent:' .. action.target
        end
        if action.target == action.npc then return false, 'agent-targets-self' end
    end

    -- ---- Layer 3: LEGALITY (capability gates + clamp) --------------------
    if spec.gate == 'money' and not ctx.moneyOn then return false, 'blocked:money-gate-off' end
    if spec.gate == 'crime' and not ctx.crimeOn then return false, 'blocked:crime-gate-off' end

    local clean = { npc = action.npc, verb = verb, target = action.target }
    if spec.amount and amount ~= nil then
        clean.amount = math.min(amount, spec.amount.max)   -- clamp to the per-verb cap
    end
    return true, 'ok', clean
end

-- ── LLM prompt (built FROM the registry so it can't drift) ───────────────────
local function enumBlock()
    -- deterministic order so the prompt is stable across ticks (cache-friendly)
    local verbs = {}
    for v in pairs(ACTIONS) do verbs[#verbs + 1] = v end
    table.sort(verbs)
    local lines = {}
    for _, v in ipairs(verbs) do
        local s = ACTIONS[v]
        local targetHint = ({ ['none'] = 'no target', ['place'] = 'target = a place name',
            ['place?'] = 'optional target = a place name', ['agent'] = "target = an npc id or 'player'" })[s.target]
        local amtHint = s.amount and (', optional integer amount up to %d'):format(s.amount.max) or ''
        lines[#lines + 1] = ('- "%s": %s (%s%s)'):format(v, s.desc, targetHint, amtHint)
    end
    return table.concat(lines, '\n')
end

local function rosterBlock(roster)
    local lines = {}
    for _, n in ipairs(roster) do
        lines[#lines + 1] = ('- id "%s" (%s): %s'):format(n.id, n.name or n.id, n.role or 'a resident')
    end
    return table.concat(lines, '\n')
end

local function placesBlock(places)
    local list = {}
    for label in pairs(places) do list[#list + 1] = label end
    table.sort(list)
    return table.concat(list, ', ')
end

-- ── GLM call (same free-tier path as dialogue; see server/main.lua) ──────────
local G_URL   = GetConvar('palm6:glm_url', 'https://open.bigmodel.cn/api/paas/v4/chat/completions')
local G_MODEL = GetConvar('palm6:glm_model', 'glm-4-flash')
local function gKey() return GetConvar('palm6:glm_key', '') end

-- Pull the first JSON array out of a possibly-chatty model response. Returns a
-- Lua table or nil; never throws (pcall around decode). Defensive because the
-- model may wrap JSON in prose or ```json fences despite instructions.
local function extractActions(resp)
    if type(resp) ~= 'string' then return nil end
    local arr = resp:match('%[.-%]')                 -- shortest bracketed span
    if not arr then arr = resp:match('%[.*%]') end   -- fall back to greedy
    if not arr then return nil end
    local ok, data = pcall(json.decode, arr)
    return (ok and type(data) == 'table') and data or nil
end

-- Run ONE Director tick. cb(result) where result = { accepted={...}, blocked={...},
-- error=nil|string }. Pure-ish: it calls GLM and the validator, and NEVER
-- actuates (this slice). world = { players = N }.
local function runTick(world, cb)
    local roster, npcIds = buildRoster()
    if #roster == 0 then return cb({ accepted = {}, blocked = {}, error = 'empty-roster' }) end
    local places = buildPlaces()

    local key = gKey()
    if key == '' then return cb({ accepted = {}, blocked = {}, error = 'no-glm-key' }) end

    local d = Config.Director or {}
    local ctx = { npcIds = npcIds, places = places, moneyOn = d.MoneyEnabled == true, crimeOn = d.CrimeEnabled == true }

    local sys = ([[You are the DIRECTOR of background characters in a Grand Theft Auto V roleplay city (Los Santos). Each tick you assign EVERY listed character ONE action so the city feels alive, especially when few real players are online.

CHARACTERS (use these exact ids):
%s

PLACES you may reference as a target:
%s

ALLOWED ACTIONS (you may ONLY use these verbs and target forms):
%s

Right now %d real player(s) are online. Pick believable, low-key actions — most people idle, wander, or run errands; crime is rare. Keep the city coherent.

Reply with ONLY a JSON array, one object per character, no prose, no code fences. Each object: {"npc":"<id>","verb":"<verb>","target":"<optional>","amount":<optional integer>}. Omit target/amount when the verb takes none.]])
        :format(rosterBlock(roster), placesBlock(places), enumBlock(), world and world.players or 0)

    local body = json.encode({
        model = G_MODEL,
        messages = { { role = 'system', content = sys },
                     { role = 'user', content = 'Assign this tick.' } },
        max_tokens = 400, temperature = 0.7,
    })

    PerformHttpRequest(G_URL, function(status, resp)
        if status ~= 200 or not resp then
            return cb({ accepted = {}, blocked = {}, error = ('http-%s'):format(tostring(status)) })
        end
        local ok, data = pcall(json.decode, resp)
        local content = ok and data and data.choices and data.choices[1]
            and data.choices[1].message and data.choices[1].message.content
        local actions = extractActions(content)
        if not actions then
            return cb({ accepted = {}, blocked = {}, error = 'unparseable-plan' })
        end

        local accepted, blocked, seen = {}, {}, {}
        for _, a in ipairs(actions) do
            local vok, reason, clean = validateAction(a, ctx)
            if vok then
                -- one goal per NPC: keep the first valid action for each id
                if not seen[clean.npc] then
                    seen[clean.npc] = true
                    accepted[#accepted + 1] = clean
                else
                    blocked[#blocked + 1] = { npc = clean.npc, verb = clean.verb, reason = 'duplicate-npc' }
                end
            else
                blocked[#blocked + 1] = { npc = (type(a) == 'table' and a.npc) or '?',
                    verb = (type(a) == 'table' and a.verb) or '?', reason = reason }
            end
        end
        cb({ accepted = accepted, blocked = blocked, error = nil })
    end, 'POST', body, { ['Content-Type'] = 'application/json', ['Authorization'] = 'Bearer ' .. key })
end

-- Format a tick result for the console meter.
local function logTick(res, tag)
    tag = tag or 'tick'
    if res.error then
        print(('[palm6_brain:director] %s ERROR: %s'):format(tag, res.error))
        return
    end
    print(('[palm6_brain:director] %s — %d accepted, %d blocked (DRY-RUN, nothing actuated):')
        :format(tag, #res.accepted, #res.blocked))
    for _, a in ipairs(res.accepted) do
        local amt = a.amount and (' $' .. a.amount) or ''
        print(('  ✓ %s WOULD %s%s%s'):format(a.npc, a.verb, a.target and (' -> ' .. a.target) or '', amt))
    end
    for _, b in ipairs(res.blocked) do
        print(('  ✗ %s %s BLOCKED: %s'):format(b.npc, b.verb, b.reason))
    end
end

-- ============================================================================
-- GOAL STORE + LIFECYCLE — the substrate actuation reads from.
--
-- Turns the Director from "decide and forget" (dry-run) into "decide, COMMIT one
-- goal per NPC with a TTL, and DEGRADE safely." One active goal per npcId. A goal
-- auto-expires after GoalTtlTicks ticks with no refresh, so a Director/GLM outage
-- can never freeze an NPC on a stale goal — it expires and the NPC falls back to
-- the always-on reflex tier. The client-actuation slice subscribes to the
-- broadcast: `palm6_brain:goal` (npcId, goal|false) — goal={verb,target,amount,
-- expiresAt}; `false` means "goal cleared, return to reflex". Same seam idiom as
-- the LLM seam documented in server/main.lua.
--
-- applyCommit/applyExpire are PURE given `now` (they mutate the passed store and
-- return what changed, no I/O) so the lifecycle is deterministically testable in
-- /brainvalidate. The real commitPlan/expireStale wrap them on the module store
-- and add the broadcast side effect.
-- ============================================================================
local goals = {}   -- npcId -> { verb, target, amount, issuedAt, expiresAt }

local function goalTtlSeconds()
    local d = Config.Director or {}
    return ((d.TickSeconds or 60) * (d.GoalTtlTicks or 2))
end

-- Pure: write one goal into `store`. Returns the stored goal.
local function applyCommit(store, npcId, action, now, ttl)
    local g = { verb = action.verb, target = action.target, amount = action.amount,
                issuedAt = now, expiresAt = now + ttl }
    store[npcId] = g
    return g
end

-- Pure: remove every goal in `store` whose expiresAt has passed. Returns the list
-- of cleared npcIds.
local function applyExpire(store, now)
    local cleared = {}
    for id, g in pairs(store) do
        if now >= g.expiresAt then
            store[id] = nil
            cleared[#cleared + 1] = id
        end
    end
    return cleared
end

-- Commit an accepted plan to the live store and broadcast each goal. Returns count.
local function commitPlan(accepted)
    local now = os.time()
    local ttl = goalTtlSeconds()
    for _, a in ipairs(accepted) do
        local g = applyCommit(goals, a.npc, a, now, ttl)
        TriggerClientEvent('palm6_brain:goal', -1, a.npc, g)
    end
    return #accepted
end

-- Expire stale goals on the live store and broadcast a clear for each. Returns count.
local function expireStale()
    local cleared = applyExpire(goals, os.time())
    for _, id in ipairs(cleared) do
        TriggerClientEvent('palm6_brain:goal', -1, id, false)
    end
    return #cleared
end

-- Read API for any consumer (the ped executor, other resources). Lazy-expires on
-- read so a caller never sees a stale goal even between sweeps.
exports('GetGoal', function(npcId)
    local g = goals[npcId]
    if not g then return nil end
    if os.time() >= g.expiresAt then goals[npcId] = nil; return nil end
    return g
end)

exports('GetGoals', function()
    local out, now = {}, os.time()
    for id, g in pairs(goals) do
        if now < g.expiresAt then out[id] = g end
    end
    return out
end)

-- ── The automatic tick loop (only runs when the master gate is on) ───────────
CreateThread(function()
    local d = Config.Director
    if not (d and d.Enabled == true) then return end   -- dark-ship: loop never starts
    while (Config.Director and Config.Director.Enabled) == true do
        -- Expire stale goals FIRST, every iteration — this runs even when GLM is
        -- down or players<min, so a Director outage degrades to reflex on schedule
        -- rather than leaving NPCs stuck on an old goal.
        local swept = expireStale()
        if d.Verbose and swept > 0 then
            print(('[palm6_brain:director] auto — expired %d stale goal(s)'):format(swept))
        end

        local players = #GetPlayers()
        if players >= (d.MinPlayers or 0) then
            runTick({ players = players }, function(res)
                if d.Verbose then logTick(res, 'auto') end
                -- DryRun=false commits the accepted plan to the goal store +
                -- broadcasts it (still inert until a client executor subscribes).
                if not d.DryRun and not res.error then
                    local n = commitPlan(res.accepted)
                    if d.Verbose and n > 0 then
                        print(('[palm6_brain:director] auto — committed %d goal(s)'):format(n))
                    end
                end
            end)
        end
        Wait(((d.TickSeconds or 60) * 1000))
    end
end)

-- ============================================================================
-- DEV COMMANDS (ACE-restricted: require command.<name>). These are the meters.
-- ============================================================================

-- /braindirector — run ONE live Director tick on demand and print the plan,
-- regardless of the auto-loop gate. Lets David watch the LLM→validate pipeline
-- against the real GLM without lighting the loop. Always DRY-RUN in this slice.
RegisterCommand('braindirector', function(src)
    runTick({ players = #GetPlayers() }, function(res)
        logTick(res, 'manual')
        -- Mirror the auto-loop: commit only when DryRun is off, so the manual
        -- probe reflects exactly what an automatic tick would do.
        local committed = 0
        if not (Config.Director and Config.Director.DryRun) and not res.error then
            committed = commitPlan(res.accepted)
            print(('[palm6_brain:director] manual — committed %d goal(s)'):format(committed))
        end
        if src ~= 0 then
            TriggerClientEvent('chat:addMessage', src, { color = { 150, 200, 255 },
                args = { 'director', res.error and ('error: ' .. res.error)
                    or ('%d accepted / %d blocked%s — see server console'):format(#res.accepted, #res.blocked,
                        committed > 0 and (', ' .. committed .. ' committed') or '') } })
        end
    end)
end, true)

-- /brainvalidate — run the adversarial test battery through validateAction and
-- print PASS/FAIL. NO GLM, fully deterministic: this is a real unit test running
-- in the real server runtime (per the verification-before-completion rule).
RegisterCommand('brainvalidate', function(src)
    -- Fixed context: a known roster + places, both gates OFF (prod default).
    local ctx = {
        npcIds = { tony = true, rosa = true, deak = true },
        places = { ['Legion Square'] = true, ['Del Perro Pier'] = true },
        moneyOn = false, crimeOn = false,
    }
    -- Each case: { action, expectOk, label }. expectOk=false means "must reject".
    local cases = {
        { { npc = 'tony', verb = 'idle' },                                   true,  'idle no-target' },
        { { npc = 'rosa', verb = 'goTo', target = 'Legion Square' },         true,  'goTo known place' },
        { { npc = 'rosa', verb = 'goTo', target = 'Narnia' },                false, 'goTo unknown place' },
        { { npc = 'tony', verb = 'teleport' },                               false, 'unknown verb' },
        { { npc = 'tony', verb = 'talkTo', target = 'ghost' },               false, 'talkTo unknown agent' },
        { { npc = 'tony', verb = 'talkTo', target = 'player' },              true,  "talkTo 'player'" },
        { { npc = 'tony', verb = 'talkTo', target = 'tony' },                false, 'talkTo self' },
        { { npc = 'deak', verb = 'rob', target = 'player' },                 false, 'rob blocked (crime gate off)' },
        { { npc = 'tony', verb = 'orderAt', target = 'Legion Square', amount = 999999 }, false, 'amount over MaxAmount' },
        { { npc = 'tony', verb = 'orderAt', target = 'Legion Square', amount = 500 },    false, 'orderAt blocked (money gate off)' },
        { { npc = 'nobody', verb = 'idle' },                                 false, 'npc not in roster' },
        { { npc = 'tony', verb = 'idle', target = 'Legion Square' },         false, 'idle rejects a target' },
        { { npc = 'tony', verb = 'orderAt', target = 'Legion Square', amount = '500' },  false, 'amount as string' },
        { { npc = 'tony', verb = 'goTo', target = "Legion Square';DROP" },   false, 'injection-ish target' },
        { 'not-a-table',                                                     false, 'non-object action' },
    }
    -- Same battery, but with gates ON, proving money/crime PASS when enabled.
    local ctxOn = { npcIds = ctx.npcIds, places = ctx.places, moneyOn = true, crimeOn = true }
    local gateCases = {
        { { npc = 'deak', verb = 'rob', target = 'player' },                 true,  'rob passes (crime gate on)' },
        { { npc = 'tony', verb = 'orderAt', target = 'Legion Square', amount = 500 }, true, 'orderAt passes (money gate on)' },
    }

    local pass, fail = 0, 0
    local function run(list, c)
        for _, case in ipairs(list) do
            local ok = validateAction(case[1], c)
            if ok == case[2] then
                pass = pass + 1
            else
                fail = fail + 1
                print(('[palm6_brain:director]   FAIL: %s (got ok=%s, expected %s)')
                    :format(case[3], tostring(ok), tostring(case[2])))
            end
        end
    end
    print('[palm6_brain:director] running validator battery...')
    run(cases, ctx)
    run(gateCases, ctxOn)
    -- Prove the clamp: amount above the per-verb cap is reduced, not rejected.
    local cok, _, clean = validateAction({ npc = 'tony', verb = 'orderAt', target = 'Legion Square', amount = 1900 }, ctxOn)
    local clampOk = cok and clean and clean.amount == 1900
    local cok2, _, clean2 = validateAction({ npc = 'tony', verb = 'orderAt', target = 'Legion Square', amount = 5000 }, ctxOn)
    local clampOk2 = cok2 and clean2 and clean2.amount == 2000   -- clamped to orderAt cap
    if clampOk and clampOk2 then pass = pass + 1 else fail = fail + 1; print('[palm6_brain:director]   FAIL: amount clamp') end

    -- Goal lifecycle (pure, deterministic via injected `now`): a goal survives
    -- before its TTL, is cleared at/after it, and a refresh extends it. Proves the
    -- degradation guarantee (stale goals always expire) without waiting real time.
    do
        local store = {}
        applyCommit(store, 'tony', { verb = 'idle' }, 1000, 120)          -- expires 1120
        local aliveBefore = (#applyExpire(store, 1119) == 0 and store.tony ~= nil)
        local cl = applyExpire(store, 1120)                                -- 1120 >= 1120 → clear
        local clearedAt = (#cl == 1 and cl[1] == 'tony' and store.tony == nil)
        applyCommit(store, 'rosa', { verb = 'wander' }, 1000, 120)         -- expires 1120
        applyCommit(store, 'rosa', { verb = 'wander' }, 1200, 120)         -- refreshed → 1320
        local refreshOk = (#applyExpire(store, 1250) == 0 and store.rosa ~= nil)
        if aliveBefore and clearedAt and refreshOk then pass = pass + 1
        else fail = fail + 1; print('[palm6_brain:director]   FAIL: goal lifecycle') end
    end

    local msg = ('validator: %d passed, %d failed'):format(pass, fail)
    print('[palm6_brain:director] ' .. msg)
    if src ~= 0 then
        TriggerClientEvent('chat:addMessage', src, { color = fail == 0 and { 120, 220, 140 } or { 230, 120, 120 },
            args = { 'director', msg } })
    end
end, true)

-- /braingoals — print the live goal store (what each NPC is currently committed
-- to and how long until it expires). The observability meter for the commit path;
-- empty while the Director is dry-run or has issued nothing.
RegisterCommand('braingoals', function(src)
    local now = os.time()
    local n = 0
    print('[palm6_brain:director] current goal store:')
    for id, g in pairs(goals) do
        local ttl = g.expiresAt - now
        if ttl > 0 then
            n = n + 1
            print(('  %s -> %s%s%s (%ds left)'):format(id, g.verb,
                g.target and (' -> ' .. g.target) or '',
                g.amount and (' $' .. g.amount) or '', ttl))
        end
    end
    if n == 0 then print('  (empty — Director is dry-run or has issued no goals)') end
    if src ~= 0 then
        TriggerClientEvent('chat:addMessage', src, { color = { 150, 200, 255 },
            args = { 'director', ('%d active goal(s) — see server console'):format(n) } })
    end
end, true)

-- On resource stop, drop every goal (in place, so export closures keep their
-- upvalue) so a restart never resurrects stale goals. Clients tear down their own
-- state via the client onResourceStop handler.
AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    for k in pairs(goals) do goals[k] = nil end
end)
