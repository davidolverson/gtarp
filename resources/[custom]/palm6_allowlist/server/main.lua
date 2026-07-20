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
    -- pcall-guarded: oxmysql .await THROWS on any query error (missing `allowlist`
    -- table, transient DB outage during a connect). An unguarded throw here inside
    -- the connect deferral leaves the deferral UNRESOLVED -> the player hangs on
    -- "Checking allowlist…" forever. On any error we treat it as "no DB match" and
    -- fall through to the Discord-role gate, so the deferral always resolves. The
    -- table is also self-created at boot by palm6_dbmigrate now (belt + braces).
    local ok, row = pcall(function()
        return MySQL.single.await(
            "SELECT 1 FROM allowlist WHERE (identifier = ? OR identifier = ?) AND enabled = 1 LIMIT 1",
            { license or '', discordId and ('discord:' .. discordId) or '' })
    end)
    if not ok then return false end
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

    -- The synchronous body is wrapped so ANY unexpected error resolves the
    -- deferral to a clean deny instead of leaving the player hung on the connect
    -- screen. The Discord path resolves the gate inside its own callback.
    local ok, err = pcall(function()
        local license   = Bridge.GetLicense(src)
        local discordId = Bridge.GetDiscordId(src)

        -- 1) DB allowlist (synchronous, pcall-guarded inside dbAllowed)
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
    if not ok then
        logDeny(nil, nil, 'handler error: ' .. tostring(err))
        pcall(function() gate.deny(Config.DenyTimeout) end)
    end
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

-- ---------------------------------------------------------------------------
-- Boot banner — surface a misconfigured gate at STARTUP (a misconfig otherwise
-- only shows up as mass player denials on a live founding night). Reports how
-- many roles are configured and whether the bot token/guild convars are set (the
-- Discord-role admit path is dead without them).
-- ---------------------------------------------------------------------------
CreateThread(function()
    local roleCount = 0
    for _ in pairs(Config.AllowedRoles) do roleCount = roleCount + 1 end
    local tokenSet = GetConvar(Config.BotTokenConvar, '') ~= ''
    local guildSet = GetConvar(Config.GuildIdConvar, '') ~= ''
    print('[palm6_allowlist] ============================================')
    print(('[palm6_allowlist] AllowedRoles: %d role(s) configured'):format(roleCount))
    print(('[palm6_allowlist] %s: %s'):format(Config.BotTokenConvar, tokenSet and 'SET' or 'UNSET'))
    print(('[palm6_allowlist] %s: %s'):format(Config.GuildIdConvar, guildSet and 'SET' or 'UNSET'))
    if roleCount > 0 and (not tokenSet or not guildSet) then
        print('[palm6_allowlist] WARNING: roles configured but a bot convar is UNSET -> the Discord-role admit path CANNOT work; role-holders will be denied. Set both convars in txAdmin.')
    elseif roleCount == 0 then
        print('[palm6_allowlist] WARNING: AllowedRoles is EMPTY -> only DB-allowlisted players can join.')
    end
    print('[palm6_allowlist] ============================================')
end)
