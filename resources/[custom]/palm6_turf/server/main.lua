-- ============================================================================
-- palm6_turf/server/main.lua
--
-- Gang turf control — the Phase 6 roadmap "faction reputation tracker"
-- candidate. Two phases like palm6_robbery: `requestTag` validates (in a
-- gang, proximity, not already yours) and reserves; `complete` flips
-- ownership after the client-side tag animation. Reputation = turf count,
-- shown via /turf. Pure logic — all framework/native access via Bridge.*
-- (§6 gate). Our own `palm6_turf` SQL stays here (Section 3 of
-- docs/GTA6-READINESS.md).
-- ============================================================================

local zones   = {}  -- [id] = { label, coords, owner_gang, captured_by, captured_at }
local pending = {}  -- [src] = { zoneId, gangName, holdUntil }
local zoneRepAt = {}  -- [zoneId] = os.time() of last rep-minting takeover (anti-farm)

local function ensureZones()
    for _, z in ipairs(Config.Zones) do
        pcall(function()
            MySQL.insert.await(
                'INSERT IGNORE INTO palm6_turf (zone_id) VALUES (?)', { z.id })
        end)
    end
end

local function loadZones()
    zones = {}
    local ok, rows = pcall(function()
        return MySQL.query.await('SELECT * FROM palm6_turf') or {}
    end)
    local byId = {}
    if ok then
        for _, r in ipairs(rows) do byId[r.zone_id] = r end
    end
    for _, z in ipairs(Config.Zones) do
        local row = byId[z.id] or {}
        zones[z.id] = {
            id = z.id, label = z.label, coords = z.coords,
            owner_gang = row.owner_gang, captured_by = row.captured_by,
        }
    end
end

local function publicZones()
    local out = {}
    for id, z in pairs(zones) do
        out[id] = { id = z.id, label = z.label, coords = z.coords, owner_gang = z.owner_gang }
    end
    return out
end

local function syncAll()
    local data = publicZones()
    for _, src in ipairs(GetPlayers()) do
        TriggerClientEvent('palm6_turf:syncZones', tonumber(src), data)
    end
end

AddEventHandler('onResourceStart', function(resource)
    if resource ~= GetCurrentResourceName() then return end
    ensureZones()
    loadZones()
    print(('[palm6_turf] loaded %d turf zone(s)'):format(#Config.Zones))
end)

RegisterNetEvent('palm6_turf:requestSync', function()
    TriggerClientEvent('palm6_turf:syncZones', source, publicZones())
end)

RegisterNetEvent('palm6_turf:requestTag', function(zoneId)
    local src = source
    if not Bridge.GetCitizenId(src) then return end
    local z = zones[zoneId]
    if not z then return end

    local gang = Bridge.GetGang(src)
    if not gang then
        Bridge.Notify(src, 'Turf', 'You need to be in a gang to tag turf.', 'error')
        return
    end
    if z.owner_gang == gang.name then
        Bridge.Notify(src, 'Turf', 'Your gang already holds this turf.', 'error')
        return
    end

    local coords = Bridge.GetCoords(src)
    if not coords or Bridge.Distance(coords, z.coords) > (Config.InteractRadius + 3.0) then
        Bridge.Notify(src, 'Turf', 'You are too far from this turf.', 'error')
        return
    end

    pending[src] = { zoneId = zoneId, gangName = gang.name, startedAt = os.time(), holdUntil = os.time() + 30 }
    TriggerClientEvent('palm6_turf:begin', src, { zoneId = zoneId, label = z.label })
end)

RegisterNetEvent('palm6_turf:complete', function(zoneId)
    local src = source
    local pend = pending[src]
    if not pend or pend.zoneId ~= zoneId then return end
    pending[src] = nil
    local now = os.time()
    if now > pend.holdUntil then return end
    if now - pend.startedAt < math.floor(Config.TagProgressMs / 1000) then return end  -- skipped the tag animation

    local z = zones[zoneId]
    if not z then return end
    local gang = Bridge.GetGang(src)
    if not gang or gang.name ~= pend.gangName then return end

    local coords = Bridge.GetCoords(src)
    if not coords or Bridge.Distance(coords, z.coords) > (Config.InteractRadius + 3.0) then
        Bridge.Notify(src, 'Turf', 'You left the turf.', 'error')
        return
    end

    local cid = Bridge.GetCitizenId(src)
    local prevOwner = z.owner_gang   -- capture before the flip for takeover check
    z.owner_gang = gang.name
    z.captured_by = cid
    pcall(function()
        MySQL.update.await(
            'UPDATE palm6_turf SET owner_gang = ?, captured_by = ?, captured_at = NOW() WHERE zone_id = ?',
            { gang.name, cid, zoneId })
    end)

    -- Reputation for a genuine takeover: the zone was held by a DIFFERENT
    -- player-run gang, and this zone hasn't minted rep within RepCooldownSec
    -- (anti-farm — stops two gangs ping-ponging one zone). Claiming unowned
    -- turf grants nothing. Rep is a meta stat (no cash); AddRep is soft/pcall.
    if Config.RepPerCapture and Config.RepPerCapture > 0 and gang.id
        and prevOwner and prevOwner ~= 'none' and prevOwner ~= gang.name then
        local lastAt = zoneRepAt[zoneId] or 0
        if now - lastAt >= (Config.RepCooldownSec or 600) then
            zoneRepAt[zoneId] = now
            pcall(function()
                exports.palm6_gangs:AddRep(gang.id, Config.RepPerCapture, 'turf_takeover')
            end)
        end
    end

    Bridge.Notify(src, 'Turf', ('%s tagged for %s.'):format(z.label, gang.name), 'success')
    syncAll()
end)

RegisterNetEvent('palm6_turf:cancel', function(zoneId)
    local src = source
    local pend = pending[src]
    if pend and pend.zoneId == zoneId then pending[src] = nil end
end)

RegisterCommand('turf', function(src)
    local counts = {}
    for _, z in pairs(zones) do
        if z.owner_gang then
            counts[z.owner_gang] = (counts[z.owner_gang] or 0) + 1
        end
    end

    local board = {}
    for gang, count in pairs(counts) do board[#board + 1] = { gang = gang, count = count } end
    table.sort(board, function(a, b) return a.count > b.count end)

    local lines = {}
    for i, entry in ipairs(board) do
        lines[#lines + 1] = ('%d. **%s** — %d turf'):format(i, entry.gang, entry.count)
    end
    for _, z in pairs(zones) do
        if not z.owner_gang then
            lines[#lines + 1] = ('_%s — unclaimed_'):format(z.label)
        end
    end

    if #lines == 0 then lines[1] = 'No turf claimed yet.' end
    TriggerClientEvent('palm6_turf:showLog', src, table.concat(lines, '\n'))
end, false)

AddEventHandler('playerDropped', function()
    pending[source] = nil
end)
