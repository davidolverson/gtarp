-- ============================================================================
-- palm6_fc_combat/client/main.lua
--
-- Pure presentation: fires the CHALLENGE, answers the prompt, picks a fighter,
-- runs the client 3-2-1 + model swap, squares up, and unwinds on teardown.
-- Every action is server-validated; a modified client only picks what to REQUEST.
-- Combat input (strike/block) is added by Task 7.
-- ============================================================================

local myPick = nil  -- { fighterId, styleId } — remembered so the model swap matches the pick

local function enabledClient()
    local ok, cfg = pcall(function() return exports.palm6_fc_core:Config() end)
    return ok and cfg and cfg.Enabled == true
end

-- CHALLENGE: ox_target eye on a nearby player.
CreateThread(function()
    Game.AddChallengeTarget(function(serverId)
        TriggerServerEvent('palm6_fc_combat:challenge', { targetServerId = serverId })
    end)
end)

-- CHALLENGE fallback: /fcchallenge <serverid>
RegisterCommand('fcchallenge', function(_, args)
    local sid = tonumber(args[1])
    if not sid then
        Game.Notify({ title = 'Fight Club', description = 'Usage: /fcchallenge [server id]', type = 'error' })
        return
    end
    TriggerServerEvent('palm6_fc_combat:challenge', { targetServerId = sid })
end, false)

RegisterNetEvent('palm6_fc_combat:challengePrompt', function(d)
    if type(d) ~= 'table' then return end
    local ok = Game.ConfirmDialog('Fight Challenge',
        ('**%s** wants to fight you at the ring. Accept?'):format(d.fromName or 'Someone'), d.ttl or 20)
    TriggerServerEvent(ok and 'palm6_fc_combat:accept' or 'palm6_fc_combat:decline')
end)

RegisterNetEvent('palm6_fc_combat:openSelect', function(d)
    if type(d) ~= 'table' then return end
    local ok, cfg = pcall(function() return exports.palm6_fc_core:Config() end)
    if not ok or not cfg then return end
    local opts = {}
    for _, f in ipairs(cfg.Fighters or {}) do
        opts[#opts + 1] = {
            title = f.name,
            description = ('Style: %s'):format(f.styleId or '?'),
            icon = 'fa-solid fa-user-ninja',
            onSelect = function()
                myPick = { fighterId = f.id, styleId = f.styleId }
                TriggerServerEvent('palm6_fc_combat:select', { fighterId = f.id, styleId = f.styleId })
            end,
        }
    end
    Game.OpenMenu('palm6_fc_select', 'Choose your fighter', opts)
end)

RegisterNetEvent('palm6_fc_combat:countdown', function(d)
    if type(d) ~= 'table' then return end
    local sec = tonumber(d.seconds) or 0
    if sec > 0 then
        -- COUNTDOWN: preload + model swap (uses the remembered pick, else the default the server also used)
        local ok, cfg = pcall(function() return exports.palm6_fc_core:Config() end)
        local pick = myPick or (ok and cfg and { fighterId = cfg.DefaultFighter, styleId = cfg.DefaultStyle }) or nil
        if pick then
            local f = exports.palm6_fc_core:GetFighter(pick.fighterId)
            if f and f.model then Game.SwapToFighter(f.model, pick.styleId) end
        end
        Game.RunCountdown(sec)
    else
        Game.Notify({ title = 'Fight Club', description = 'FIGHT!', type = 'inform', duration = 1500 })
    end
end)

-- Emitted by T10's palm6_fc_arena (T6 no longer emits squareUp — C7); this is a
-- pure consumer that places the local ped on its fight-mark.
RegisterNetEvent('palm6_fc_arena:squareUp', function(d)
    if type(d) ~= 'table' or type(d.coords) ~= 'table' then return end
    Game.SquareUp(d.coords, d.heading)
end)

RegisterNetEvent('palm6_fc_combat:teardown', function(d)
    -- matchId==0 is the boot "abort any fight" broadcast — always unwind.
    abortFinisherLocal()   -- T8: stop the synced scene + clear the handle BEFORE any unfreeze/timescale/cam (§11)
    Game.RestoreAppearance()
    myPick = nil
    pcall(function() lib.hideContext(false) end)
end)

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    Game.RestoreAppearance()
end)

-- ============================================================================
-- T7: LIVE fighter hardening loop + strike/KO/teardown reactions. Presentation
-- only; the server owns every number and validates every event.
-- ============================================================================

local Fighter = { matchId = false, hardening = false }

-- Clip name WITHIN the style's strike dict (server picks the dict; the clip is
-- pure feel — tune/replace in David's feel-test, zero logic impact).
local STRIKE_CLIP = {
    jab      = 'plyr_takedown_front_lefthook',
    cross    = 'plyr_takedown_front_lefthook',
    hook     = 'plyr_takedown_front_lefthook',
    uppercut = 'plyr_takedown_front_lefthook',
    body     = 'plyr_takedown_front_lefthook',
}

local function startHardening(matchId)
    if Fighter.hardening then return end
    Fighter.matchId = matchId
    Fighter.hardening = true
    CreateThread(function()
        while Fighter.hardening do
            Game.HardenFighterPed()
            Wait(0)                       -- re-assert every frame (§6)
        end
    end)
end

local function stopHardening()
    Fighter.hardening = false
    Fighter.matchId = false
    Game.RestoreFighterPed()
end

-- Drive hardening off our own player statebag. bagFilter nil + explicit own-bag
-- check because GetPlayerServerId is unreliable at script-load.
AddStateBagChangeHandler('fc:active', nil, function(bagName, _, value)
    if bagName ~= ('player:%d'):format(GetPlayerServerId(PlayerId())) then return end
    if value and value ~= false then
        startHardening(tonumber(value))
    else
        stopHardening()
    end
end)

-- Attacker's own swing (targeted to us; replication shows it to everyone else).
RegisterNetEvent('palm6_fc_combat:playClip', function(data)
    if type(data) ~= 'table' then return end
    local clip = STRIKE_CLIP[data.moveId] or 'plyr_takedown_front_lefthook'
    Game.PlayStrikeClip(data.animDict, clip)
end)

-- KO: stop re-asserting CanRagdoll(false) BEFORE ragdolling (§6 ordering) or the
-- next hardening frame no-ops SetPedToRagdoll.
RegisterNetEvent('palm6_fc_combat:koRagdoll', function(data)
    if type(data) ~= 'table' then return end
    Fighter.hardening = false
    Wait(0)
    Game.RagdollSelf()
    Fighter.matchId = false
end)

-- Canonical teardown (net-registered by T6). A second AddEventHandler runs
-- alongside T6's HUD/cam teardown to guarantee hardening is dropped + ped restored
-- (ring-out drops invincibility the instant this arrives).
AddEventHandler('palm6_fc_combat:teardown', function()
    stopHardening()
end)

-- ============================================================================
-- Blazin finisher (T8) -- client half. Runs the scene on THIS client's OWN ped
-- ONLY (§7): never drives the other ped. Interruptible -- abortFinisherLocal()
-- stops the scene task + clears the handle BEFORE unfreeze/timescale/cam (§11),
-- and is called at the TOP of the palm6_fc_combat:teardown handler (below). A
-- per-client `finisherActive` flag stops a torn-down player from being re-frozen.
-- ============================================================================
local FinCfg = exports.palm6_fc_core:Config()

local FINISHER_DICT        = 'mini@takedowns@front'
local FINISHER_ANIM_VICTIM = 'victim_takedown_front'   -- role tag: this recipient is the mash-side victim
local FINISHER_WINDUP_MS   = 800     -- MUST match the server constant (Fin server half)
local FINISHER_TIMESCALE   = 0.4     -- participant slow-mo (feel-test)

local finisherActive = false
local finisherScene  = nil
local finisherCam    = nil

local function stopFinisherCam()
    if finisherCam then
        RenderScriptCams(false, true, 300, true, true)
        DestroyCam(finisherCam, false)
        finisherCam = nil
    end
end

local function startFinisherCam(origin)
    finisherCam = CreateCamWithParams('DEFAULT_SCRIPTED_CAMERA',
        origin.x + 1.6, origin.y + 1.6, origin.z + 0.7, 0.0, 0.0, 0.0, 42.0, false, 2)
    SetCamActive(finisherCam, true)
    RenderScriptCams(true, false, 0, true, true)
    -- slow dolly toward the action over the full lock
    SetCamParams(finisherCam,
        origin.x + 2.4, origin.y + 2.4, origin.z + 1.0, 0.0, 0.0, 0.0, 42.0,
        FINISHER_WINDUP_MS + FinCfg.Blazin.SceneDurationMs)
end

-- Hard abort (KO / DC / void / resource-stop). Stops the scene task + clears the
-- handle FIRST, then drops timescale/cam and unfreezes (belt-and-suspenders
-- against a stranded frozen ped). GLOBAL so the T6 teardown handler can call it.
function abortFinisherLocal()
    if not finisherActive and not finisherScene then return end
    finisherActive = false
    finisherScene  = nil
    local ped = PlayerPedId()
    ClearPedTasksImmediately(ped)     -- kill the synced-scene task FIRST (§11 ordering)
    stopFinisherCam()
    SetTimeScale(1.0)
    ClearTimecycleModifier()
    FreezeEntityPosition(ped, false)
    -- invincibility / CanRagdoll are re-asserted by the T7 LIVE hardening loop
    -- (non-KO), or handled by the koRagdoll path (KO).
end

-- Soft end (non-KO scene finished): resume fighting, match still LIVE.
local function endFinisherLocal()
    if not finisherActive then return end
    finisherActive = false
    finisherScene  = nil
    stopFinisherCam()
    SetTimeScale(1.0)
    ClearTimecycleModifier()
    local ped = PlayerPedId()
    ClearPedTasks(ped)
    FreezeEntityPosition(ped, false)
end

RegisterNetEvent('palm6_fc_combat:finisher', function(d)
    if type(d) ~= 'table' or type(d.origin) ~= 'table' then return end
    if finisherActive then return end

    RequestAnimDict(d.sceneDict)
    local dl = GetGameTimer() + 2000
    while not HasAnimDictLoaded(d.sceneDict) and GetGameTimer() < dl do Wait(10) end
    if not HasAnimDictLoaded(d.sceneDict) then return end

    finisherActive = true
    local isVictim = (d.sceneAnim == FINISHER_ANIM_VICTIM)   -- role from the tailored clip

    -- Telegraph + mash window (BEFORE impact). Victim mashes JUMP to shave damage.
    PlaySoundFrontend(-1, 'CHECKPOINT_PERFECT', 'HUD_MINI_GAME_SOUNDSET', true)
    if isVictim then
        BeginTextCommandDisplayHelp('STRING')
        AddTextComponentSubstringPlayerName('~INPUT_JUMP~ mash to break the finisher!')
        EndTextCommandDisplayHelp(0, false, true, FINISHER_WINDUP_MS + FinCfg.Blazin.SceneDurationMs)
        CreateThread(function()
            while finisherActive do
                if IsControlJustPressed(0, 22) then   -- 22 = JUMP
                    TriggerServerEvent('palm6_fc_combat:break', { matchId = d.matchId })
                end
                Wait(0)
            end
        end)
    end

    Wait(FINISHER_WINDUP_MS)
    if not finisherActive then return end     -- aborted mid-windup (teardown / KO)

    local ped = PlayerPedId()
    SetEntityCoordsNoOffset(ped, d.origin.x, d.origin.y, d.origin.z, false, false, false)
    SetEntityHeading(ped, d.heading)
    FreezeEntityPosition(ped, true)
    SetEntityInvincible(ped, true)
    SetPedCanRagdoll(ped, false)

    finisherScene = CreateSynchronizedScene(d.origin.x, d.origin.y, d.origin.z, 0.0, 0.0, d.heading, 2)
    SetSynchronizedSceneLooped(finisherScene, false)
    TaskSynchronizedScene(ped, finisherScene, d.sceneDict, d.sceneAnim, 8.0, -8.0, 0, 0, 0, 0)

    startFinisherCam(d.origin)
    SetTimeScale(FINISHER_TIMESCALE)                 -- participant-only (spectators never got this event)
    PlaySoundFrontend(-1, 'Bed', 'MP_LOBBY_SOUNDS', true)   -- finisher stinger (T11 finalizes the sound set)

    -- Non-KO end: server applies damage at the SAME total; if it wasn't a KO, no
    -- teardown arrives, so we self-restore and resume fighting.
    SetTimeout(FinCfg.Blazin.SceneDurationMs, function()
        if finisherActive then endFinisherLocal() end
    end)
end)
