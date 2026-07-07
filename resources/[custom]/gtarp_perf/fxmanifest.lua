fx_version 'cerulean'
game 'gta5'
lua54 'yes'

author 'EvThatGuy'
version '0.1.0'
description 'gtarp performance monitor — server thread-hitch sampler + webhook'

shared_scripts {
    '@ox_lib/init.lua',
    'config.lua',
}

server_scripts {
    'bridge/sv_game.lua',   -- game/runtime adapter — must load before logic
    'server/main.lua',
}

dependencies {
    'ox_lib',
    'gtarp_staff',
}
