-- ============================================================================
-- palm6_founder/server/main.lua
--
-- Reads the palm6_founding_grants ledger (written by the website when a verified
-- /beta reservation links its Discord identity) and renders the Founding Tester
-- tag in game. Two consumers:
--
--   1. exports.palm6_founder:GetTag(src)  -> label, icon   (nil if not a founder)
--      exports.palm6_founder:IsFounder(src) -> boolean
--      The authoritative, non-blocking way for ANY resource (chat, scoreboard,
--      nameplate) to ask "is this player a founder, and how should I mark them?"
--
--   2. An optional built-in chat badge (Config.ChatBadgeEnabled) for servers on
--      the STOCK `chat` resource. OFF by default — see shared/config.lua + README.
--
-- Fail-open by design: a DB hiccup or a missing ledger just means no tag. Nothing
-- here can block a connect, a chat line, or gameplay.
-- ============================================================================

-- [src] = { label=, icon= } (founder) | false (known non-founder) | nil (unknown)
local cache = {}

-- Resolve a discord id to its active grant, cb({label, icon} | nil). Fail-open.
local function queryGrant(discordId, cb)
    if not discordId then cb(nil); return end
    local ok = pcall(function()
        MySQL.single(
            'SELECT tag_label, tag_icon FROM palm6_founding_grants WHERE discord_id = ? AND revoked_at IS NULL LIMIT 1',
            { discordId },
            function(row)
                if row then
                    cb({
                        label = row.tag_label or Config.DefaultLabel,
                        icon = row.tag_icon or Config.DefaultIcon,
                    })
                else
                    cb(nil)
                end
            end
        )
    end)
    if not ok then cb(nil) end
end

-- Populate the cache for a connected player. `false` records a confirmed
-- non-founder so we do not re-query on every chat line.
local function loadForSrc(src, cb)
    local discordId = Bridge.GetDiscordId(src)
    queryGrant(discordId, function(tag)
        cache[src] = tag or false
        if cb then cb(tag) end
    end)
end

AddEventHandler('playerJoining', function()
    loadForSrc(source)
end)

AddEventHandler('playerDropped', function()
    cache[source] = nil
end)

-- Backfill already-connected players on a hot (re)start so founder tags are not
-- blank until each founder reconnects.
AddEventHandler('onResourceStart', function(res)
    if res ~= GetCurrentResourceName() then return end
    for _, pid in ipairs(GetPlayers()) do
        loadForSrc(tonumber(pid))
    end
end)

--- The authoritative founder tag for a player. Non-blocking: returns the cached
--- grant (populated on join); on a cache miss it kicks an async load and returns
--- nil for THIS call (the next call sees the populated value).
--- @return string|nil label, string|nil icon
local function getTag(src)
    src = tonumber(src)
    if not src then return nil end
    local hit = cache[src]
    if hit == nil then
        loadForSrc(src) -- warm for next time
        return nil
    end
    if hit == false then return nil end
    return hit.label, hit.icon
end

exports('GetTag', getTag)
exports('IsFounder', function(src)
    local label = getTag(src)
    return label ~= nil
end)

-- Optional built-in badge for servers on the STOCK `chat` resource. Cancels the
-- default broadcast and re-emits the founder's line with a [FOUNDER] prefix. OFF
-- unless palm6:founder_chat_badge=true. DO NOT enable on a proximity/custom chat
-- (it broadcasts to everyone) — have that chat call the exports instead.
if Config.ChatBadgeEnabled then
    AddEventHandler('chatMessage', function(src, name, message)
        local hit = cache[src]
        if not hit or hit == false then return end
        CancelEvent()
        TriggerClientEvent('chat:addMessage', -1, {
            color = Config.BadgeColor,
            multiline = true,
            args = { ('[%s] %s'):format(hit.label, name), message },
        })
    end)
    print('[palm6_founder] built-in chat badge ENABLED (stock-chat mode)')
else
    print('[palm6_founder] ready — exports live; built-in chat badge off (palm6:founder_chat_badge=false)')
end
