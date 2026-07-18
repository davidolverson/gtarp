fx_version 'cerulean'
game 'gta5'
lua54 'yes'

author 'EvThatGuy'
version '0.1.0'
description 'palm6 fightclub — underground bare-knuckle ring with parimutuel spectator betting'

-- Server-only on purpose: every command reads server state and replies in
-- chat/notify, and both fighters' health/position/weapon are server-derived
-- off the live synced peds (palm6_bounty precedent). There is nothing for a
-- client script to do and therefore nothing for a modified client to abuse
-- (palm6_citations/palm6_mdt/palm6_bounty precedent) — no shared_scripts
-- block, so nothing here ships to clients.
server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'shared/config.lua',
    'bridge/sv_framework.lua',  -- framework adapter — before server logic
    'server/main.lua',
    'server/debug.lua',         -- ace-gated /fcdebug harness — AFTER main (uses its exports)
}

dependencies {
    'ox_lib',
    'oxmysql',
    'qbx_core',
}
