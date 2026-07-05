-- ============================================================================
-- gtarp_devtest/server/main.lua
--
-- Boot-time self-test of the CROSS-RESOURCE CONTRACTS the custom layer's
-- resources depend on — the things a banner-only boot check can't see:
--
--   * gtarp_evidence's FROZEN v2 export API (EnsureCase idempotency,
--     AppendEntry, LinkSuspect, GetCase round-trip)
--   * gtarp_staff's Log export actually landing an audit_log row
--   * gtarp_courier GetOpenPostings / gtarp_eventguard GetViolations /
--     gtarp_perf GetSummary shapes
--
-- Gated on the `gtarp:devtest` convar (default OFF — production never runs
-- this). Enable for one boot on the local test server:
--     set gtarp:devtest 1
-- Every DB row the tests create is deleted afterwards. Tests that need a
-- live player (allowlist role checks, witnesses.ReportCrime) are reported
-- as SKIP, not silently omitted.
--
-- No bridge/ folder on purpose: this resource calls only sibling gtarp
-- exports (portable by definition) and engine-agnostic runtime facilities
-- (GetConvar / GetResourceState / CreateThread / os.time). It ships in no
-- marketplace deliverable and is not part of the §6 game-native surface.
-- ============================================================================

local passed, failed, skipped = 0, 0, 0

local function pass(msg) passed = passed + 1; print(('[gtarp_devtest] PASS %s'):format(msg)) end
local function fail(msg) failed = failed + 1; print(('[gtarp_devtest] FAIL %s'):format(msg)) end
local function skip(msg) skipped = skipped + 1; print(('[gtarp_devtest] SKIP %s'):format(msg)) end

local function check(cond, msg)
    if cond then pass(msg) else fail(msg) end
    return cond
end

-- pcall a zero-arg fn; on error report FAIL with the error text.
local function try(label, fn)
    local ok, err = pcall(fn)
    if not ok then fail(('%s — errored: %s'):format(label, tostring(err))) end
    return ok
end

local function resourceUp(name)
    return GetResourceState(name) == 'started'
end

-- ---------------------------------------------------------------------------
-- Test groups
-- ---------------------------------------------------------------------------

local function testEvidence()
    if not resourceUp('gtarp_evidence') then
        fail('evidence — resource not started')
        return
    end
    local key = ('devtest:%d'):format(os.time())
    local caseId, caseId2, entryId, linked, full

    if not try('evidence.EnsureCase', function()
        caseId = exports.gtarp_evidence:EnsureCase(key, 'devtest self-test case', 'gtarp_devtest')
        caseId2 = exports.gtarp_evidence:EnsureCase(key, 'devtest self-test case', 'gtarp_devtest')
    end) then return end

    if not check(type(caseId) == 'number', 'evidence.EnsureCase returns numeric caseId') then return end
    check(caseId == caseId2, ('evidence.EnsureCase idempotent per incidentKey (case %d)'):format(caseId))

    try('evidence.AppendEntry', function()
        entryId = exports.gtarp_evidence:AppendEntry(caseId, 'note', { probe = true, tag = 'devtest' }, 'gtarp_devtest')
    end)
    check(type(entryId) == 'number', 'evidence.AppendEntry returns numeric entryId (table payload json-encoded)')

    try('evidence.LinkSuspect', function()
        linked = exports.gtarp_evidence:LinkSuspect(caseId, nil, 'devtest descriptor: tall, red hoodie')
    end)
    check(linked == true, 'evidence.LinkSuspect (descriptor-only) returns true')

    try('evidence.GetCase', function()
        full = exports.gtarp_evidence:GetCase(caseId)
    end)
    if check(type(full) == 'table', 'evidence.GetCase returns case table') then
        check(full.incident_key == key, 'evidence.GetCase round-trips incident_key')
        check(type(full.entries) == 'table' and #full.entries >= 1, 'evidence.GetCase includes appended entry')
        check(type(full.suspects) == 'table' and #full.suspects >= 1, 'evidence.GetCase includes linked suspect')
    end

    -- cleanup (children first — no FK cascade assumed)
    pcall(function()
        MySQL.update.await('DELETE FROM gtarp_evidence WHERE case_id = ?', { caseId })
        MySQL.update.await('DELETE FROM gtarp_evidence_suspects WHERE case_id = ?', { caseId })
        MySQL.update.await('DELETE FROM gtarp_evidence_cases WHERE id = ?', { caseId })
    end)
end

local function testStaffLog()
    if not resourceUp('gtarp_staff') then
        fail('staff — resource not started')
        return
    end
    local marker = ('devtest-%d'):format(os.time())
    if not try('staff.Log', function()
        exports.gtarp_staff:Log('devtest', 0, nil, marker)
    end) then return end

    local row
    pcall(function()
        row = MySQL.single.await(
            'SELECT id, actor_name FROM audit_log WHERE action = ? AND detail = ? ORDER BY id DESC LIMIT 1',
            { 'devtest', marker })
    end)
    if check(row ~= nil, 'staff.Log lands an audit_log row') then
        check(row.actor_name == 'console', 'staff.Log records console actor for src 0')
        pcall(function() MySQL.update.await('DELETE FROM audit_log WHERE id = ?', { row.id }) end)
    end
end

local function testShapes()
    if resourceUp('gtarp_courier') then
        try('courier.GetOpenPostings', function()
            local p = exports.gtarp_courier:GetOpenPostings()
            check(type(p) == 'table', 'courier.GetOpenPostings returns table')
        end)
    else
        fail('courier — resource not started')
    end

    if resourceUp('gtarp_eventguard') then
        try('eventguard.GetViolations', function()
            local v = exports.gtarp_eventguard:GetViolations(999999)
            check(v == 0, 'eventguard.GetViolations returns 0 for unknown src')
        end)
    else
        fail('eventguard — resource not started')
    end

    if resourceUp('gtarp_perf') then
        try('perf.GetSummary', function()
            local s = exports.gtarp_perf:GetSummary()
            check(type(s) == 'table', 'perf.GetSummary returns table')
        end)
    else
        fail('perf — resource not started')
    end
end

local function testPlayerBound()
    -- These contracts need a live player source; exercising them with a
    -- fake src would test error paths, not the contract. Visible SKIPs so
    -- the summary never over-claims coverage.
    skip('allowlist.IsAllowlisted / HasAllowedRole — needs live player src')
    skip('whitelist_jobs.IsAllowed — needs live player src')
    skip('witnesses.ReportCrime — needs live player position + ambient peds')
end

-- ---------------------------------------------------------------------------
-- Runner
-- ---------------------------------------------------------------------------

AddEventHandler('onResourceStart', function(resource)
    if resource ~= GetCurrentResourceName() then return end
    if GetConvar('gtarp:devtest', '0') ~= '1' then
        print('[gtarp_devtest] disabled (set gtarp:devtest 1 to run contract self-tests)')
        return
    end

    -- Let siblings finish their own onResourceStart work first.
    CreateThread(function()
        Wait(3000)
        print('[gtarp_devtest] ▶ running cross-resource contract self-tests')
        testEvidence()
        testStaffLog()
        testShapes()
        testPlayerBound()
        local mark = failed == 0 and '✔' or '✘'
        print(('[gtarp_devtest] %s %d passed, %d failed, %d skipped'):format(mark, passed, failed, skipped))
        if failed > 0 then
            print('[gtarp_devtest] CONTRACTS BROKEN — do not ship until the FAIL lines above are fixed.')
        end
    end)
end)
