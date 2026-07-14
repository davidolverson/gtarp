-- ============================================================================
-- palm6_loanshark/bridge/sv_framework.lua
--
-- Framework adapter (server). The ONLY file in this resource that calls
-- qbx_core / ox_inventory / the palm6_mdt cross-export or server-side natives.
-- server/main.lua (the lending logic) calls Bridge.* only — a GTA VI port is
-- a rewrite of THIS FILE. See docs/GTA6-READINESS.md §3.
-- ============================================================================

Bridge = {}

local function getPlayer(src)
    local ok, p = pcall(function() return exports.qbx_core:GetPlayer(src) end)
    return ok and p or nil
end

function Bridge.GetCitizenId(src)
    local p = getPlayer(src)
    return p and p.PlayerData and p.PlayerData.citizenid or nil
end

-- Server id currently playing `citizenid`, or nil (offline) — to notify a
-- borrower when their loan defaults.
function Bridge.GetSourceByCitizenId(citizenid)
    for _, sid in ipairs(GetPlayers()) do
        sid = tonumber(sid)
        local p = getPlayer(sid)
        if p and p.PlayerData and p.PlayerData.citizenid == citizenid then return sid end
    end
    return nil
end

-- Presence check for the dirty-cash item. Boot self-disable.
function Bridge.ItemExists(name)
    local ok, item = pcall(function() return exports.ox_inventory:Items(name) end)
    return ok and item ~= nil
end

-- Hand over the loan principal as DIRTY cash (black_money, count == dollars).
function Bridge.GiveDirty(src, name, amount)
    local ok, added = pcall(function()
        return exports.ox_inventory:AddItem(src, name, amount)
    end)
    return ok and added and true or false
end

-- Take a clean-bank repayment. ATOMIC: qbx RemoveMoney returns false (and
-- removes nothing) when the account can't cover it, so this is the whole
-- funds check — no read-then-remove race.
function Bridge.TakeBank(src, amount, reason)
    local p = getPlayer(src)
    if not p or not p.Functions then return false end
    -- pcall-wrapped (like GiveDirty) so a framework throw can't unwind the
    -- caller and leak its in-flight repay lock.
    local ok, res = pcall(function() return p.Functions.RemoveMoney('bank', amount, reason) end)
    return ok and res == true
end

-- Refund a clean-bank repayment (used only when a repayment races the default
-- sweep and the loan is no longer 'open' by the time we go to apply it).
function Bridge.GiveBank(src, amount, reason)
    local p = getPlayer(src)
    if not p or not p.Functions then return false end
    pcall(function() p.Functions.AddMoney('bank', amount, reason) end)
    return true
end

-- Soft cross-call into palm6_mdt: issue a system warrant on a defaulter.
-- Returns the warrant id, or nil if mdt is absent / rejected it. Never throws.
function Bridge.IssueWarrant(citizenid, reason, officerLabel)
    if GetResourceState('palm6_mdt') ~= 'started' then return nil end
    local ok, id = pcall(function()
        return exports.palm6_mdt:IssueWarrant(citizenid, reason, officerLabel)
    end)
    return (ok and id) or nil
end

-- Does this citizen already have an active warrant? (Gate re-borrowing while
-- wanted.) Soft — false if mdt is absent.
function Bridge.HasActiveWarrant(citizenid)
    if GetResourceState('palm6_mdt') ~= 'started' then return false end
    local ok, has = pcall(function()
        return exports.palm6_mdt:HasActiveWarrant(citizenid)
    end)
    return ok and has == true
end

-- Caller position as {x,y,z}, or nil (server-side proximity).
function Bridge.GetCoords(src)
    local ped = GetPlayerPed(src)
    if not ped or ped == 0 then return nil end
    local c = GetEntityCoords(ped)
    return { x = c.x, y = c.y, z = c.z }
end

function Bridge.Distance(a, b)
    return #(vector3(a.x, a.y, a.z) - vector3(b.x, b.y, b.z))
end

function Bridge.Notify(src, title, msg, t)
    if src == 0 then
        print(('[palm6_loanshark] %s: %s'):format(title, msg))
        return
    end
    TriggerClientEvent('ox_lib:notify', src, {
        title = title, description = msg, type = t or 'inform',
    })
end

function Bridge.ResourceStarted(name)
    return GetResourceState(name) == 'started'
end

function Bridge.RegisterCommand(name, handler)
    RegisterCommand(name, handler, false)
end
