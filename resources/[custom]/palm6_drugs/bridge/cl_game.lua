-- ============================================================================
-- palm6_drugs/bridge/cl_game.lua
--
-- Game adapter (client). The ONLY file in this resource that calls GTA
-- natives, ox_target, or ox_lib UI. client/main.lua calls Game.* only, so the
-- plot / mixing-station / street-buyer flows port to GTA VI by rewriting THIS
-- FILE. See docs/GTA6-READINESS.md (Section 3, the bridge pattern).
--
-- Interactions use ox_target sphere zones when ox_target is started, else a
-- lib.points marker with an E prompt — the same dual pattern as
-- palm6_counterfeit / palm6_flashdrop. Nothing polls per-frame unless the
-- player is inside a fallback marker's radius.
-- ============================================================================

Game = {}

local hasTarget = GetResourceState('ox_target') == 'started'

-- ---------------------------------------------------------------------------
-- World / position
-- ---------------------------------------------------------------------------

function Game.GetPlayerCoords()
    local p = GetEntityCoords(PlayerPedId())
    return { x = p.x, y = p.y, z = p.z }
end

function Game.DistanceBetween(a, b)
    return #(vector3(a.x, a.y, a.z) - vector3(b.x, b.y, b.z))
end

-- ---------------------------------------------------------------------------
-- Scene dressing: the street-buyer NPC (existing game asset only)
-- ---------------------------------------------------------------------------

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

function Game.DeletePed(ped)
    if ped and DoesEntityExist(ped) then DeleteEntity(ped) end
end

-- ---------------------------------------------------------------------------
-- Interactions. Game.CreateInteraction returns an opaque handle for
-- Game.RemoveInteraction. ox_target sphere when present; marker + E prompt
-- fallback otherwise (poll only while inside the point's radius).
-- ---------------------------------------------------------------------------

function Game.CreateInteraction(id, coords, radius, label, icon, onSelect)
    if hasTarget then
        local zoneId = exports.ox_target:addSphereZone({
            coords = vector3(coords.x, coords.y, coords.z),
            radius = radius,
            debug = Config.Debug,
            options = {
                {
                    name = ('palm6_drugs_%s'):format(id),
                    icon = icon or 'fas fa-cannabis',
                    label = label,
                    onSelect = onSelect,
                    distance = radius,
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
            80, 200, 80, 200, false, true, 2, false, nil, nil, false)
        if self.currentDistance < radius then
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
-- Blips (fallback dispatch ping only — this resource has no map-blip surface)
-- ---------------------------------------------------------------------------

function Game.ShowDispatchBlip(coords, label, durationSec)
    local b = AddBlipForCoord(coords.x, coords.y, coords.z)
    SetBlipSprite(b, 51)
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
-- UI: notifications, progress, menus, text input
-- ---------------------------------------------------------------------------

function Game.Notify(opts)
    lib.notify(opts)
end

-- Cancellable progress bar. Returns true if it completed.
function Game.ProgressBar(label, durationMs)
    return lib.progressBar({
        duration = durationMs,
        label = label,
        useWhileDead = false,
        canCancel = true,
        disable = { move = true, car = true, combat = true },
    }) and true or false
end

-- Context menu. `options` = { {title, description?, icon?, disabled?, onSelect?}, ... }.
-- `menu` is the parent id to return to via the header back-arrow (optional).
function Game.OpenMenu(id, title, options, menu)
    lib.registerContext({ id = id, title = title, menu = menu, options = options })
    lib.showContext(id)
end

-- Single free-text prompt (product branding). Returns the string, or nil if
-- cancelled / empty. Length is also re-clamped server-side.
function Game.InputText(header, label, maxLength, placeholder)
    local res = lib.inputDialog(header, {
        {
            type = 'input',
            label = label,
            placeholder = placeholder,
            required = true,
            min = 1,
            max = maxLength,
        },
    })
    if not res or not res[1] then return nil end
    local s = tostring(res[1]):gsub('^%s+', ''):gsub('%s+$', '')
    if #s == 0 then return nil end
    return s
end
