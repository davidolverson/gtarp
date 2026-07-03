-- ============================================================================
-- gtarp_flashdrop/bridge/cl_game.lua
--
-- Game adapter (client). The ONLY file in this resource that calls GTA
-- natives, ox_target, or ox_lib UI. client/main.lua calls Game.* only, so
-- the drop-day flow (announce, blip, line, checkout, market menus) ports to
-- GTA VI by rewriting THIS FILE. See docs/GTA6-READINESS.md (Section 3).
--
-- Interactions use ox_target sphere zones when ox_target is started, else a
-- lib.points marker with an E prompt — the same dual pattern as
-- ox_inventory_overrides/client/render.lua. Nothing here polls per-frame
-- unless the player is inside a fallback marker's 16m radius.
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

-- ---------------------------------------------------------------------------
-- Blips
-- ---------------------------------------------------------------------------

-- Map blip for a live/revealed drop. Flashes if configured. Returns handle.
function Game.CreateDropBlip(coords, label)
    local b = AddBlipForCoord(coords.x, coords.y, coords.z)
    SetBlipSprite(b, Config.DropBlip.sprite)
    SetBlipColour(b, Config.DropBlip.colour)
    SetBlipScale(b, Config.DropBlip.scale)
    SetBlipAsShortRange(b, false)
    if Config.DropBlip.flashes then SetBlipFlashes(b, true) end
    BeginTextCommandSetBlipName('STRING')
    AddTextComponentSubstringPlayerName(label)
    EndTextCommandSetBlipName(b)
    return b
end

-- Permanent short-range blip (consignment boutique). Returns handle.
function Game.CreateShopBlip(coords, blip)
    local b = AddBlipForCoord(coords.x, coords.y, coords.z)
    SetBlipSprite(b, blip.sprite or 617)
    SetBlipColour(b, blip.colour or 0)
    SetBlipScale(b, blip.scale or 0.7)
    SetBlipAsShortRange(b, true)
    BeginTextCommandSetBlipName('STRING')
    AddTextComponentSubstringPlayerName(blip.label or 'Shop')
    EndTextCommandSetBlipName(b)
    return b
end

-- Remove a blip by handle.
function Game.RemoveBlip(handle)
    if handle and DoesBlipExist(handle) then RemoveBlip(handle) end
end

-- ---------------------------------------------------------------------------
-- Scene dressing: NPC peds + the pop-up drop table (existing game assets
-- only — no custom models).
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

-- Spawn a static prop (the drop table). Returns the object handle, or nil.
function Game.SpawnProp(model, coords, zOffset)
    local hash = joaat(model)
    if not IsModelValid(hash) then return nil end
    RequestModel(hash)
    local deadline = GetGameTimer() + 5000
    while not HasModelLoaded(hash) and GetGameTimer() < deadline do Wait(50) end
    if not HasModelLoaded(hash) then return nil end
    local obj = CreateObject(hash, coords.x, coords.y, coords.z + (zOffset or 0.0), false, false, false)
    PlaceObjectOnGroundProperly(obj)
    FreezeEntityPosition(obj, true)
    SetModelAsNoLongerNeeded(hash)
    return obj
end

-- Delete a spawned prop.
function Game.DeleteProp(obj)
    if obj and DoesEntityExist(obj) then DeleteEntity(obj) end
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
                    name = ('gtarp_flashdrop_%s'):format(id),
                    icon = icon or 'fas fa-shoe-prints',
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
-- UI: notifications, announcements, progress, minigame, menus, dialogs
-- ---------------------------------------------------------------------------

-- Notify the local player.
function Game.Notify(opts)
    lib.notify(opts)
end

-- City-wide announcement styling (drop riddles / reveals).
function Game.Announce(title, msg, t)
    lib.notify({
        title = title, description = msg, type = t or 'inform',
        duration = 12000, position = 'top',
    })
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

-- Steady-hands minigame (legit check). Returns true on success.
function Game.SkillCheck(difficulty)
    return lib.skillCheck(difficulty) and true or false
end

-- Context menu. `options` = { {title, description?, icon?, disabled?, onSelect?}, ... }.
function Game.OpenMenu(id, title, options)
    lib.registerContext({ id = id, title = title, options = options })
    lib.showContext(id)
end

-- Single-field number input. Returns the number, or nil if dismissed.
function Game.InputNumber(title, label, min, max, default)
    local input = lib.inputDialog(title, {
        { type = 'number', label = label, min = min, max = max, default = default, required = true },
    })
    if not input or not input[1] then return nil end
    return tonumber(input[1])
end

-- Read-only report dialog (legit-check verdicts, provenance tape).
function Game.ShowReport(title, content)
    lib.alertDialog({
        header = title,
        content = content,
        centered = true,
        cancel = false,
    })
end
