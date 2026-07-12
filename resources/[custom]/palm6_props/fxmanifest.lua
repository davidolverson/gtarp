-- ============================================================
--  PROP / OBJECT resource: palm6_props
--  Palm6 venue prop set - branded entrance sign, shipping crate, event barrier.
--  Models: palm6_sign, palm6_crate, palm6_barrier
--  Each .ydr carries an embedded DXT diffuse (branded Palm6 wordmark) + a
--  typed BOUND_BOX collision. Spawn by model name in-game.
-- ============================================================
fx_version 'cerulean'
game 'gta5'

author 'Palm6'
version '1.0.0'
description 'Palm6 venue prop set - branded sign, shipping crate, event barrier'

-- Raw assets (.ydr) in stream/ are auto-streamed. The .ytyp archetypes are the
-- one thing that must be registered (files{} + a DLC_ITYP_REQUEST line each):
files {
    'stream/palm6_sign.ytyp',
    'stream/palm6_crate.ytyp',
    'stream/palm6_barrier.ytyp',
}

data_file 'DLC_ITYP_REQUEST' 'stream/palm6_sign.ytyp'
data_file 'DLC_ITYP_REQUEST' 'stream/palm6_crate.ytyp'
data_file 'DLC_ITYP_REQUEST' 'stream/palm6_barrier.ytyp'
