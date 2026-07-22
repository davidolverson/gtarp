-- ============================================================================
-- palm6_brain/client/main.lua — Phase 0 ambient spawner (client-side, local peds).
--
-- One slow loop: for every scene, if the player is within SpawnDist and it isn't
-- populated yet, spawn its peds (ground-snapped, on a scenario); once the player
-- is past DespawnDist, delete them. Non-networked peds → each client populates
-- around itself, no OneSync, no sync cost. Everything is torn down on resource stop.
-- ============================================================================

local spawned = {}   -- sceneIndex -> { peds = { pedHandle, ... } }
local running = false

local function dbg(msg) if Config.Debug then print('[palm6_brain] ' .. msg) end end

local function pick(t) return t[math.random(#t)] end

local function loadModel(model)
    local hash = (type(model) == 'number') and model or joaat(model)
    if not IsModelInCdimage(hash) then return nil end
    RequestModel(hash)
    local waited = 0
    while not HasModelLoaded(hash) and waited < 5000 do Wait(50); waited = waited + 50 end
    if not HasModelLoaded(hash) then return nil end
    return hash
end

-- Snap a spawn point to the real ground height so an imprecise config z (or uneven
-- terrain) never leaves a ped floating or buried. Falls back to the given z if the
-- ground probe misses (e.g. the tile hasn't streamed — rare at SpawnDist range).
local function groundZ(x, y, z)
    local ok, gz = GetGroundZFor_3dCoord(x + 0.0, y + 0.0, z + 3.0, false)
    return ok and gz or z
end

local function pedCount()
    local n = 0
    for _, s in pairs(spawned) do n = n + #s.peds end
    return n
end

local function spawnScene(i, scene)
    if spawned[i] then return end
    local peds = {}
    for _ = 1, (scene.count or 4) do
        if pedCount() + #peds >= Config.MaxPeds then break end   -- global pool guard
        local ang  = math.random() * math.pi * 2.0
        local dist = math.random() * (scene.radius or 10.0)
        local px = scene.x + math.cos(ang) * dist
        local py = scene.y + math.sin(ang) * dist
        local pz = groundZ(px, py, scene.z)
        local hash = loadModel(pick(scene.models or Config.ModelPool))
        if hash then
            local ped = CreatePed(4, hash, px, py, pz, math.random(0, 359) + 0.0, false, true)
            if ped and ped ~= 0 then
                SetEntityAsMissionEntity(ped, true, true)   -- engine won't cull it as ambient
                SetPedCanRagdollFromPlayerImpact(ped, true)
                -- Reactive peds flee danger; non-reactive stay locked to the scenario.
                SetBlockingOfNonTemporaryEvents(ped, not Config.Reactive)
                TaskStartScenarioInPlace(ped, pick(scene.scenarios or Config.ScenarioPool), 0, true)
                peds[#peds + 1] = ped
            end
            SetModelAsNoLongerNeeded(hash)
        end
    end
    spawned[i] = { peds = peds }
    dbg(('scene %s: spawned %d'):format(scene.label or i, #peds))
end

local function despawnScene(i)
    local s = spawned[i]
    if not s then return end
    for _, ped in ipairs(s.peds) do
        if DoesEntityExist(ped) then DeletePed(ped) end
    end
    spawned[i] = nil
    dbg('scene ' .. tostring(i) .. ': despawned')
end

local function clearAll()
    for i in pairs(spawned) do despawnScene(i) end
end

CreateThread(function()
    if not Config.Enabled then return end   -- dark-ship: nothing spawns while off
    running = true
    while running do
        local ped = PlayerPedId()
        local pc = (ped ~= 0) and GetEntityCoords(ped) or nil
        if pc then
            for i, scene in ipairs(Config.Scenes) do
                local d = #(pc - vector3(scene.x + 0.0, scene.y + 0.0, scene.z + 0.0))
                if d <= Config.SpawnDist and not spawned[i] then
                    spawnScene(i, scene)
                elseif d > Config.DespawnDist and spawned[i] then
                    despawnScene(i)
                end
            end
        end
        Wait(Config.TickMs or 2000)
    end
end)

-- /brainscene [label...] — prints a paste-ready scene block for wherever you're
-- standing, so ambient spots are captured from real positions, never guessed.
-- Add the printed line to Config.Scenes and redeploy. Coord-printer only (harmless).
RegisterCommand('brainscene', function(_src, args)
    local ped = PlayerPedId()
    if ped == 0 then return end
    local c = GetEntityCoords(ped)
    local label = (args[1] and table.concat(args, ' ')) or 'New scene'
    local line = ("    { label = '%s', x = %.1f, y = %.1f, z = %.1f, count = 6, radius = 12.0 },")
        :format(label:gsub("'", ""), c.x, c.y, c.z)
    print('[palm6_brain] paste into Config.Scenes:')
    print(line)
    if lib and lib.notify then
        lib.notify({ title = 'palm6_brain', description = 'Scene coords printed to F8 console.', type = 'inform' })
    end
end, false)

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    running = false
    clearAll()
end)
