fx_version 'cerulean'
game 'gta5'
lua54 'yes'

author 'EvThatGuy'
version '0.1.0'
description 'gtarp seizure — police dirty-money forfeiture ledger (the law vs the crime economy)'

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'shared/config.lua',
    'bridge/sv_framework.lua',  -- framework adapter — before server logic
    'server/main.lua',
}

-- gtarp_mdt (warrant gate) and gtarp_evidence (case linkage) are SOFT deps —
-- read via export, tolerated absent — so they're not listed here.
dependencies {
    'ox_lib',
    'oxmysql',
    'qbx_core',
    'ox_inventory',
}
