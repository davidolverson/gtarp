-- ============================================================================
-- gtarp_robbery/server/main.lua
--
-- Store & ATM robberies. Two phases: `start` validates (police gate, cooldown,
-- proximity), reserves the target and fires dispatch; `complete` pays out after
-- the client-side hold. Pure logic — all framework/native access via Bridge.*.
-- ============================================================================

local cd      = { store = {}, atm = {} }  -- [index] = unix expiry
local pending = {}                        -- [src] = { kind, index, holdUntil }

local function cfgFor(kind)
    return kind == 'store' and Config.Stores or (kind == 'atm' and Config.ATMs) or nil
end

local function nearby(src, coords)
    local c = Bridge.GetCoords(src)
    if not c or not coords then return true end
    return Bridge.Distance(c, coords) <= (Config.InteractRadius + 2.5)
end

RegisterNetEvent('gtarp_robbery:start', function(kind, index)
    local src = source
    local cfg = cfgFor(kind)
    if not cfg then return end
    local loc = cfg.locations[index]
    if not loc then return end
    if not Bridge.GetCitizenId(src) then return end

    if Bridge.CountOnDutyPolice() < (Config.MinPolice or 0) then
        Bridge.Notify(src, 'Robbery', 'It is too quiet — not enough police around.', 'error')
        return
    end

    local now = os.time()
    if (cd[kind][index] or 0) > now then
        Bridge.Notify(src, 'Robbery', 'This spot was hit recently. Come back later.', 'error')
        return
    end
    if not nearby(src, loc.coords) then return end

    -- Reserve immediately so it can't be double-started or spammed.
    cd[kind][index] = now + cfg.cooldown_secs
    pending[src] = { kind = kind, index = index, holdUntil = now + cfg.hold_seconds + 5 }

    Bridge.AlertPolice(loc.coords,
        ('%s — %s'):format(Config.Dispatch.label, loc.label),
        Config.Dispatch.durationSeconds,
        Config.Dispatch.blipSprite, Config.Dispatch.blipColour, Config.Dispatch.blipScale)

    TriggerClientEvent('gtarp_robbery:begin', src, { kind = kind, index = index, hold = cfg.hold_seconds })
end)

RegisterNetEvent('gtarp_robbery:complete', function(kind, index)
    local src = source
    local pend = pending[src]
    if not pend or pend.kind ~= kind or pend.index ~= index then return end
    pending[src] = nil
    if os.time() > pend.holdUntil then return end  -- took too long / tampered

    local cfg = cfgFor(kind)
    local loc = cfg and cfg.locations[index]
    if not loc or not nearby(src, loc.coords) then
        Bridge.Notify(src, 'Robbery', 'You left the counter.', 'error')
        return
    end

    local reward = math.random(cfg.reward_min, cfg.reward_max)
    Bridge.AddCash(src, reward, 'robbery')

    -- optional marked-bills loot on store jobs
    if kind == 'store' and cfg.marked_item and Bridge.ItemExists(cfg.marked_item)
       and math.random() < (cfg.marked_chance or 0) then
        Bridge.GiveItem(src, cfg.marked_item, math.random(cfg.marked_min or 1, cfg.marked_max or 1))
    end

    Bridge.Notify(src, 'Robbery', ('You got away with $%d.'):format(reward), 'success')
end)

RegisterNetEvent('gtarp_robbery:cancel', function()
    local src = source
    local pend = pending[src]
    if not pend then return end
    pending[src] = nil
    -- Soft penalty on cancel so start/cancel can't spam dispatch, but a genuine
    -- interruption isn't a full 30-minute lockout.
    cd[pend.kind][pend.index] = os.time() + 60
end)

AddEventHandler('playerDropped', function()
    pending[source] = nil
end)
