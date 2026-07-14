fx_version 'cerulean'
game 'gta5'
lua54 'yes'

author 'EvThatGuy'
version '0.1.0'
description 'palm6 rapsheet, read-only justice record for citizens and on-duty police'

-- Server-only on purpose: the rap sheet is a set of parameterized SELECTs over
-- tables other resources own. This resource creates NO tables and writes
-- NOTHING (SELECT / COUNT / SUM only). No client surface.
server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'shared/config.lua',
    'bridge/sv_framework.lua',  -- framework adapter, before server logic
    'server/main.lua',
}

dependencies {
    'ox_lib',    -- Bridge.Notify uses ox_lib:notify (soft, same as siblings)
    'oxmysql',
    'qbx_core',
}
