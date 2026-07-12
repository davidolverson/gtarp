-- ============================================================
--  PROP / OBJECT resource: mystudio_props
--  Textured shipping crate (model: mystudio_crate, hash 0x3c43573b).
--  Embedded 512x512 wood diffuse -- replaces the old black/untextured crate.
-- ============================================================
fx_version 'cerulean'
game 'gta5'

author 'MyStudio'
version '1.1.0'
description 'MyStudio prop pack - textured crate'

-- Raw assets (.ydr .ytd .ybn) in stream/ are auto-streamed. No lines needed.
-- The .ytyp archetype is the ONE thing you must register:
files {
    'stream/mystudio_props.ytyp',
}

data_file 'DLC_ITYP_REQUEST' 'stream/mystudio_props.ytyp'
