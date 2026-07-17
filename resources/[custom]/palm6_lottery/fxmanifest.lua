fx_version 'cerulean'
game 'gta5'
lua54 'yes'

author 'EvThatGuy'
version '0.1.0'
description 'palm6 lottery - clean-money city lottery, a house-rake economy sink'

-- All money/draw logic is server-side (tickets and draws are ledger rows, the
-- draw runs server-side, nothing trusts a client value). The client layer is a
-- pure kiosk: a clerk NPC + menu that fires server events which re-run the same
-- authority as /lottery. Self-contained: creates its own tables at boot
-- (palm6_lottery_tickets, palm6_lottery_draws) and writes ONLY to those + bank.
shared_scripts {
    '@ox_lib/init.lua',
    'shared/config.lua',
}

client_scripts {
    'bridge/cl_game.lua',       -- native / ox UI adapter, before client logic
    'client/main.lua',
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'bridge/sv_framework.lua',  -- framework adapter, before server logic
    'server/main.lua',
}

dependencies {
    'ox_lib',
    'oxmysql',
    'qbx_core',
}
