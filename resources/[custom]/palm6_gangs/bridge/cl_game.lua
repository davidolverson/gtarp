-- ============================================================================
-- palm6_gangs/bridge/cl_game.lua
--
-- Game adapter (client). The ONLY file in this resource that calls ox_lib UI
-- (menus, dialogs, notifications). client/main.lua drives the flow and calls
-- Game.* only, so the whole gang UI ports to GTA VI by rewriting THIS FILE.
-- See docs/GTA6-READINESS.md (Section 3, the bridge pattern).
--
-- There are NO world natives here on purpose: palm6_gangs has no map coords,
-- blips, peds, or targets — it is pure management UI over server-authoritative
-- state. Everything the player does is validated again on the server.
-- ============================================================================

Game = {}

-- Notify the local player. opts = { title, description, type }.
function Game.Notify(opts)
    lib.notify(opts)
end

-- Context menu. `options` = ox_lib context option list. `parentId` (optional)
-- wires a Back arrow to a previously-registered menu.
function Game.OpenMenu(id, title, options, parentId)
    lib.registerContext({ id = id, title = title, menu = parentId, options = options })
    lib.showContext(id)
end

-- Free-form input dialog. `fields` = ox_lib inputDialog field list. Returns
-- the raw results array, or nil if the player cancelled.
function Game.InputDialog(title, fields)
    return lib.inputDialog(title, fields)
end

-- Yes/no confirmation. Returns true only if the player confirmed.
function Game.Confirm(header, content)
    return lib.alertDialog({
        header = header,
        content = content,
        centered = true,
        cancel = true,
    }) == 'confirm'
end

-- Read-only report dialog (roster / vault ledger view).
function Game.ShowReport(title, content)
    lib.alertDialog({
        header = title,
        content = content,
        centered = true,
        cancel = false,
    })
end
