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
-- It is the PLANNING spine only. In DRY-RUN (the default) accepted actions are
-- logged — "Tony WOULD goTo Legion Square" — and discarded. This lets us watch
-- and trust the Director's decisions, and prove the batched-LLM → schema →
-- validate → plan pipeline end-to-end, before a single side effect exists.
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

-- ── The automatic tick loop (only runs when the master gate is on) ───────────
CreateThread(function()
    local d = Config.Director
    if not (d and d.Enabled == true) then return end   -- dark-ship: loop never starts
    while (Config.Director and Config.Director.Enabled) == true do
        local players = #GetPlayers()
        if players >= (d.MinPlayers or 0) then
            runTick({ players = players }, function(res)
                if d.Verbose then logTick(res, 'auto') end
                -- DRY-RUN: results are logged above and discarded. Actuation of
                -- res.accepted lands in the next slice, behind its own gate.
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
        if src ~= 0 then
            TriggerClientEvent('chat:addMessage', src, { color = { 150, 200, 255 },
                args = { 'director', res.error and ('error: ' .. res.error)
                    or ('%d accepted / %d blocked — see server console'):format(#res.accepted, #res.blocked) } })
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

    local msg = ('validator: %d passed, %d failed'):format(pass, fail)
    print('[palm6_brain:director] ' .. msg)
    if src ~= 0 then
        TriggerClientEvent('chat:addMessage', src, { color = fail == 0 and { 120, 220, 140 } or { 230, 120, 120 },
            args = { 'director', msg } })
    end
end, true)
