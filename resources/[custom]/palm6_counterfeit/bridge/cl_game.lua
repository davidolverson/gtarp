-- ============================================================================
-- palm6_counterfeit/bridge/cl_game.lua
--
-- Game adapter (client). The ONLY file in this resource that calls GTA
-- natives, ox_target, or ox_lib UI. client/main.lua calls Game.* only, so
-- the printer/sink/fence/pen flows port to GTA VI by rewriting THIS FILE.
-- See docs/GTA6-READINESS.md (Section 3, the bridge pattern).
--
-- Interactions use ox_target sphere zones when ox_target is started, else a
-- lib.points marker with an E prompt — the same dual pattern as
-- palm6_flashdrop. Nothing here polls per-frame unless the player is inside
-- a fallback marker's 16m radius.
-- ============================================================================

Game = {}

local hasTarget = GetResourceState('ox_target') == 'started'

-- ---------------------------------------------------------------------------
-- World / position
-- ---------------------------------------------------------------------------

-- Local player position as {x,y,z}.
function Game.GetPlayerCoords()
    local p = GetEntityCoords(PlayerPedId())
    return { x = p.x, y = p.y, z = p.z }
end

-- Distance in metres between two coord tables (accepts vector3 too).
function Game.DistanceBetween(a, b)
    return #(vector3(a.x, a.y, a.z) - vector3(b.x, b.y, b.z))
end

-- Scan for the closest whitelisted anchor prop near the player. Returns the
-- matching MODEL NAME, or nil. Map props are client-side only, which is why
-- this scan cannot live on the server (see shared/config.lua for the trust
-- analysis — this is placement flavor, not a security gate).
function Game.FindNearbyAnchorProp(models, radius)
    local c = GetEntityCoords(PlayerPedId())
    for _, model in ipairs(models) do
        local obj = GetClosestObjectOfType(c.x, c.y, c.z, radius, joaat(model), false, false, false)
        if obj and obj ~= 0 then return model end
    end
    return nil
end

-- ---------------------------------------------------------------------------
-- Scene dressing: NPC peds (existing game assets only — no custom models)
-- ---------------------------------------------------------------------------

-- Spawn a frozen, invincible, non-reactive NPC. Returns the ped handle.
function Game.SpawnPed(model, coords, heading)
    local hash = joaat(model)
    if not IsModelValid(hash) then return nil end
    RequestModel(hash)
    local deadline = GetGameTimer() + 5000
    while not HasModelLoaded(hash) and GetGameTimer() < deadline do Wait(50) end
    if not HasModelLoaded(hash) then return nil end
    local ped = CreatePed(4, hash, coords.x, coords.y, coords.z - 1.0, heading or 0.0, false, true)
    SetEntityInvincible(ped, true)
    FreezeEntityPosition(ped, true)
    SetBlockingOfNonTemporaryEvents(ped, true)
    SetModelAsNoLongerNeeded(hash)
    return ped
end

-- Delete a spawned ped.
function Game.DeletePed(ped)
    if ped and DoesEntityExist(ped) then DeleteEntity(ped) end
end

-- ---------------------------------------------------------------------------
-- Blips
-- ---------------------------------------------------------------------------

-- Vague AREA blip (the police heat ping): a translucent radius circle, auto
-- removed after `durationSec`. Returns nothing — lifecycle is self-managed.
function Game.ShowAreaPing(coords, radius, label, durationSec, colour, alpha)
    local area = AddBlipForRadius(coords.x, coords.y, coords.z, radius + 0.0)
    SetBlipColour(area, colour or 1)
    SetBlipAlpha(area, alpha or 80)
    SetBlipHighDetail(area, true)
    -- A small centre marker carries the label (radius blips cannot).
    local mark = AddBlipForCoord(coords.x, coords.y, coords.z)
    SetBlipSprite(mark, 161)
    SetBlipColour(mark, colour or 1)
    SetBlipScale(mark, 0.8)
    SetBlipAsShortRange(mark, false)
    BeginTextCommandSetBlipName('STRING')
    AddTextComponentSubstringPlayerName(label or 'Suspicious activity')
    EndTextCommandSetBlipName(mark)
    SetTimeout(math.max(10, durationSec or 120) * 1000, function()
        if DoesBlipExist(area) then RemoveBlip(area) end
        if DoesBlipExist(mark) then RemoveBlip(mark) end
    end)
end

-- Point dispatch blip (fallback police alert), auto removed.
function Game.ShowDispatchBlip(coords, label, durationSec)
    local b = AddBlipForCoord(coords.x, coords.y, coords.z)
    SetBlipSprite(b, 161)
    SetBlipColour(b, 1)
    SetBlipScale(b, 1.0)
    SetBlipFlashes(b, true)
    SetBlipAsShortRange(b, false)
    BeginTextCommandSetBlipName('STRING')
    AddTextComponentSubstringPlayerName(label or 'Dispatch')
    EndTextCommandSetBlipName(b)
    SetTimeout(math.max(10, durationSec or 60) * 1000, function()
        if DoesBlipExist(b) then RemoveBlip(b) end
    end)
end

-- ---------------------------------------------------------------------------
-- Interactions. Game.CreateInteraction returns an opaque handle for
-- Game.RemoveInteraction. ox_target when present; marker + E prompt fallback
-- otherwise (poll only while inside the point's radius).
-- ---------------------------------------------------------------------------

function Game.CreateInteraction(id, coords, label, icon, onSelect)
    if hasTarget then
        local zoneId = exports.ox_target:addSphereZone({
            coords = vector3(coords.x, coords.y, coords.z),
            radius = Config.InteractRadius,
            debug = Config.Debug,
            options = {
                {
                    name = ('palm6_counterfeit_%s'):format(id),
                    icon = icon or 'fas fa-money-bill',
                    label = label,
                    onSelect = onSelect,
                    distance = Config.InteractRadius,
                },
            },
        })
        return { kind = 'target', zoneId = zoneId }
    end

    local point = lib.points.new({
        coords = vector3(coords.x, coords.y, coords.z),
        distance = 16.0,
    })
    function point:nearby()
        DrawMarker(2, self.coords.x, self.coords.y, self.coords.z + 0.4,
            0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.3, 0.3, 0.3,
            255, 255, 255, 200, false, true, 2, false, nil, nil, false)
        if self.currentDistance < Config.InteractRadius then
            BeginTextCommandDisplayHelp('STRING')
            AddTextComponentSubstringPlayerName(('Press ~INPUT_PICKUP~ %s'):format(label))
            EndTextCommandDisplayHelp(0, false, true, -1)
            if IsControlJustReleased(0, 38) then onSelect() end
        end
    end
    return { kind = 'point', point = point }
end

function Game.RemoveInteraction(handle)
    if not handle then return end
    if handle.kind == 'target' and handle.zoneId then
        pcall(function() exports.ox_target:removeZone(handle.zoneId) end)
    elseif handle.kind == 'point' and handle.point and handle.point.remove then
        handle.point:remove()
    end
end

-- ---------------------------------------------------------------------------
-- UI: notifications, progress, minigame, menus, dialogs
-- ---------------------------------------------------------------------------

-- Notify the local player.
function Game.Notify(opts)
    lib.notify(opts)
end

-- Blocking progress bar. Returns true if it completed, false if cancelled.
function Game.ProgressBar(label, durationMs)
    return lib.progressBar({
        duration = durationMs,
        label = label,
        useWhileDead = false,
        canCancel = true,
        disable = { move = true, car = true, combat = true },
    }) and true or false
end

-- Steady-hands minigame (detector pen). Returns true on success.
function Game.SkillCheck(difficulty)
    return lib.skillCheck(difficulty) and true or false
end

-- Context menu. `options` = { {title, description?, icon?, onSelect?}, ... }.
function Game.OpenMenu(id, title, options)
    lib.registerContext({ id = id, title = title, options = options })
    lib.showContext(id)
end

-- Read-only report dialog (pen verdicts).
function Game.ShowReport(title, content)
    lib.alertDialog({
        header = title,
        content = content,
        centered = true,
        cancel = false,
    })
end
