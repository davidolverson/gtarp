fx_version 'cerulean'
game 'gta5'
lua54 'yes'

author 'EvThatGuy'
version '0.1.0'
description 'palm6 citystats, read-only in-game mirror of the website /city page: live gang, vault, drug-economy and warrant aggregates via /citystats'

-- Server-only on purpose: citystats runs read-only, parameterized SELECTs over
-- tables OTHER resources own (palm6_gangs, palm6_gang_members, palm6_drugs_sales,
-- palm6_mdt_warrants), aggregates them, and prints them to a rate-limited
-- /citystats command any citizen may run. It creates NO tables and writes
-- NOTHING (SELECT / COUNT / SUM only). No client surface.
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
