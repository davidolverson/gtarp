-- ============================================================================
-- gtarp_pumpcoin/bridge/cl_game.lua
--
-- Game adapter (client). The ONLY file in this resource that calls GTA
-- natives, NUI focus/message natives, or ox_lib UI. client/main.lua calls
-- Game.* only, so the exchange loop, NUI plumbing, and billboard logic port
-- to GTA VI by rewriting THIS FILE.
-- See docs/GTA6-READINESS.md (Section 3, the bridge pattern).
-- ============================================================================

Game = {}

-- Local player position as {x,y,z}.
function Game.GetPlayerCoords()
    local p = GetEntityCoords(PlayerPedId())
    return { x = p.x, y = p.y, z = p.z }
end

-- Distance in metres between two coord tables (accepts vector3 too).
function Game.DistanceBetween(a, b)
    return #(vector3(a.x, a.y, a.z) - vector3(b.x, b.y, b.z))
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

-- Give/take keyboard+mouse focus to the NUI page.
function Game.SetUIFocus(hasFocus)
    SetNuiFocus(hasFocus, hasFocus)
end

-- Push a message table to the NUI page.
function Game.SendUIMessage(msg)
    SendNUIMessage(msg)
end

-- Permanent map blip for an exchange terminal (only if enabled in config).
function Game.CreateExchangeBlip(coords)
    local b = AddBlipForCoord(coords.x, coords.y, coords.z)
    SetBlipSprite(b, Config.ExchangeBlip.sprite)
    SetBlipColour(b, Config.ExchangeBlip.colour)
    SetBlipScale(b, Config.ExchangeBlip.scale)
    SetBlipAsShortRange(b, true)
    BeginTextCommandSetBlipName('STRING')
    AddTextComponentSubstringPlayerName(Config.ExchangeBlip.label)
    EndTextCommandSetBlipName(b)
    return b
end

-- Temporary paid billboard blip advertising a coin. Returns a handle.
function Game.CreateBillboardBlip(coords, label)
    local b = AddBlipForCoord(coords.x, coords.y, coords.z)
    SetBlipSprite(b, Config.BillboardBlipSprite)
    SetBlipColour(b, Config.BillboardBlipColour)
    SetBlipScale(b, Config.BillboardBlipScale)
    SetBlipAsShortRange(b, false)
    BeginTextCommandSetBlipName('STRING')
    AddTextComponentSubstringPlayerName(label)
    EndTextCommandSetBlipName(b)
    return b
end

-- Remove a blip by handle.
function Game.RemoveBlip(handle)
    if handle then RemoveBlip(handle) end
end

-- Notify the local player.
function Game.Notify(opts)
    lib.notify(opts)
end
