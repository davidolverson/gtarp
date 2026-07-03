-- ============================================================================
-- gtarp_clout/bridge/cl_game.lua
--
-- Game adapter (client). The ONLY file in this resource that calls GTA
-- natives, NUI message natives, or ox_lib UI. client/main.lua calls Game.*
-- only, so the overlay plumbing, live head-tag bookkeeping, and broker-ped
-- logic port to GTA VI by rewriting THIS FILE.
-- See docs/GTA6-READINESS.md (Section 3, the bridge pattern).
-- ============================================================================

Game = {}

-- Local player position as {x,y,z}.
function Game.GetPlayerCoords()
    local p = GetEntityCoords(PlayerPedId())
    return { x = p.x, y = p.y, z = p.z }
end

-- Distance in metres between two coord tables (accepts vector3/4 too).
function Game.DistanceBetween(a, b)
    return #(vector3(a.x, a.y, a.z) - vector3(b.x, b.y, b.z))
end

-- This client's server id (to skip drawing a LIVE tag on yourself).
function Game.GetMyServerId()
    return GetPlayerServerId(PlayerId())
end

-- Show a "press ~key~" help prompt for the current frame.
function Game.ShowHelpThisFrame(text)
    BeginTextCommandDisplayHelp('STRING')
    AddTextComponentSubstringPlayerName(text)
    EndTextCommandDisplayHelp(0, false, true, -1)
end

-- Was the interact key (E / INPUT_PICKUP) pressed this frame?
function Game.InteractPressed()
    return IsControlJustReleased(0, 38)
end

-- Push a message table to the NUI overlay. The overlay never takes input
-- focus — it is a pure HUD layer, so no focus natives are needed.
function Game.SendUIMessage(msg)
    SendNUIMessage(msg)
end

-- ---------------------------------------------------------------------------
-- LIVE head tags (MP gamer tags) over streaming players.
-- ---------------------------------------------------------------------------

-- Ped handle for another player's server id, or nil when out of scope.
function Game.GetPedForServerId(serverId)
    local player = GetPlayerFromServerId(serverId)
    if player == -1 then return nil end
    local ped = GetPlayerPed(player)
    if not ped or ped == 0 then return nil end
    return ped
end

-- Attach a LIVE tag to a ped. Returns the tag handle.
function Game.CreateLiveTag(ped, text)
    local tag = CreateFakeMpGamerTag(ped, text, false, false, '', 0)
    SetMpGamerTagVisibility(tag, 0, true)          -- component 0 = the name text
    SetMpGamerTagColour(tag, 0, 6)                 -- HUD_COLOUR_RED
    SetMpGamerTagAlpha(tag, 0, 255)
    return tag
end

-- Is a tag handle still valid (ped despawn/respawn invalidates it)?
function Game.IsTagActive(tag)
    return tag ~= nil and IsMpGamerTagActive(tag)
end

-- Remove a tag by handle.
function Game.RemoveLiveTag(tag)
    if tag and IsMpGamerTagActive(tag) then RemoveMpGamerTag(tag) end
end

-- ---------------------------------------------------------------------------
-- Pawnshop broker ped (brand-deal cashout NPC).
-- ---------------------------------------------------------------------------

-- Spawn the broker: frozen, invincible, non-reactive scenery. Returns the
-- ped handle, or nil if the model fails to stream in.
function Game.SpawnBrokerPed(model, coords4)
    local hash = joaat(model)
    if not IsModelValid(hash) then return nil end
    RequestModel(hash)
    local deadline = GetGameTimer() + 5000
    while not HasModelLoaded(hash) do
        if GetGameTimer() > deadline then return nil end
        Wait(50)
    end
    local ped = CreatePed(4, hash, coords4.x, coords4.y, coords4.z - 1.0, coords4.w or 0.0, false, true)
    SetModelAsNoLongerNeeded(hash)
    if not ped or ped == 0 then return nil end
    SetEntityInvincible(ped, true)
    FreezeEntityPosition(ped, true)
    SetBlockingOfNonTemporaryEvents(ped, true)
    return ped
end

-- Despawn the broker.
function Game.DeletePed(ped)
    if ped and DoesEntityExist(ped) then DeleteEntity(ped) end
end

-- Show a read-only text dialog (the subpoena'd VOD log).
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
