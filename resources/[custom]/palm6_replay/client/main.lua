-- ============================================================================
-- palm6_replay/client/main.lua
--
-- Two halves, both pure logic (all native access via Game.* — §6 gate):
--
--   1. The recorder: a rolling ring of compact telemetry frames sampled at
--      Config.Recording.FrameHz. A few KB in memory, nothing on disk,
--      nothing sent anywhere — until the SERVER asks for it by capture id
--      (palm6_replay:requestBuffer). The client never volunteers a buffer.
--
--   2. The reconstruction: translucent ghost peds interpolated through a
--      persisted scene's frames — pause / scrub / speed control — with
--      muzzle-flash markers at recorded shot frames.
--
-- The server re-validates everything we upload; nothing here is trusted.
-- ============================================================================

-- Frame flag bits (mirrored in server validation's FLAG_MASK).
local FLAG_SHOOT   = 1
local FLAG_VEHICLE = 2
local FLAG_DEAD    = 4
local FLAG_AIM     = 8
local FLAG_RAGDOLL = 16

local function round(v, m)
    return math.floor(v * m + 0.5) / m
end

-- ---------------------------------------------------------------------------
-- 1. The recorder — rolling telemetry ring
-- ---------------------------------------------------------------------------

local RING_SIZE = Config.Recording.FrameHz * Config.Recording.BufferSeconds
local ring = {}
local ringHead = 0  -- last written slot (1..RING_SIZE)

CreateThread(function()
    if not Config.Recording.Enabled then return end
    local frameInterval = math.floor(1000 / Config.Recording.FrameHz)
    local SHOT_POLL_MS = 100  -- IsPedShooting is edge-triggered; 4 Hz alone
                              -- would miss single gunshots between samples.
    local shotSeen = false
    local lastShotReport = 0
    local nextFrameAt = 0

    while true do
        local now = Game.Now()

        if Game.IsLocalPedShooting() then
            shotSeen = true
            -- "Shots ring out": tell the server we fired. The report carries
            -- no data — the server reads OUR position itself and applies its
            -- own cooldown; this client-side one just avoids useless traffic.
            if Config.Triggers.ShotsFired
                and now - lastShotReport > Config.Triggers.ShotsFiredCooldown * 1000 then
                lastShotReport = now
                TriggerServerEvent('palm6_replay:shotsFired')
            end
        end

        if now >= nextFrameAt then
            nextFrameAt = now + frameInterval
            local s = Game.SampleTelemetry()

            local f = 0
            if shotSeen or s.shooting then f = f + FLAG_SHOOT end
            if s.inVehicle then f = f + FLAG_VEHICLE end
            if s.dead      then f = f + FLAG_DEAD end
            if s.aiming    then f = f + FLAG_AIM end
            if s.ragdoll   then f = f + FLAG_RAGDOLL end
            shotSeen = false

            ringHead = ringHead % RING_SIZE + 1
            ring[ringHead] = {
                t = now,
                x = round(s.x, 100), y = round(s.y, 100), z = round(s.z, 100),
                h = round(s.heading, 10),
                s = round(s.speed, 10),
                w = s.weapon,
                f = f,
            }
        end

        Wait(SHOT_POLL_MS)
    end
end)

-- Ordered snapshot (oldest -> newest) with timestamps rebased to 0, matching
-- the server's validation window.
local function snapshotRing()
    local out = {}
    for i = 1, RING_SIZE do
        local fr = ring[(ringHead + i - 1) % RING_SIZE + 1]
        if fr then out[#out + 1] = fr end
    end
    if #out == 0 then return out end
    local t0 = out[1].t
    local rebased = {}
    for i, fr in ipairs(out) do
        rebased[i] = { t = fr.t - t0, x = fr.x, y = fr.y, z = fr.z,
                       h = fr.h, s = fr.s, w = fr.w, f = fr.f }
    end
    return rebased
end

-- The ONLY path a buffer leaves this client: the server asked, by capture id.
RegisterNetEvent('palm6_replay:requestBuffer', function(captureId)
    if type(captureId) ~= 'number' then return end
    local frames = snapshotRing()
    if #frames < 2 then return end
    TriggerServerEvent('palm6_replay:uploadBuffer', captureId, frames, Game.GetPedModelHash())
end)

-- ---------------------------------------------------------------------------
-- 2. The reconstruction — ghost playback
-- ---------------------------------------------------------------------------

local playback = {
    active   = false,
    loading  = false, -- startPlayback is spawning ghosts (yields on model loads)
    incoming = nil,   -- scene being streamed down (meta + participants)
    parts    = {},    -- [{ name, model, frames, duration, ghost, cursor, motion }]
    meta     = nil,
    clock    = 0.0,
    duration = 0.0,
    speedIdx = 1,
    paused   = false,
    hudText  = nil,
}

-- Bumped by stopPlayback (and each startPlayback). An in-flight startPlayback
-- captures the value and bails out the moment it changes — so /replaystop or
-- a replacement scene arriving DURING the yielding model-load phase can't
-- leave orphaned ghosts or a second concurrent render loop.
local playToken = 0

local function currentSpeed()
    return Config.Playback.Speeds[playback.speedIdx] or 1.0
end

local function resetCursors()
    for _, part in ipairs(playback.parts) do part.cursor = 1 end
end

local function stopPlayback(silent)
    playToken = playToken + 1  -- aborts any startPlayback still loading models
    if not playback.active and not playback.loading and not playback.incoming then return end
    for _, part in ipairs(playback.parts) do
        if part.ghost then
            Game.DeleteGhost(part.ghost)
            part.ghost = nil
        end
    end
    playback.active, playback.loading, playback.incoming = false, false, nil
    playback.parts, playback.meta = {}, nil
    playback.hudText = nil
    Game.HideTextUI()
    if not silent then
        Game.Notify({ title = 'Replay', description = 'Reconstruction ended.', type = 'inform' })
    end
end

-- Shortest-arc heading interpolation (359° -> 1° must not spin the ghost).
local function lerpHeading(a, b, alpha)
    local diff = (b - a + 180.0) % 360.0 - 180.0
    return (a + diff * alpha) % 360.0
end

-- Locomotion bucket for the ghost's anim, from recorded speed + flags.
local function motionState(speed, flags)
    if flags % (FLAG_DEAD * 2) >= FLAG_DEAD then return 'dead' end
    if speed < 0.4 then return 'idle' end
    if speed < 2.2 then return 'walk' end
    if speed < 5.0 then return 'run' end
    return 'sprint'
end

-- Advance one participant to `clock` ms and render it.
local function renderPart(part, clock)
    local frames = part.frames
    -- Cursor supports rewind: fall back to the start when we've scrubbed back.
    if frames[part.cursor].t > clock then part.cursor = 1 end
    while part.cursor < #frames - 1 and frames[part.cursor + 1].t <= clock do
        part.cursor = part.cursor + 1
    end

    local a = frames[part.cursor]
    local b = frames[math.min(part.cursor + 1, #frames)]
    local span = b.t - a.t
    local alpha = span > 0 and math.min(math.max((clock - a.t) / span, 0.0), 1.0) or 0.0

    local x = a.x + (b.x - a.x) * alpha
    local y = a.y + (b.y - a.y) * alpha
    local z = a.z + (b.z - a.z) * alpha
    local h = lerpHeading(a.h, b.h, alpha)
    local speed = a.s + (b.s - a.s) * alpha

    if part.ghost then
        Game.SetGhostTransform(part.ghost, x, y, z, h)
        local state = motionState(speed, a.f)
        if state ~= part.motion then
            part.motion = state
            Game.ApplyGhostMotion(part.ghost, state)
        end
        if a.w ~= part.weapon then
            part.weapon = a.w
            Game.SetGhostWeapon(part.ghost, a.w)
        end
    end

    Game.Draw3DText(x, y, z + 1.1, part.name, 200, 220, 255)

    -- Muzzle-flash evidence marker at recorded shot frames.
    local shot = (a.f % (FLAG_SHOOT * 2) >= FLAG_SHOOT)
        or (b.f % (FLAG_SHOOT * 2) >= FLAG_SHOOT)
    if shot then
        Game.DrawShotMarker(x, y, z)
        Game.Draw3DText(x, y, z + 1.35, 'SHOT', 255, 60, 60)
    end
end

local function fmtClock(ms)
    local total = math.max(math.floor(ms / 1000), 0)
    return ('%d:%02d'):format(math.floor(total / 60), total % 60)
end

local function updateHud()
    local text = ('**REPLAY #%d** — %s  \n%s / %s · %.2gx%s  \n[SPACE] pause · [←/→] scrub · [↑/↓] speed · [X] stop')
        :format(playback.meta.sceneId, playback.meta.label,
            fmtClock(playback.clock), fmtClock(playback.duration),
            currentSpeed(), playback.paused and ' · PAUSED' or '')
    if text ~= playback.hudText then
        playback.hudText = text
        Game.ShowTextUI(text)
    end
end

local function handleControls()
    if Game.PlaybackControlPressed('pause') then
        playback.paused = not playback.paused
    end
    if Game.PlaybackControlPressed('scrubBack') then
        playback.clock = math.max(playback.clock - Config.Playback.ScrubSeconds * 1000, 0.0)
        resetCursors()
    end
    if Game.PlaybackControlPressed('scrubFwd') then
        playback.clock = math.min(playback.clock + Config.Playback.ScrubSeconds * 1000, playback.duration)
    end
    if Game.PlaybackControlPressed('speedUp') then
        playback.speedIdx = math.min(playback.speedIdx + 1, #Config.Playback.Speeds)
    end
    if Game.PlaybackControlPressed('speedDown') then
        playback.speedIdx = math.max(playback.speedIdx - 1, 1)
    end
    if Game.PlaybackControlPressed('stop') then
        stopPlayback()
    end
end

local function startPlayback()
    local scene = playback.incoming
    playback.incoming = nil
    if not scene or #scene.parts == 0 then
        Game.Notify({ title = 'Replay', description = 'Scene arrived empty.', type = 'error' })
        return
    end

    playToken = playToken + 1
    local token = playToken
    playback.loading = true    -- stopPlayback now acts on us instead of no-opping
    playback.meta = scene.meta
    playback.parts = scene.parts
    playback.duration = 0.0
    for _, part in ipairs(playback.parts) do
        part.duration = part.frames[#part.frames].t
        part.cursor = 1
        if part.duration > playback.duration then playback.duration = part.duration end
    end

    -- Spawn the ghosts at their first recorded frame (model loads yield, so
    -- this whole start runs inside the playback thread). Each yield is a
    -- window for /replaystop or a replacement scene — if the token moved,
    -- clean up whatever we spawned and bow out.
    local spawned = 0
    for _, part in ipairs(scene.parts) do
        local first = part.frames[1]
        part.ghost = Game.CreateGhostPed(part.model, Config.Playback.FallbackPedModel,
            { x = first.x, y = first.y, z = first.z }, first.h, Config.Playback.GhostAlpha)
        if token ~= playToken then
            for _, p in ipairs(scene.parts) do
                if p.ghost then
                    Game.DeleteGhost(p.ghost)
                    p.ghost = nil
                end
            end
            return
        end
        if part.ghost then spawned = spawned + 1 end
    end
    if spawned == 0 then
        stopPlayback(true)
        Game.Notify({ title = 'Replay', description = 'Could not materialise the reconstruction.', type = 'error' })
        return
    end

    playback.clock = 0.0
    playback.speedIdx = 1
    for i, sp in ipairs(Config.Playback.Speeds) do
        if sp == Config.Playback.DefaultSpeed then playback.speedIdx = i end
    end
    playback.paused = false
    playback.loading = false
    playback.active = true
    Game.Notify({
        title = 'Replay',
        description = ('Reconstructing scene #%d — %d participant(s).')
            :format(playback.meta.sceneId, #playback.parts),
        type = 'success',
    })

    -- Per-frame ONLY while a reconstruction is live — this thread exits the
    -- moment playback stops, so idle cost is zero (§ perf rule). The token
    -- guard ensures at most ONE render loop ever advances playback.clock,
    -- even if a replacement scene starts while this one is mid-frame.
    local lastNow = Game.Now()
    while playback.active and token == playToken do
        local now = Game.Now()
        local dt = now - lastNow
        lastNow = now

        if not playback.paused then
            playback.clock = playback.clock + dt * currentSpeed()
        end
        if playback.clock >= playback.duration then
            if Config.Playback.LoopPlayback then
                playback.clock = 0.0
                resetCursors()
            else
                stopPlayback()
                break
            end
        end

        for _, part in ipairs(playback.parts) do
            renderPart(part, playback.clock)
        end
        handleControls()
        if playback.active then updateHud() end

        Wait(0)
    end
end

-- --- scene streaming (meta -> participants -> ready) -----------------------

RegisterNetEvent('palm6_replay:playbackMeta', function(meta)
    stopPlayback(true)  -- one reconstruction at a time
    playback.incoming = { meta = meta, parts = {} }
end)

RegisterNetEvent('palm6_replay:playbackParticipant', function(p)
    local scene = playback.incoming
    if not scene then return end
    if #scene.parts >= Config.Incident.MaxParticipants then return end
    if type(p) ~= 'table' or type(p.frames) ~= 'table' or #p.frames < 2 then return end
    scene.parts[#scene.parts + 1] = { name = p.name, model = p.model, frames = p.frames }
end)

RegisterNetEvent('palm6_replay:playbackReady', function()
    if not playback.incoming then return end
    CreateThread(startPlayback)
end)

-- --- misc -------------------------------------------------------------------

RegisterNetEvent('palm6_replay:showSceneList', function(content)
    Game.ShowLogDialog('Recorded Scenes Nearby', content)
end)

RegisterCommand('replaystop', function()
    stopPlayback()
end, false)

AddEventHandler('onResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() then return end
    stopPlayback(true)
end)
