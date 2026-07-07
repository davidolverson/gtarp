-- ============================================================================
-- gtarp_allowlist/bridge/sv_framework.lua
--
-- Platform adapter (server). The ONLY file in this resource that touches
-- player identifiers, the connection-deferral plumbing, convars, or the
-- HTTP native used for the Discord member lookup.
--
-- Core logic (server/main.lua) calls Bridge.* and nothing else, so the
-- allowlist decision (DB check, role matching, cache policy, fail-open vs
-- fail-closed, deny logging against our own staff export) stays engine- and
-- platform-agnostic. To port to GTA VI, rewrite THIS FILE against the new
-- platform's connect hook, identity API, and HTTP mechanism.
--
-- See docs/GTA6-READINESS.md (Section 3, the bridge pattern; allowlist is
-- mostly Tier 1 — only the connect-deferral hook is a runtime binding).
-- ============================================================================

Bridge = {}

-- The player's license identifier, or nil.
function Bridge.GetLicense(src)
    local ids = GetPlayerIdentifiers(src) or {}
    for i = 1, #ids do
        if ids[i]:sub(1, 8) == 'license:' then return ids[i] end
    end
    return nil
end

-- The player's raw Discord id (no 'discord:' prefix), or nil.
function Bridge.GetDiscordId(src)
    local ids = GetPlayerIdentifiers(src) or {}
    for i = 1, #ids do
        if ids[i]:sub(1, 8) == 'discord:' then return ids[i]:sub(9) end
    end
    return nil
end

-- Register the connect gate. `handler(src, gate)` runs once the deferral is
-- open; `gate` normalizes the platform deferral API so the logic never sees
-- defer/update/done:
--   gate.update(msg)    -- show progress text to the connecting player
--   gate.allow()        -- admit the player
--   gate.deny(reason)   -- reject with a message
function Bridge.OnConnecting(handler)
    AddEventHandler('playerConnecting', function(_name, _setKickReason, deferrals)
        local src = source
        deferrals.defer()
        -- Wait(0) yield: required after deferrals.defer before deferrals.update.
        Wait(0)
        local gate = {
            update = function(msg) deferrals.update(msg) end,
            allow  = function() deferrals.done() end,
            deny   = function(reason) deferrals.done(reason) end,
        }
        handler(src, gate)
    end)
end

-- Fetch the Discord guild-member role set for `discordId`, calling
-- cb(set|nil): a set is { [roleId] = true }; nil means token/guild unset,
-- an HTTP error, or a timeout. `opts` = { tokenConvar, guildConvar,
-- timeoutMs }. This is the only place the Discord API endpoint, the bot
-- auth header, the convar reads, and the HTTP/timeout natives live.
function Bridge.FetchDiscordRoles(discordId, opts, cb)
    local token = GetConvar(opts.tokenConvar, '')
    local guild = GetConvar(opts.guildConvar, '')
    if token == '' or guild == '' then cb(nil); return end

    local url = ('https://discord.com/api/v10/guilds/%s/members/%s'):format(guild, discordId)
    local done = false
    PerformHttpRequest(url, function(status, body)
        if done then return end
        done = true
        if status ~= 200 or not body then cb(nil); return end
        local ok, data = pcall(json.decode, body)
        if not ok or type(data) ~= 'table' or type(data.roles) ~= 'table' then
            cb(nil); return
        end
        local set = {}
        for _, r in ipairs(data.roles) do set[r] = true end
        cb(set)
    end, 'GET', '', { ['Authorization'] = 'Bot ' .. token })

    SetTimeout(opts.timeoutMs or 4000, function()
        if not done then done = true; cb(nil) end
    end)
end
