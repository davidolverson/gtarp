fx_version 'cerulean'
game 'gta5'
lua54 'yes'

author 'EvThatGuy'
version '0.1.0'
description 'palm6 ganginfo, read-only in-game public gang directory (/ganginfo, /gangs); creates no tables and writes nothing'

-- Server-only on purpose: this resource runs parameterized, read-only SELECTs
-- over tables other resources own (palm6_gangs, palm6_gang_members, palm6_turf)
-- and prints a public gang profile / leaderboard to chat. It creates NO tables
-- and writes NOTHING. There is no client surface (chat output only). This is
-- the in-game equivalent of the website /gangs page, and is distinct from
-- palm6_gangs (which owns the /gang management menu and /gangweb), so nothing
-- here duplicates that resource: it is a public directory, not a manager.
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
