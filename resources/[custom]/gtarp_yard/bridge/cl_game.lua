-- ============================================================================
-- gtarp_yard/bridge/cl_game.lua
--
-- Game adapter (client). The ONLY file in this resource that calls GTA natives,
-- ox_target, or ox_lib UI. client/main.lua calls Game.* only, so the three
-- station interactions + menus port to GTA VI by rewriting THIS FILE. See
-- docs/GTA6-READINESS.md §3 (the bridge pattern).
--
-- Interactions use ox_target sphere zones when ox_target is started, else a
-- lib.points marker with an E prompt — the same dual pattern as gtarp_drugs.
-- Nothing polls per-frame unless the player is inside a fallback marker.
-- ============================================================================

Game = {}

local hasTarget = GetResourceState('ox_target') == 'started'

-- ---------------------------------------------------------------------------
-- Interactions
-- ---------------------------------------------------------------------------
function Game.CreateInteraction(id, coords, radius, label, icon, onSelect)
    if hasTarget then
        local zoneId = exports.ox_target:addSphereZone({
            coords = vector3(coords.x, coords.y, coords.z),
            radius = radius,
            debug = Config.Debug,
            options = {
                {
                    name = ('gtarp_yard_%s'):format(id),
                    icon = icon or 'fas fa-hammer',
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
            120, 170, 220, 200, false, true, 2, false, nil, nil, false)
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
-- Blips
-- ---------------------------------------------------------------------------
function Game.CreateBlip(coords, sprite, colour, scale, label)
    local b = AddBlipForCoord(coords.x, coords.y, coords.z)
    SetBlipSprite(b, sprite or 1)
    SetBlipColour(b, colour or 0)
    SetBlipScale(b, scale or 0.8)
    SetBlipAsShortRange(b, true)
    BeginTextCommandSetBlipName('STRING')
    AddTextComponentString(label or 'Prison Yard')
    EndTextCommandSetBlipName(b)
    return b
end

function Game.RemoveBlip(b)
    if b and DoesBlipExist(b) then RemoveBlip(b) end
end

-- ---------------------------------------------------------------------------
-- UI
-- ---------------------------------------------------------------------------
function Game.Notify(opts)
    lib.notify(opts)
end

-- Cancellable progress bar. Returns true only if it ran to completion.
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
function Game.OpenMenu(id, title, options, menu)
    lib.registerContext({ id = id, title = title, menu = menu, options = options })
    lib.showContext(id)
end

-- Ask for a quantity (1..maxQty). Returns an integer, or nil if cancelled. The
-- server re-clamps and re-prices, so this is UX only — nothing here is trusted.
function Game.InputNumber(header, label, maxQty)
    local res = lib.inputDialog(header, {
        {
            type = 'number',
            label = label,
            default = 1,
            min = 1,
            max = maxQty,
            required = true,
        },
    })
    if not res or not res[1] then return nil end
    local n = math.floor(tonumber(res[1]) or 0)
    if n < 1 then return nil end
    return n
end

-- Yes/no confirmation. Returns true only on explicit confirm.
function Game.Confirm(header, content)
    local ok = lib.alertDialog({
        header = header,
        content = content,
        centered = true,
        cancel = true,
    })
    return ok == 'confirm'
end
