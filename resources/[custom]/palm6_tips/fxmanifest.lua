fx_version 'cerulean'
game 'gta5'
lua54 'yes'

author 'EvThatGuy'
version '0.1.0'
description 'palm6 tips — anonymous payphone tips into the 911 log'

-- Server-only on purpose: the payphone check is a server-side position
-- read and the tip lands via palm6_mdt's LogCall export. No client
-- surface, no net events.
server_scripts {
    'shared/config.lua',
    'bridge/sv_framework.lua',  -- framework adapter — before server logic
    'server/main.lua',
}

dependencies {
    'ox_lib',
    'qbx_core',
    'palm6_mdt',
}
