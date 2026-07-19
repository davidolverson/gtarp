fx_version 'cerulean'
game 'gta5'
lua54 'yes'

author 'EvThatGuy'
version '0.1.0'
description 'palm6 fc arena — ring zone, crowd, spectator cam, fight-mark placement, betting broadcast (presentation only, no authority)'

shared_scripts {
    '@ox_lib/init.lua',
    'shared/config.lua',        -- FightMarkOffset read on BOTH realms (server computeMarks + client)
}

client_scripts {
    'bridge/cl_game.lua',       -- native / ox_lib adapter, before client logic
    'client/main.lua',
}

server_scripts {
    'bridge/sv_framework.lua',  -- framework adapter, before server logic
    'server/main.lua',
}

dependencies {
    'ox_lib',
    'qbx_core',
    'palm6_fc_core',
}
