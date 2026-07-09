fx_version 'cerulean'
game 'gta5'
lua54 'yes'

author 'EvThatGuy'
version '0.1.0'
description 'gtarp protection — turf-gated business extortion (makes holding turf pay)'

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'shared/config.lua',
    'bridge/sv_framework.lua',  -- framework adapter — before server logic
    'server/main.lua',
}

-- gtarp_turf is a SOFT dependency (read via SQL cross-read, tolerated absent) —
-- intentionally NOT listed here so start order isn't coupled.
dependencies {
    'ox_lib',
    'oxmysql',
    'qbx_core',
    'ox_inventory',
}
