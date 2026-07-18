-- ============================================================================
-- palm6_fc_core/data.lua — roster + style data + statebag key constants.
-- DATA ONLY. Attaches to the shared Config table from config.lua. BOTH realms.
-- ============================================================================

-- Original "house" fighters (§8): {id,name,model,styleId,unlockId?} mapped to
-- existing base/MP ped models (zero custom assets). unlockId omitted = always
-- selectable. GetFighter(id) resolves these (O(1) index built in exports.lua).
Config.Fighters = {
    { id = 'house_ace',    name = 'Ace Malone',  model = 'mp_m_freemode_01',   styleId = 'brawler'   },
    { id = 'house_dozer',  name = 'Big Dozer',   model = 'a_m_m_hillbilly_01', styleId = 'wrestler'  },
    { id = 'house_switch', name = 'Switchblade', model = 'a_m_y_downtown_01',  styleId = 'kickboxer' },
    { id = 'house_reign',  name = 'Queen Reign', model = 'mp_f_freemode_01',   styleId = 'brawler'   },
    { id = 'house_kobra',  name = 'Kobra King',  model = 'g_m_y_lost_01',      styleId = 'kickboxer' },
    { id = 'house_titan',  name = 'Iron Titan',  model = 'a_m_m_og_boss_01',   styleId = 'wrestler'  },
}

-- 3 STAT-IDENTICAL styles (§8): differ ONLY in movementClipset + anim feel,
-- NEVER power (so rep is genuinely cash-neutral, §9). Keyed by styleId.
Config.Styles = {
    brawler = {
        id = 'brawler', name = 'Brawler', movementClipset = 'move_m@brave',
        animDicts = { strike = 'melee@unarmed@streamed_core', block = 'anim@mp_player_intmenu@key_fob@', hitreact = 'melee@unarmed@streamed_core', finisher = 'mini@takedowns@front' },
    },
    kickboxer = {
        id = 'kickboxer', name = 'Kickboxer', movementClipset = 'move_m@confident',
        animDicts = { strike = 'melee@unarmed@streamed_core', block = 'anim@mp_player_intmenu@key_fob@', hitreact = 'melee@unarmed@streamed_core', finisher = 'mini@takedowns@front' },
    },
    wrestler = {
        id = 'wrestler', name = 'Wrestler', movementClipset = 'move_m@tough_guy@',
        animDicts = { strike = 'melee@unarmed@streamed_core', block = 'anim@mp_player_intmenu@key_fob@', hitreact = 'melee@unarmed@streamed_core', finisher = 'mini@takedowns@front' },
    },
}

-- Statebag key constants (T1 DOCUMENTS the shape; T7 writes, T9 reads).
-- Exposed via exports.palm6_fc_core:StateKeys().
FcStateKeys = {
    MATCH_PREFIX  = 'fc:match:',
    PLAYER_ACTIVE = 'fc:active',
    PLAYER_SLOT   = 'fc:slot',
    matchKey = function(matchId) return 'fc:match:' .. matchId end,
}
