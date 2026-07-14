-- ============================================================================
-- palm6_robbery/server/main.lua
--
-- ATM robberies. Two phases: `start` validates (police gate, cooldown,
-- proximity), reserves the target and fires dispatch; `complete` pays out
-- after the client-side hold. Pure logic — all framework/native access via
-- Bridge.*.
-- ============================================================================

local cd      = {}  -- [index] = unix expiry
local pending = {}  -- [src] = { index, holdUntil }

local function nearby(src, coords)
    local c = Bridge.GetCoords(src)
    if not c or not coords then return true end
    return Bridge.Distance(c, coords) <= (Config.InteractRadius + 2.5)
end

RegisterNetEvent('palm6_robbery:start', function(index)
    local src = source
    local loc = Config.ATMs.locations[index]
    if not loc then return end
    if not Bridge.GetCitizenId(src) then return end

    if Bridge.CountOnDutyPolice() < (Config.MinPolice or 0) then
        Bridge.Notify(src, 'Robbery', 'It is too quiet — not enough police around.', 'error')
        return
    end

    if Config.RequireWeapon and not Bridge.IsArmed(src) then
        Bridge.Notify(src, 'Robbery', 'You need a weapon out for this.', 'error')
        return
    end

    local now = os.time()
    if (cd[index] or 0) > now then
        Bridge.Notify(src, 'Robbery', 'This spot was hit recently. Come back later.', 'error')
        return
    end
    if not nearby(src, loc.coords) then return end

    -- Reserve immediately so it can't be double-started or spammed.
    cd[index] = now + Config.ATMs.cooldown_secs
    pending[src] = { index = index, startedAt = now,
                      holdUntil = now + Config.ATMs.hold_seconds + 5 }

    Bridge.AlertPolice(loc.coords,
        ('%s — %s'):format(Config.Dispatch.label, loc.label),
        Config.Dispatch.durationSeconds,
        Config.Dispatch.blipSprite, Config.Dispatch.blipColour, Config.Dispatch.blipScale)

    -- Server-only signal for shadow listeners (palm6_witnesses): fired ONLY
    -- after every gate above passed, so rejected/forged starts never leak.
    -- TriggerEvent (local), never a net event — clients cannot fake this.
    TriggerEvent('palm6_robbery:started', src)

    TriggerClientEvent('palm6_robbery:begin', src, { index = index, hold = Config.ATMs.hold_seconds })
end)

RegisterNetEvent('palm6_robbery:complete', function(index)
    local src = source
    local pend = pending[src]
    if not pend or pend.index ~= index then return end
    pending[src] = nil
    local elapsed = os.time() - pend.startedAt
    if os.time() > pend.holdUntil then return end  -- took too long / tampered
    if elapsed < Config.ATMs.hold_seconds then return end  -- skipped the hold client-side

    local loc = Config.ATMs.locations[index]
    if not loc or not nearby(src, loc.coords) then
        Bridge.Notify(src, 'Robbery', 'You left the ATM.', 'error')
        return
    end

    local reward = math.random(Config.ATMs.reward_min, Config.ATMs.reward_max)
    Bridge.AddCash(src, reward, 'robbery')

    Bridge.Notify(src, 'Robbery', ('You got away with $%d.'):format(reward), 'success')
end)

RegisterNetEvent('palm6_robbery:cancel', function()
    local src = source
    local pend = pending[src]
    if not pend then return end
    pending[src] = nil
    -- Soft penalty on cancel so start/cancel can't spam dispatch, but a genuine
    -- interruption isn't a full 30-minute lockout.
    cd[pend.index] = os.time() + 60
end)

AddEventHandler('playerDropped', function()
    pending[source] = nil
end)
