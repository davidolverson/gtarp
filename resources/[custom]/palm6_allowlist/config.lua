-- ============================================================================
-- palm6_allowlist/config.lua
--
-- The allowlist has two independent sources:
--   1. Discord roles — queried via Discord bot API. Read role ids from
--      Config.AllowedRoles. Bot token comes from a convar — NEVER hardcode.
--   2. DB allowlist — rows in the `allowlist` table (sql/0009_allowlist.sql).
--      Used for manual additions or for players without Discord linked.
--
-- A join is approved if EITHER source matches.
--
-- Relationship to txAdmin's native whitelist (audited 2026-07-03): txAdmin
-- ships guildRoles and approvedLicense whitelist modes, but runs exactly ONE
-- mode at a time — it cannot express this resource's "role OR license"
-- either-match, and it has no palm6_staff deny-logging. This resource
-- intentionally supersedes it: keep txAdmin's whitelist mode set to
-- `disabled` (its default) or joins get double-gated.
-- ============================================================================

Config = {}

-- Convar names (set in txAdmin secret store):
--   set palm6:discord_bot_token  "..."
--   set palm6:discord_guild_id   "..."
Config.BotTokenConvar = 'palm6:discord_bot_token'
Config.GuildIdConvar  = 'palm6:discord_guild_id'

-- Discord role ids permitted to join. A join is admitted if the linked Discord
-- member holds ANY of these roles (requires the bot token + guild id convars set
-- below — the boot banner in server/main.lua reports whether they are).
Config.AllowedRoles = {
    -- Founding Tester role (guild 1522465866837393418), granted by the founding
    -- pipeline (palm6-bot /webhooks/founding-grant) — the primary admit path for
    -- the Founding Beta cohort. Add the general whitelist role id here as well
    -- once it exists for the public launch.
    ['1528644816890630166'] = 'founding',
}

-- Role lookups are cached this many seconds.
Config.RoleCacheTtlSeconds = 60

-- Per-request timeout for the Discord API call. After this, allow OR deny
-- depending on Config.FailOpen.
Config.DiscordTimeoutMs = 4000
Config.FailOpen        = false  -- safer default for a public RP server

-- Friendly messages.
Config.DenyNoLink   = 'Your Discord must be linked in FiveM to join.'
Config.DenyNoRole   = 'You are not on the allowlist. Apply via Discord first.'
Config.DenyTimeout  = 'Allowlist check timed out. Try again in a minute.'
