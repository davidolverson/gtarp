fx_version 'cerulean'
game 'gta5'
lua54 'yes'

author 'EvThatGuy'
version '0.1.0'
description 'palm6 bounty — the wanted board (state + player-posted contracts)'

-- Server-only on purpose: every command reads server state and replies in
-- chat/notify. There is nothing for a client script to do and therefore
-- nothing for a modified client to abuse (palm6_citations/palm6_mdt
-- precedent) — no shared_scripts block, so nothing here ships to clients.
server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'shared/config.lua',
    'bridge/sv_framework.lua',  -- framework adapter — before server logic
    'server/main.lua',
}

dependencies {
    'ox_lib',
    'oxmysql',
    'qbx_core',
}
