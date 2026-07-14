fx_version 'cerulean'
game 'gta5'
lua54 'yes'

author 'EvThatGuy'
version '0.1.0'
description 'palm6 drugs — Schedule I MVP: grow weed, mix branded product (effects + quality), sell to players + an NPC buyer for dirty cash, with heat/evidence'

shared_scripts {
    '@ox_lib/init.lua',
    'shared/config.lua',
}

client_scripts {
    'bridge/cl_game.lua',   -- game adapter — must load before client logic
    'client/main.lua',
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'bridge/sv_framework.lua',  -- framework adapter — before server logic
    'server/main.lua',
}

dependencies {
    'ox_lib',
    'oxmysql',
    'qbx_core',
    'ox_inventory',
}
