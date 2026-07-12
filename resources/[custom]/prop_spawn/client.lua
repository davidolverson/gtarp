-- prop_spawn — dev test commands for custom props
-- Usage in-game:
--   /prop <modelname>   spawn any prop model 2m in front of you
--   /crate              shortcut for the CP1-CP7 walkthrough crate
--   /clearprops         delete every prop you've spawned this session

local spawned = {}

local function spawnProp(model)
    local hash = GetHashKey(model)
    RequestModel(hash)
    local tries = 0
    while not HasModelLoaded(hash) and tries < 200 do
        Wait(10)
        tries = tries + 1
    end
    if not HasModelLoaded(hash) then
        print(('[prop_spawn] model "%s" never loaded — check the name matches the .ydr/archetype, and that the resource is started'):format(model))
        return
    end
    local ped = PlayerPedId()
    local p = GetEntityCoords(ped)
    local fwd = GetEntityForwardVector(ped)
    local obj = CreateObject(hash, p.x + fwd.x * 2.0, p.y + fwd.y * 2.0, p.z, true, true, false)
    PlaceObjectOnGroundProperly(obj)
    SetModelAsNoLongerNeeded(hash)
    spawned[#spawned + 1] = obj
    print(('[prop_spawn] spawned "%s" (entity %d)'):format(model, obj))
end

RegisterCommand('prop', function(_, args)
    local model = args[1]
    if not model then
        print('[prop_spawn] usage: /prop <modelname>')
        return
    end
    spawnProp(model)
end, false)

RegisterCommand('crate', function()
    spawnProp('mystudio_crate')   -- matches the walkthrough prop
end, false)

RegisterCommand('clearprops', function()
    local n = 0
    for _, obj in ipairs(spawned) do
        if DoesEntityExist(obj) then
            DeleteEntity(obj)
            n = n + 1
        end
    end
    spawned = {}
    print(('[prop_spawn] cleared %d prop(s)'):format(n))
end, false)
