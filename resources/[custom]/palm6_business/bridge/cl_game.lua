-- ============================================================================
-- palm6_business/bridge/cl_game.lua
--
-- Game adapter (client). The ONLY file that calls ox_lib UI. client/main.lua
-- drives the flow and calls Game.* only, so the whole UI ports to GTA VI by
-- rewriting THIS FILE (the bridge pattern, same as palm6_gangs).
--
-- MVP is abstract (no world coords/blips/peds) — pure management UI over
-- server-authoritative state, plus one skill-check "serve" moment. Everything
-- the player does is re-validated on the server.
-- ============================================================================

Game = {}

function Game.Notify(opts)
    lib.notify(opts)
end

-- Context menu. `options` = ox_lib option list. `parentId` (optional) wires a
-- Back arrow to a previously-registered menu.
function Game.OpenMenu(id, title, options, parentId)
    lib.registerContext({ id = id, title = title, menu = parentId, options = options })
    lib.showContext(id)
end

-- Free-form input dialog. Returns the raw results array, or nil if cancelled.
function Game.InputDialog(title, fields)
    return lib.inputDialog(title, fields)
end

-- Yes/no confirmation. Returns true only if the player confirmed.
function Game.Confirm(header, content)
    return lib.alertDialog({
        header = header, content = content, centered = true, cancel = true,
    }) == 'confirm'
end

-- Read-only report dialog (roster / ledger view).
function Game.ShowReport(title, content)
    lib.alertDialog({ header = title, content = content, centered = true, cancel = false })
end

-- The "serve a walk-in customer" active-work moment. A quick skill-check gates
-- the NPC-income serve so it is active play, never AFK minting. Returns true on
-- success. The server re-validates clock-in/supply/cooldown/daily-cap regardless.
function Game.ServeAction()
    local ok = lib.skillCheck({ 'easy', 'easy', 'medium' }, { 'w', 'a', 's', 'd' })
    return ok == true
end
