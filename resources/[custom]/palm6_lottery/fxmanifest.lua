fx_version 'cerulean'
game 'gta5'
lua54 'yes'

author 'EvThatGuy'
version '0.1.0'
description 'palm6 lottery - clean-money city lottery, a house-rake economy sink'

-- Server-only on purpose: tickets and draws are ledger rows, all money is a
-- server-side bank read/write, the draw runs server-side. No client surface,
-- no client-trusted values. Self-contained: creates its own tables at boot
-- (palm6_lottery_tickets, palm6_lottery_draws) and writes ONLY to those plus
-- player bank via the framework bridge.
server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'shared/config.lua',
    'bridge/sv_framework.lua',  -- framework adapter, before server logic
    'server/main.lua',
}

dependencies {
    'ox_lib',
    'oxmysql',
    'qbx_core',
}
