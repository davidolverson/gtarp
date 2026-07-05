fx_version 'cerulean'
game 'gta5'
lua54 'yes'

author 'EvThatGuy'
version '0.1.0'
description 'gtarp devtest — convar-gated boot self-test of cross-resource export contracts (never runs unless gtarp:devtest is 1)'

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/main.lua',
}

dependencies {
    'oxmysql',
    'gtarp_evidence',
    'gtarp_staff',
    'gtarp_courier',
    'gtarp_eventguard',
    'gtarp_perf',
}
