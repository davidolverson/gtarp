-- ============================================================================
-- 0016_clout.sql — tables for palm6_clout (the IRL-streamer mechanic).
--
-- All tables carry the `palm6_` prefix per the defensive convention adopted
-- after the 0010_properties.sql collision — the prefix costs nothing and
-- rules out recipe-table collisions permanently.
--
--  * palm6_clout_streamers — per-character career stats (the leaderboard).
--  * palm6_clout_deals     — one-time brand-deal unlocks. Payout is
--                            snapshotted at UNLOCK so config retunes never
--                            reprice money already earned; the UNIQUE key is
--                            the once-per-character-per-milestone authority.
--  * palm6_clout_vod       — the evidence liability: crime events witnessed
--                            while live (who/what/where/when). Police
--                            subpoenas read this; housekeeping prunes it.
-- ============================================================================

CREATE TABLE IF NOT EXISTS `palm6_clout_streamers` (
    citizenid VARCHAR(64) NOT NULL PRIMARY KEY,
    streamer_name VARCHAR(100) DEFAULT NULL,
    total_streams INT UNSIGNED NOT NULL DEFAULT 0,
    total_seconds INT UNSIGNED NOT NULL DEFAULT 0,
    peak_viewers INT UNSIGNED NOT NULL DEFAULT 0,
    total_donations INT UNSIGNED NOT NULL DEFAULT 0,
    last_live_at TIMESTAMP NULL DEFAULT NULL,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS `palm6_clout_deals` (
    id INT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
    citizenid VARCHAR(64) NOT NULL,
    milestone INT UNSIGNED NOT NULL,
    payout INT UNSIGNED NOT NULL DEFAULT 0,
    unlocked_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    claimed_at TIMESTAMP NULL DEFAULT NULL,
    UNIQUE KEY uq_clout_deal (citizenid, milestone)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS `palm6_clout_vod` (
    id INT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
    streamer_citizenid VARCHAR(64) NOT NULL,
    streamer_name VARCHAR(100) DEFAULT NULL,
    event_type VARCHAR(32) NOT NULL,
    suspect_citizenid VARCHAR(64) DEFAULT NULL,
    suspect_name VARCHAR(100) DEFAULT NULL,
    detail VARCHAR(255) DEFAULT NULL,
    coords TEXT DEFAULT NULL,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    INDEX idx_clout_vod_streamer (streamer_citizenid, created_at)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
