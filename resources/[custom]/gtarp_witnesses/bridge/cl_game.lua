-- ============================================================================
-- gtarp_witnesses/bridge/cl_game.lua
--
-- Game adapter (client). The ONLY file in this resource that calls GTA
-- natives or ox_lib UI. client/main.lua calls Game.* only, so the marker /
-- canvass / press presentation logic ports to GTA VI by rewriting THIS
-- FILE. See docs/GTA6-READINESS.md (Section 3, the bridge pattern).
--
-- Nothing here is trusted by the server: markers, prompts, progress bars
-- and the aim-hold are presentation. Every gate that matters (duty, armed,
-- proximity, elapsed window, money) is re-checked server-side.
-- ============================================================================

Game = {}

local UNARMED = joaat('WEAPON_UNARMED')

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
-- Blips + markers
-- ---------------------------------------------------------------------------

-- Short-range witness blip. `cfg` = { sprite, colour, scale, label }.
function Game.CreateWitnessBlip(coords, cfg)
    local b = AddBlipForCoord(coords.x, coords.y, coords.z)
    SetBlipSprite(b, cfg.sprite or 480)
    SetBlipColour(b, cfg.colour or 47)
    SetBlipScale(b, cfg.scale or 0.75)
    SetBlipAsShortRange(b, true)
    BeginTextCommandSetBlipName('STRING')
    AddTextComponentSubstringPlayerName(cfg.label or 'Witness')
    EndTextCommandSetBlipName(b)
    return b
end

-- Remove a blip by handle.
function Game.RemoveBlip(handle)
    if handle and DoesBlipExist(handle) then RemoveBlip(handle) end
end

-- Ground marker for one frame. `rgb` = { r, g, b }.
function Game.DrawWitnessMarker(coords, rgb)
    DrawMarker(2, coords.x, coords.y, coords.z + 0.4,
        0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.35, 0.35, 0.35,
        rgb[1], rgb[2], rgb[3], 200, false, true, 2, false, nil, nil, false)
end

-- ---------------------------------------------------------------------------
-- Input / player state
-- ---------------------------------------------------------------------------

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

-- Was the alternate key (G / INPUT_DETONATE) pressed this frame?
function Game.AltPressed()
    return IsControlJustReleased(0, 47)
end

-- Is the local player free-aiming a weapon right now?
function Game.IsAiming()
    return IsPlayerFreeAiming(PlayerId())
end

-- Is the local player holding anything other than fists? (Flavor gate —
-- the server re-checks armed state with its own read.)
function Game.IsArmed()
    local weapon = GetSelectedPedWeapon(PlayerPedId())
    return weapon ~= nil and weapon ~= 0 and weapon ~= UNARMED
end

-- ---------------------------------------------------------------------------
-- Appearance signature — REAL ped natives, read on the suspect's own
-- client at crime time (server-requested, nonce-gated, clamped there).
-- Component 11 = torso/top; component 1 = mask.
-- ---------------------------------------------------------------------------
function Game.GetAppearanceSignature()
    local ped = PlayerPedId()
    return {
        topDrawable = GetPedDrawableVariation(ped, 11) or 0,
        topTexture  = GetPedTextureVariation(ped, 11) or 0,
        maskOn      = (GetPedDrawableVariation(ped, 1) or 0) > 0,
    }
end

-- ---------------------------------------------------------------------------
-- UI
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

-- Progress bar that allows combat controls (the press aim-hold needs the
-- weapon up the whole time). Movement stays locked so the server anchor
-- check always passes for legit players.
function Game.AimProgressBar(label, durationMs)
    return lib.progressBar({
        duration = durationMs,
        label = label,
        useWhileDead = false,
        canCancel = true,
        disable = { move = true, car = true, combat = false },
    }) and true or false
end

-- Abort the running progress bar (the press watcher fires this when the
-- weapon drops off aim mid-hold).
function Game.CancelProgress()
    if lib.progressActive() then lib.cancelProgress() end
end

-- Read-only statement dialog (canvass results).
function Game.ShowDialog(title, content)
    lib.alertDialog({
        header = title,
        content = content,
        centered = true,
        cancel = false,
    })
end
