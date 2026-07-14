-- ============================================================================
-- palm6_replay/bridge/cl_game.lua
--
-- Game adapter (client). The ONLY file in this resource that calls GTA
-- natives or ox_lib UI. client/main.lua calls Game.* only — the ring-buffer
-- bookkeeping, frame encoding, and playback/interpolation math all live
-- there and port to GTA VI by rewriting THIS FILE.
-- See docs/GTA6-READINESS.md (Section 3, the bridge pattern).
--
-- Deliberately ABSENT: StartRecording / StopRecordingAndSaveClip / any
-- Rockstar Editor native. This resource is telemetry-only; the recipe's
-- qbx_smallresources owns clip recording and we never touch it.
-- ============================================================================

Game = {}

-- ---------------------------------------------------------------------------
-- Time / position primitives
-- ---------------------------------------------------------------------------

-- Monotonic client clock in ms (frame timestamps + playback pacing).
function Game.Now()
    return GetGameTimer()
end

-- Local player position as {x,y,z}.
function Game.GetPlayerCoords()
    local p = GetEntityCoords(PlayerPedId())
    return { x = p.x, y = p.y, z = p.z }
end

-- Distance in metres between two coord tables (accepts vector3 too).
function Game.DistanceBetween(a, b)
    return #(vector3(a.x, a.y, a.z) - vector3(b.x, b.y, b.z))
end

-- ---------------------------------------------------------------------------
-- Telemetry sampling (one call per ring-buffer tick)
-- ---------------------------------------------------------------------------

-- Raw snapshot of the local ped for one 4 Hz sample. The compact frame
-- encoding (bitfield, rounding) is client logic's job — this just reads.
function Game.SampleTelemetry()
    local ped = PlayerPedId()
    local c = GetEntityCoords(ped)
    return {
        x = c.x, y = c.y, z = c.z,
        heading   = GetEntityHeading(ped),
        speed     = GetEntitySpeed(ped),
        weapon    = GetSelectedPedWeapon(ped),
        shooting  = IsPedShooting(ped),
        aiming    = IsPlayerFreeAiming(PlayerId()),
        inVehicle = IsPedInAnyVehicle(ped, false),
        ragdoll   = IsPedRagdoll(ped),
        dead      = IsEntityDead(ped),
    }
end

-- Local ped's model hash (stored with the buffer so the ghost wears the
-- right body).
function Game.GetPedModelHash()
    return GetEntityModel(PlayerPedId())
end

-- Cheap shot poll — IsPedShooting is only true on actual firing frames, so
-- the recorder polls this faster than it records (single gunshots would slip
-- between 4 Hz samples otherwise).
function Game.IsLocalPedShooting()
    return IsPedShooting(PlayerPedId())
end

-- ---------------------------------------------------------------------------
-- Ghost peds (the re-enactment)
-- ---------------------------------------------------------------------------

local ghostAnim = {}  -- [ped] = last motion clip applied (avoid re-tasking)

local function toModelHash(model)
    if type(model) == 'number' then return model end
    -- Stored hashes arrive as strings ("1885233650"); only joaat real names.
    return tonumber(model) or joaat(model)
end

local function loadModel(hash, timeoutMs)
    if not IsModelValid(hash) then return false end
    RequestModel(hash)
    local deadline = GetGameTimer() + (timeoutMs or 3000)
    while not HasModelLoaded(hash) do
        if GetGameTimer() > deadline then return false end
        Wait(25)
    end
    return true
end

-- Spawn a translucent, non-colliding, local-only re-enactment ped. Falls
-- back to `fallbackModel` when the recorded model won't load. Returns a ped
-- handle, or nil.
function Game.CreateGhostPed(model, fallbackModel, coords, heading, alpha)
    local hash = toModelHash(model)
    if not loadModel(hash) then
        hash = toModelHash(fallbackModel)
        if not loadModel(hash) then return nil end
    end

    -- Local-only (not networked): the reconstruction renders for the officer
    -- who launched it; squadmates run /replay themselves to watch in sync.
    local ped = CreatePed(4, hash, coords.x, coords.y, coords.z, heading or 0.0, false, false)
    SetModelAsNoLongerNeeded(hash)
    if not ped or ped == 0 then return nil end

    SetEntityAlpha(ped, alpha or 150, false)
    SetEntityCollision(ped, false, false)
    SetEntityInvincible(ped, true)
    SetBlockingOfNonTemporaryEvents(ped, true)
    FreezeEntityPosition(ped, true)  -- we drive position; physics stays out
    return ped
end

-- Hard-place a ghost for the current playback frame.
function Game.SetGhostTransform(ped, x, y, z, heading)
    if not DoesEntityExist(ped) then return end
    SetEntityCoordsNoOffset(ped, x, y, z, false, false, false)
    SetEntityHeading(ped, heading or 0.0)
end

-- Give the ghost a locomotion clip matching its recorded state so it reads
-- as walking/running rather than a statue on rails. `state` is one of:
-- 'idle' | 'walk' | 'run' | 'sprint' | 'dead'. Re-tasks only on change.
local MOTION_CLIPS = {
    idle   = { dict = 'move_m@generic', clip = 'idle' },
    walk   = { dict = 'move_m@generic', clip = 'walk' },
    run    = { dict = 'move_m@generic', clip = 'run' },
    sprint = { dict = 'move_m@generic', clip = 'sprint' },
    dead   = { dict = 'dead',           clip = 'dead_a' },
}

function Game.ApplyGhostMotion(ped, state)
    if not DoesEntityExist(ped) then return end
    if ghostAnim[ped] == state then return end
    local m = MOTION_CLIPS[state] or MOTION_CLIPS.idle
    RequestAnimDict(m.dict)
    if HasAnimDictLoaded(m.dict) then
        TaskPlayAnim(ped, m.dict, m.clip, 4.0, -4.0, -1, 1, 0.0, false, false, false)
        ghostAnim[ped] = state
    end
    -- If the dict isn't in yet, we simply retry next state change / tick —
    -- never worth blocking the playback loop for.
end

-- Put the recorded weapon in the ghost's hands (evidence legibility — the
-- squad sees who was holding what). Unknown hashes just leave it unarmed.
function Game.SetGhostWeapon(ped, weaponHash)
    if not DoesEntityExist(ped) then return end
    RemoveAllPedWeapons(ped, true)
    if weaponHash and weaponHash ~= 0 and IsWeaponValid(weaponHash) then
        GiveWeaponToPed(ped, weaponHash, 0, false, true)
        SetCurrentPedWeapon(ped, weaponHash, true)
    end
end

function Game.DeleteGhost(ped)
    ghostAnim[ped] = nil
    if ped and DoesEntityExist(ped) then DeleteEntity(ped) end
end

-- ---------------------------------------------------------------------------
-- Playback overlays (drawn per-frame while a reconstruction runs)
-- ---------------------------------------------------------------------------

-- Muzzle-flash evidence marker: a red chevron pulsing over a ghost at its
-- recorded shot frames — first-shooter disputes end here.
function Game.DrawShotMarker(x, y, z)
    DrawMarker(27,                       -- flat ring on the ground
        x, y, z - 0.95,
        0.0, 0.0, 0.0, 0.0, 0.0, 0.0,
        0.9, 0.9, 0.9,
        255, 40, 40, 200,
        false, false, 2, false, nil, nil, false)
    DrawMarker(0,                        -- chevron overhead
        x, y, z + 1.15,
        0.0, 0.0, 0.0, 0.0, 180.0, 0.0,
        0.25, 0.25, 0.25,
        255, 40, 40, 220,
        true, false, 2, true, nil, nil, false)
end

-- Small floating label above a ghost (participant name / SHOT tag).
function Game.Draw3DText(x, y, z, text, r, g, b)
    local onScreen, sx, sy = World3dToScreen2d(x, y, z)
    if not onScreen then return end
    SetTextScale(0.32, 0.32)
    SetTextFont(4)
    SetTextColour(r or 255, g or 255, b or 255, 215)
    SetTextCentre(true)
    SetTextOutline()
    BeginTextCommandDisplayText('STRING')
    AddTextComponentSubstringPlayerName(text)
    EndTextCommandDisplayText(sx, sy)
end

-- Persistent controls hint while playback runs (ox_lib text UI).
function Game.ShowTextUI(text)
    lib.showTextUI(text, { position = 'bottom-center' })
end

function Game.HideTextUI()
    lib.hideTextUI()
end

-- ---------------------------------------------------------------------------
-- Playback controls
-- ---------------------------------------------------------------------------

-- Named playback keys -> GTA control ids (keyboard):
--   pause = SPACE, scrub back/fwd = LEFT/RIGHT arrows,
--   speed up/down = UP/DOWN arrows, stop = X.
local CONTROLS = {
    pause     = 22,   -- INPUT_JUMP (space)
    scrubBack = 174,  -- INPUT_CELLPHONE_LEFT
    scrubFwd  = 175,  -- INPUT_CELLPHONE_RIGHT
    speedUp   = 172,  -- INPUT_CELLPHONE_UP
    speedDown = 173,  -- INPUT_CELLPHONE_DOWN
    stop      = 73,   -- INPUT_VEH_DUCK (X)
}

-- Was the named playback control just pressed this frame?
function Game.PlaybackControlPressed(name)
    local id = CONTROLS[name]
    if not id then return false end
    DisableControlAction(0, id, true)  -- don't jump/duck while scrubbing
    return IsDisabledControlJustPressed(0, id)
end

-- ---------------------------------------------------------------------------
-- Dialogs / notifications
-- ---------------------------------------------------------------------------

-- Read-only text dialog (the nearby-scene list).
function Game.ShowLogDialog(title, content)
    lib.alertDialog({
        header = title,
        content = content,
        centered = true,
        cancel = false,
    })
end

-- Notify the local player.
function Game.Notify(opts)
    lib.notify(opts)
end
