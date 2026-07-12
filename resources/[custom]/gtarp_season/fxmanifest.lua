fx_version 'cerulean'
game 'gta5'
lua54 'yes'

author 'Palm6'
version '0.1.0'
description 'gtarp season: read-only competitive season scoreboard over existing ledgers (self-contained, self-creating tables)'

shared_scripts {
    '@ox_lib/init.lua',
    'shared/config.lua',
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'bridge/sv_framework.lua',   -- framework adapter, before server logic
    'server/main.lua',
}

dependencies {
    'ox_lib',
    'oxmysql',
    'qbx_core',
}
