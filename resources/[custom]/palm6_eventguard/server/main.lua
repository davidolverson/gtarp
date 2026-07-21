-- ============================================================================
-- palm6_eventguard/server/main.lua
--
-- Ratelimits the events listed in Config.Events. Wraps the existing
-- handler chain by registering ourselves first; when a player exceeds the
-- budget we log to event_violations and drop the event. After
-- Config.KickThreshold breaches in a session, the player is kicked.
-- ============================================================================

local Counts     = {}  -- [eventName][src] = { calls = {ts...}, breaches = 0 }
local Violations = {}  -- [src] = total breaches this session

local function now() return os.time() end

local function bucket(eventName, src)
    Counts[eventName] = Counts[eventName] or {}
    Counts[eventName][src] = Counts[eventName][src] or { calls = {}, breaches = 0 }
    return Counts[eventName][src]
end

local function prune(b, window)
    local t = now()
    local i = 1
    while i <= #b.calls do
        if b.calls[i] < (t - window) then
            table.remove(b.calls, i)
        else
            i = i + 1
        end
    end
end

local function record(src, eventName, reason)
    Violations[src] = (Violations[src] or 0) + 1
    local detail = ('event=%s reason=%s breaches_session=%d'):format(
        eventName, reason, Violations[src])
    print(('[palm6_eventguard] VIOLATION src=%d %s'):format(src, detail))

    -- Best-effort: an unguarded await here THREW on any DB error (and
    -- event_violations ships only in sql/0008_security_events.sql, so a rebuilt DB
    -- may not have it), which unwound record() and skipped BOTH the staff log and
    -- the 3-strike kick below. pcall keeps the violation flow alive; the row is
    -- forensics, the kick is the control. (The drop itself already happened in
    -- guard() before this is ever called.) Also registered in palm6_dbmigrate now.
    pcall(function()
        MySQL.insert.await(
            "INSERT INTO event_violations (player_src, identifier, event_name, reason, created_at) VALUES (?,?,?,?, NOW())",
            { src, Bridge.GetPrimaryIdentifier(src), eventName, reason }
        )
    end)

    pcall(function()
        exports.palm6_staff:Log('eventguard', 0, src, detail)
    end)

    if Violations[src] >= (Config.KickThreshold or 3) then
        Bridge.Kick(src, 'kicked by eventguard: repeated event violations')
    end
end

-- Wrap one event with the ratelimit. Returns the wrapper handler.
local function guard(eventName, budget)
    AddEventHandler(eventName, function(...)
        local src = source
        if not src or src == 0 then return end  -- skip server-emitted
        local b = bucket(eventName, src)
        prune(b, budget.window_seconds)
        if #b.calls >= budget.calls then
            -- CANCEL FIRST — before ANY yielding call. CancelEvent() only takes
            -- effect while this handler is still running SYNCHRONOUSLY. record()
            -- below performs a yielding DB insert (and a yielding staff log), and
            -- in FiveM a yield hands control back to the event dispatcher, which
            -- immediately invokes the NEXT handler — the real one. Cancelling
            -- AFTER record() therefore arrived too late: the over-budget event was
            -- already delivered, so the limiter logged violations but never
            -- actually dropped anything (every non-combat budget was inert; only
            -- the combat branch, which cancelled before returning, worked).
            -- Dropping is load-bearing; logging is best-effort. Order matters.
            CancelEvent()
            -- Combat-class budget (fc striking/finisher mash): DROP the
            -- over-budget event but NEVER call record() — no violation row,
            -- no Violations[src]++ , no 3-strike kick. A legit flurry of
            -- palm6_fc_combat:strike/connect/block/break can burst past the
            -- budget; the server move-clock (palm6_fc_combat) — not eventguard
            -- — is the combat authority, and the §7 finisher :break mash would
            -- trip the kick model instantly. Money/menu events keep the
            -- strike-and-kick model via record() below.
            if budget.class == 'combat' then return end
            record(src, eventName, ('over budget %d/%ds'):format(
                budget.calls, budget.window_seconds))
            return
        end
        b.calls[#b.calls + 1] = now()
    end)
end

-- onResourceStart can fire more than once for this resource's own name in
-- some boot sequences (observed: guards silently double-registering,
-- halving every rate-limit budget and doubling violation counts — false
-- kicks after as few as 2 real breaches). Guard registration is not safe
-- to run twice in the same VM, so make it idempotent regardless of how
-- many times the event fires.
local guardsRegistered = false

AddEventHandler('onResourceStart', function(resource)
    if resource ~= GetCurrentResourceName() then return end
    if guardsRegistered then return end
    guardsRegistered = true

    local n = 0
    for name, budget in pairs(Config.Events) do
        guard(name, budget)
        n = n + 1
    end
    print(('[palm6_eventguard] guarding %d events; kick threshold=%d'):format(
        n, Config.KickThreshold or 3))
end)

AddEventHandler('playerDropped', function()
    local src = source
    Violations[src] = nil
    for name, t in pairs(Counts) do t[src] = nil end
end)

exports('GetViolations', function(src) return Violations[src] or 0 end)
