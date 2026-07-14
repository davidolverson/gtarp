-- ============================================================================
-- 0027_bounty.sql — palm6_bounty wanted board contracts.
--
-- `palm6_`-prefixed per the defensive convention. No FK constraints (house
-- style — this repo's other palm6_* tables don't use them either).
--
-- One table covers both contract kinds:
--   - 'state'   — auto-posted by the sweep against palm6_mdt's live warrant
--                 table (read-only cross-read, never written by this
--                 resource). poster_citizenid/poster_name are NULL.
--   - 'private' — posted by a citizen, escrow already taken from their bank
--                 at insert time.
-- ============================================================================

CREATE TABLE IF NOT EXISTS `palm6_bounty_contracts` (
    id INT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
    kind ENUM('state','private') NOT NULL,
    target_citizenid VARCHAR(64) NOT NULL,
    target_name VARCHAR(100) NOT NULL DEFAULT '',
    poster_citizenid VARCHAR(64) DEFAULT NULL,
    poster_name VARCHAR(100) DEFAULT NULL,
    amount INT UNSIGNED NOT NULL,
    reason VARCHAR(200) NOT NULL DEFAULT '',
    status ENUM('active','claimed','cancelled','expired') NOT NULL DEFAULT 'active',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    expires_at TIMESTAMP NULL DEFAULT NULL,
    claimed_by_citizenid VARCHAR(64) DEFAULT NULL,
    claimed_by_name VARCHAR(100) DEFAULT NULL,
    claimed_at TIMESTAMP NULL DEFAULT NULL,
    INDEX idx_palm6_bounty_target (target_citizenid, kind, status),
    INDEX idx_palm6_bounty_poster (poster_citizenid, status),
    INDEX idx_palm6_bounty_status (status)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
