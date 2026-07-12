fx_version 'cerulean'
game 'gta5'
lua54 'yes'

author 'EvThatGuy'
version '0.1.0'
description 'gtarp blotter, read-only civic-visibility digest of citations, bookings and 911 calls for on-duty police'

-- Server-only on purpose: the blotter runs read-only SELECTs over tables
-- other resources own (gtarp_citations, gtarp_mdt), aggregates them for an
-- on-duty police /blotter command, and (optionally, off by default) posts a
-- weekly digest to gtarp_discord. It creates NO tables and writes NOTHING.
-- No client surface.
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
