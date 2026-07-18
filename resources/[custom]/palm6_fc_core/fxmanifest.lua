fx_version 'cerulean'
game 'gta5'
lua54 'yes'

author 'EvThatGuy'
version '0.1.0'
description 'palm6 fc_core — shared Def Jam fight-club data + constants (no behavior)'

-- shared_scripts (NOT server-only): the server move-clock validator AND the
-- client combat/HUD both read GetMove/GetStyle/StateKeys/Config, so this single
-- source of truth loads in BOTH realms. Data only — zero events, threads, DB.
shared_scripts {
    'config.lua',
    'data.lua',
    'exports.lua',
}
