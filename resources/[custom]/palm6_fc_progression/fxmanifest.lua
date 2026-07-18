fx_version 'cerulean'
game 'gta5'
lua54 'yes'

author 'EvThatGuy'
version '0.1.0'
description 'palm6 fc_progression — rep/rank/unlock ledger for the fight club (claim-before-credit, anti-farm, cash-neutral)'

-- Server-only on purpose: rep is a server-authoritative ledger with no client
-- surface (palm6_fightclub / palm6_bounty precedent). Nothing here ships to
-- clients, so nothing a modified client can abuse.
server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'bridge/sv_framework.lua',  -- framework adapter — before server logic
    'server/main.lua',
}

dependencies {
    'ox_lib',
    'oxmysql',
    'qbx_core',
    'palm6_fc_core',
    'palm6_fightclub',
}
