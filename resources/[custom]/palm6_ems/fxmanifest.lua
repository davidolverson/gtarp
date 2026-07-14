fx_version 'cerulean'
game 'gta5'
lua54 'yes'

author 'EvThatGuy'
version '0.1.0'
description 'palm6 ems - recorded EMS bills, patient bill list, and an EMS 911 dispatch reader'

-- Server-only on purpose: bills are ledger rows, payment is a server-side
-- bank read, dispatch is a server-side read of the shared call log. No
-- client surface.
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
