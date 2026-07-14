fx_version 'cerulean'
game 'gta5'
lua54 'yes'

author 'EvThatGuy'
version '0.1.0'
description 'palm6 server_base — minimal starter resource for the custom layer'

shared_scripts {
    '@ox_lib/init.lua',
    'config.lua',
}

client_scripts {
    'bridge/cl_game.lua',       -- game adapter — must load before client logic
    'client/main.lua',
}

server_scripts {
    'bridge/sv_framework.lua',  -- framework adapter — must load before server logic
    'server/main.lua',
}

dependencies {
    'ox_lib',
    'qbx_core',
}
