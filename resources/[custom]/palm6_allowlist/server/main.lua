-- ============================================================================
-- palm6_allowlist/server/main.lua
--
-- Enforces allowlist at connect. Approves if the joining identifier appears
-- in the DB allowlist OR if their Discord member carries one of
-- Config.AllowedRoles.
--
-- Pure logic: the connect-deferral plumbing, player identifiers, and the
-- Discord HTTP lookup go through Bridge.* (bridge/sv_framework.lua), so this
-- file is platform-agnostic. Our own `allowlist` table query and the
-- palm6_staff deny-log export stay here (both portable). To port to GTA VI,
-- rewrite the bridge, not this file. See docs/GTA6-READINESS.md.
-- ============================================================================

local roleCache = {}  -- [discordId] = { roles = {set}, at = ts }

local function dbAllowed(license, discordId)
    if not license and not discordId then return false end
    local row = MySQL.single.await(
        "SELECT 1 FROM allowlist WHERE (identifier = ? OR identifier = ?) AND enabled = 1 LIMIT 1",
        { license or '', discordId and ('discord:' .. discordId) or '' }
    )
    return row ~= nil
end

-- Resolve the Discord role set for a player, honouring the cache TTL.
-- cb(set|nil) — nil on token/guild unset, HTTP error, or timeout.
local function getRoles(discordId, cb)
    local cached = roleCache[discordId]
    if cached and (os.time() - cached.at) < (Config.RoleCacheTtlSeconds or 60) then
        cb(cached.roles)
        return
    end
    Bridge.FetchDiscordRoles(discordId, {
        tokenConvar = Config.BotTokenConvar,
        guildConvar = Config.GuildIdConvar,
        timeoutMs   = Config.DiscordTimeoutMs,
    }, function(set)
        if set then roleCache[discordId] = { roles = set, at = os.time() } end
        cb(set)
    end)
end

local function hasAllowedRole(roleSet)
    if not roleSet then return false end
    for roleId in pairs(Config.AllowedRoles) do
        if roleSet[roleId] then return true end
    end
    return false
end

local function logDeny(license, discord, reason)
    pcall(function()
        exports.palm6_staff:Log('allowlist_deny', 0, nil,
            ('license=%s discord=%s reason=%s'):format(
                tostring(license), tostring(discord), reason))
    end)
end

Bridge.OnConnecting(function(src, gate)
    gate.update('Checking allowlist…')

    local license   = Bridge.GetLicense(src)
    local discordId = Bridge.GetDiscordId(src)

    -- 1) DB allowlist (synchronous)
    if dbAllowed(license, discordId) then
        gate.allow()
        return
    end

    -- 2) Discord role check
    if not discordId then
        logDeny(license, nil, 'no discord linked')
        gate.deny(Config.DenyNoLink)
        return
    end

    getRoles(discordId, function(roles)
        if roles == nil then
            -- Timeout / error.
            local allow = Config.FailOpen and true or false
            logDeny(license, discordId, allow and 'timeout fail-open' or 'timeout fail-closed')
            if allow then gate.allow() else gate.deny(Config.DenyTimeout) end
            return
        end
        if hasAllowedRole(roles) then
            gate.allow()
        else
            logDeny(license, discordId, 'no allowed role')
            gate.deny(Config.DenyNoRole)
        end
    end)
end)

-- ---------------------------------------------------------------------------
-- Shared checks — one allowlist source of truth for other resources.
-- ---------------------------------------------------------------------------

exports('HasAllowedRole', function(src)
    local discordId = Bridge.GetDiscordId(src)
    if not discordId then return false end
    local cached = roleCache[discordId]
    if cached then return hasAllowedRole(cached.roles) end
    return false
end)

exports('IsAllowlisted', function(src)
    local license = Bridge.GetLicense(src)
    local discord = Bridge.GetDiscordId(src)
    if dbAllowed(license, discord) then return true end
    local cached = discord and roleCache[discord] or nil
    return cached ~= nil and hasAllowedRole(cached.roles)
end)
