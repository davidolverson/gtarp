fx_version 'cerulean'
game 'gta5'
lua54 'yes'

author 'EvThatGuy'
version '0.1.0'
description 'gtarp server_identity - loading screen, spawn handler, Discord rich presence'

shared_scripts {
    '@ox_lib/init.lua',
    'config.lua',
}

client_scripts {
    'bridge/cl_game.lua',   -- game adapter - must load before client logic
    'client/main.lua',
}

loadscreen 'html/loading.html'
loadscreen_manual_shutdown 'no'
loadscreen_cursor 'no'

files {
    'html/loading.html',
    'html/palm6_screen.jpg',
}

dependencies {
    'ox_lib',
}
