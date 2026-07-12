fx_version 'cerulean'
game 'gta5'
lua54 'yes'

author 'EvThatGuy'
version '0.1.0'
description 'gtarp wanted, read-only public most-wanted board (active warrants + bounties) and a personal wanted-status self-check for any citizen'

-- Server-only on purpose: this resource runs read-only SELECTs over tables
-- other resources own (gtarp_mdt_warrants, gtarp_bounty_contracts,
-- gtarp_mdt_bolos), presents an in-character public most-wanted board
-- (/wanted) and a personal self-check (/amiwanted). It creates NO tables and
-- writes NOTHING. No client surface.
server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'shared/config.lua',
    'bridge/sv_framework.lua',  -- framework adapter, before server logic
    'server/main.lua',
}

dependencies {
    'oxmysql',
    'qbx_core',
}
