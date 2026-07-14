fx_version 'cerulean'
game 'gta5'
lua54 'yes'

author 'EvThatGuy'
version '0.1.0'
description 'palm6 discord — server->Discord feed announcer for the signature systems'

shared_scripts {
    '@ox_lib/init.lua',
    'shared/config.lua',
}

server_scripts {
    'bridge/sv_framework.lua',  -- runtime adapter — before server logic
    'server/main.lua',
}

dependencies {
    'ox_lib',
}
