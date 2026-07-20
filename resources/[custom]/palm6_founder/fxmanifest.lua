fx_version 'cerulean'
game 'gta5'
lua54 'yes'

author 'MGT'
version '0.1.0'
description 'palm6 founder — reads palm6_founding_grants and renders the Founding Tester chat tag / name icon in game'

shared_scripts {
    '@ox_lib/init.lua',
    'shared/config.lua',
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'bridge/sv_framework.lua',  -- platform adapter — after oxmysql, before logic
    'server/main.lua',
}

dependencies {
    'ox_lib',
    'oxmysql',
    'qbx_core',
}
