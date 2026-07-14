fx_version 'cerulean'
game 'gta5'
lua54 'yes'

author 'Palm6'
version '0.1.0'
description 'palm6 help, a curated in-game command reference: /help lists the player-usable Palm6 custom commands by category, /help [topic] shows one category in detail'

-- Server-only on purpose: /help renders a STATIC curated menu defined entirely
-- in shared/config.lua. It creates NO tables, writes NOTHING, and reads NO
-- database (there is no oxmysql include here at all). No client surface: output
-- goes over the chat/notify bridge to the invoking player only.
server_scripts {
    'shared/config.lua',
    'bridge/sv_framework.lua',  -- framework adapter, before server logic
    'server/main.lua',
}

-- qbx_core is used only for optional debug attribution (player name / citizenid)
-- and is called through pcall in the bridge, so its absence never hard-fails.
-- The Admin-category gate uses the IsPlayerAceAllowed native (no dependency).
dependencies {
    'qbx_core',
}
