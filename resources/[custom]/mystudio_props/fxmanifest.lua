-- ============================================================
--  PROP / OBJECT resource
--  Verified structure (mid-2026). Rename 'mystudio' + 'props'.
-- ============================================================
fx_version 'cerulean'
game 'gta5'

author 'YourName'
version '1.0.0'
description 'Custom prop pack'

-- Raw assets (.ydr .ytd .ybn) in stream/ are auto-streamed. No lines needed.
-- The .ytyp archetype is the ONE thing you must register:
files {
    'stream/mystudio_props.ytyp',
}

data_file 'DLC_ITYP_REQUEST' 'stream/mystudio_props.ytyp'
