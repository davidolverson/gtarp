fx_version 'cerulean'
game 'gta5'
lua54 'yes'

author 'EvThatGuy'
version '0.1.0'
description 'palm6 dealership — canonical Palm6 vehicle catalog + price tiers (single source of truth for tools/patch-vehicle-prices.sh)'

shared_scripts {
    '@ox_lib/init.lua',
    'shared/catalog.lua',
}

server_scripts {
    'server/main.lua',
}

dependencies {
    'ox_lib',
}
