-- ============================================================================
-- palm6_fc_arena/bridge/cl_game.lua
-- Game adapter (client). The ONLY client file calling GTA natives / ox_lib.
-- Presentation only — every fight authority (HP, winner, rep, proximity) is
-- server-owned elsewhere; nothing here is security-sensitive.
-- ============================================================================
Game = {}

local hasTarget = GetResourceState('ox_target') == 'started'
local INTERACT_RADIUS = 2.5

function Game.Dist(a, b)
    local dx, dy, dz = a.x - b.x, a.y - b.y, (a.z or 0) - (b.z or 0)
    return math.sqrt(dx * dx + dy * dy + dz * dz)
end

function Game.LocalCoords()
    local ped = PlayerPedId()
    if not ped or ped == 0 then return nil end
    local c = GetEntityCoords(ped)
    return { x = c.x, y = c.y, z = c.z }
end

-- Am I an active fighter? (statebag written by T7's combat server.)
function Game.IsFighter()
    return LocalPlayer.state['fc:active'] and true or false
end

function Game.Notify(opts) lib.notify(opts) end

function Game.AddBlip(coords, opts)
    local b = AddBlipForCoord(coords.x, coords.y, coords.z)
    SetBlipSprite(b, opts.sprite)
    SetBlipColour(b, opts.color)
    SetBlipScale(b, opts.scale)
    SetBlipAsShortRange(b, true)
    BeginTextCommandSetBlipName('STRING')
    AddTextComponentSubstringPlayerName(opts.label)
    EndTextCommandSetBlipName(b)
    return b
end

function Game.RemoveBlip(h)
    if h and DoesBlipExist(h) then RemoveBlip(h) end
end

-- ox_lib sphere zone around the ring for the spectator-gallery hint.
function Game.AddRingZone(coords, radius, onEnter, onExit)
    return lib.zones.sphere({
        coords = vector3(coords.x, coords.y, coords.z),
        radius = radius,
        onEnter = onEnter,
        onExit = onExit,
        debug = false,
    })
end

function Game.RemoveZone(z)
    if z and z.remove then z:remove() end
end

-- Spawn a frozen, invincible, non-reactive NPC (the fight promoter). Returns the
-- ped handle or nil. Mirrors the palm6 NPC-bridge template (lottery/insurance).
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

-- Interaction on a ped: ox_target entity eye when present, else a marker + E
-- prompt (poll only while inside the radius). Returns an opaque handle.
function Game.AddPedInteraction(ped, coords, label, icon, onSelect)
    if hasTarget and ped then
        exports.ox_target:addLocalEntity(ped, {
            {
                name = 'palm6_fc_promoter',
                icon = icon or 'fa-solid fa-hand-fist',
                label = label,
                onSelect = onSelect,
                distance = INTERACT_RADIUS,
            },
        })
        return { kind = 'target', ped = ped }
    end

    local point = lib.points.new({
        coords = vector3(coords.x, coords.y, coords.z),
        distance = 12.0,
    })
    function point:nearby()
        if self.currentDistance < INTERACT_RADIUS then
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
    if handle.kind == 'target' and handle.ped then
        pcall(function() exports.ox_target:removeLocalEntity(handle.ped) end)
    elseif handle.kind == 'point' and handle.point and handle.point.remove then
        handle.point:remove()
    end
end

-- ox_lib context menu. options = { { title, description, icon, disabled, onSelect=fn }, ... }.
function Game.OpenMenu(id, title, options)
    lib.registerContext({ id = id, title = title, options = options })
    lib.showContext(id)
end

-- Square the local fighter up on their server-authored mark (own ped only).
function Game.SquareUp(coords, heading)
    local ped = PlayerPedId()
    if not ped or ped == 0 then return end
    SetEntityCoords(ped, coords.x, coords.y, coords.z, false, false, false, false)
    SetEntityHeading(ped, heading + 0.0)
end

-- Spawn N local, non-networked, frozen crowd peds cheering around the ring.
function Game.SpawnCrowd(center, n, galleryRadius)
    local peds = {}
    for i = 1, n do
        local ang = (i / n) * 2.0 * math.pi
        local x = center.x + math.cos(ang) * galleryRadius
        local y = center.y + math.sin(ang) * galleryRadius
        local z = center.z
        local found, gz = GetGroundZFor_3dCoord(x, y, z + 2.0, false)
        if found then z = gz end
        local model = Config.CrowdModels[math.random(#Config.CrowdModels)]
        local hash = joaat(model)
        if IsModelValid(hash) then
            RequestModel(hash)
            local deadline = GetGameTimer() + 3000
            while not HasModelLoaded(hash) and GetGameTimer() < deadline do Wait(10) end
            if HasModelLoaded(hash) then
                -- isNetwork=false, thisScriptCheck=false => local, non-networked
                local ped = CreatePed(4, hash, x, y, z, (math.deg(ang) + 180.0) % 360.0, false, false)
                SetEntityInvincible(ped, true)
                FreezeEntityPosition(ped, true)
                SetBlockingOfNonTemporaryEvents(ped, true)
                SetPedCanRagdoll(ped, false)
                TaskStartScenarioInPlace(ped, 'WORLD_HUMAN_CHEERING', 0, true)
                SetModelAsNoLongerNeeded(hash)
                peds[#peds + 1] = ped
            end
        end
    end
    return peds
end

function Game.DeleteCrowd(peds)
    for _, ped in ipairs(peds or {}) do
        if ped and DoesEntityExist(ped) then DeleteEntity(ped) end
    end
end

-- Soft-repel: if the local ped is inside `inner`, snap it back to the boundary.
-- Returns true if it repelled (caller throttles the notify).
function Game.RepelFromRing(center, inner)
    local ped = PlayerPedId()
    if not ped or ped == 0 then return false end
    local pc = GetEntityCoords(ped)
    local dx, dy = pc.x - center.x, pc.y - center.y
    local dist = math.sqrt(dx * dx + dy * dy)
    if dist < inner then
        local nx, ny = 1.0, 0.0
        if dist > 0.01 then nx, ny = dx / dist, dy / dist end
        SetEntityCoords(ped, center.x + nx * inner, center.y + ny * inner, pc.z, false, false, false, false)
        return true
    end
    return false
end

local specCam
function Game.SpectateOn(center)
    if specCam then return end
    specCam = CreateCam('DEFAULT_SCRIPTED_CAMERA', true)
    SetCamCoord(specCam, center.x + 6.0, center.y + 6.0, center.z + 4.0)
    PointCamAtCoord(specCam, center.x, center.y, center.z + 0.5)
    SetCamActive(specCam, true)
    RenderScriptCams(true, true, 500, true, true)
end

function Game.SpectateOff()
    if not specCam then return end
    RenderScriptCams(false, true, 500, true, true)
    DestroyCam(specCam, true)
    specCam = nil
end
