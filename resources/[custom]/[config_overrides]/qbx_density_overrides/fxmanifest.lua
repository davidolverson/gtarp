fx_version 'cerulean'
game 'gta5'
lua54 'yes'

author 'EvThatGuy'
version '0.1.0'
description 'gtarp config override layer for qbx_density (world population / NPC + traffic density)'

-- config.lua is shared so the documented levers are readable everywhere;
-- the values are only consumed client-side (see note below).
shared_scripts {
    '@ox_lib/init.lua',
    'config.lua',
}

-- qbx_density tuning is CLIENT-side only: its single runtime lever is the
-- client export exports.qbx_density:SetDensity(type, value). There are no
-- convars and no server API, so unlike the other config_overrides this
-- resource applies its values from a client script rather than server convars.
client_scripts {
    'client/overrides.lua',
}

dependencies {
    'ox_lib',
    'qbx_core',
    'qbx_density',
}
