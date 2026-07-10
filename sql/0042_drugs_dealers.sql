-- 0042_drugs_dealers.sql — table for the gtarp_drugs NPC dealer (Phase 2 §8).
-- One dealer per character. The dealer is a passive, hard-capped dirty-cash
-- faucet: the owner stocks weed_product into stash_json, and sales resolve
-- LAZILY on interaction over wall-clock time (like the grow/dry timers in 0039/
-- 0040 — restart- and offline-safe, no client ticks). Every unit's price is
-- recomputed SERVER-SIDE from its stored base/quality/effects on each resolve.
--
-- stash_json  : JSON array of pending product lots, each {b=base_strain,
--               q=quality, e=[effects], u=units}. The resolver sells units off
--               the front and re-encodes.
-- dirty_owed  : accrued player-cut black_money awaiting collection (paid out as
--               an item only when the owner is online + can carry it).
-- day_key/day_dirty : per-character daily faucet accounting (YYYY-MM-DD, UTC),
--               enforcing Config.Dealer.dailyDirtyCap so the passive faucet can
--               never outpace real-player dealing.
CREATE TABLE IF NOT EXISTS `gtarp_drugs_dealers` (
    owner_cid          VARCHAR(64) NOT NULL PRIMARY KEY,
    hired_at           BIGINT UNSIGNED NOT NULL,
    last_tick_at       BIGINT UNSIGNED NOT NULL,
    stash_json         JSON NULL,
    dirty_owed         INT UNSIGNED NOT NULL DEFAULT 0,
    dirty_earned_total BIGINT UNSIGNED NOT NULL DEFAULT 0,
    day_key            VARCHAR(10) NOT NULL DEFAULT '',
    day_dirty          INT UNSIGNED NOT NULL DEFAULT 0,
    created_at         TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
