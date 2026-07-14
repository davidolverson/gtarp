fx_version 'cerulean'
game 'gta5'
lua54 'yes'

author 'EvThatGuy'
version '0.1.0'
description 'palm6 devtest — convar-gated boot self-test of cross-resource export contracts (never runs unless palm6:devtest is 1)'

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/main.lua',
}

dependencies {
    'oxmysql',
    'palm6_evidence',
    'palm6_staff',
    'palm6_courier',
    'palm6_eventguard',
    'palm6_perf',
}
