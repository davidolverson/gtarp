-- ============================================================================
-- server_identity/config.lua - identity layer config.
-- ============================================================================

Config = {}

Config.ServerName = 'Palm6'

Config.LoadingScreenTips = {
    'Welcome to Palm6 Bay, the heart of the Sunrise State.',
    'Stay in character. Use /me and /do for actions and details.',
    'New here? Read the rules pinned in the Discord before spawning in.',
    'The State of Verano runs on second chances. New day, new life.',
    'Report issues to staff in-game with /report.',
}

-- Keep in sync with server_base/config.lua: Config.DefaultSpawn.
Config.SpawnPoint = vector4(195.17, -933.77, 30.69, 144.0)

-- Replace with your Discord application id from
-- https://discord.com/developers/applications.
Config.DiscordAppId = '0000000000000000000'
Config.DiscordPresenceText = 'Roleplaying in Palm6 Bay'
Config.DiscordPresenceRefreshMs = 60000
