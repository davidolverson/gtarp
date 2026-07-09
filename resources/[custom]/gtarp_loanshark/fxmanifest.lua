fx_version 'cerulean'
game 'gta5'
lua54 'yes'

author 'EvThatGuy'
version '0.1.0'
description 'gtarp loanshark — borrow dirty cash, repay clean, default into a warrant'

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'shared/config.lua',
    'bridge/sv_framework.lua',  -- framework adapter — before server logic
    'server/main.lua',
}

-- gtarp_mdt is a SOFT dependency (warrant issuance via export, tolerated
-- absent) — intentionally NOT listed so start order isn't coupled.
dependencies {
    'ox_lib',
    'oxmysql',
    'qbx_core',
    'ox_inventory',
}
