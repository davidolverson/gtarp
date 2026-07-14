-- ============================================================================
-- 0029_ransom.sql — palm6_ransom kidnapping ransom ledger.
--
-- `palm6_`-prefixed per the defensive convention (a bare `ransom` table
-- risks the same silent collision class documented for `palm6_housing`'s
-- original `properties` table). No FK constraints (house style).
-- ============================================================================

CREATE TABLE IF NOT EXISTS `palm6_ransom_cases` (
    id INT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
    kidnapper_citizenid VARCHAR(64) NOT NULL,
    kidnapper_name VARCHAR(100) NOT NULL DEFAULT '',
    victim_citizenid VARCHAR(64) NOT NULL,
    victim_name VARCHAR(100) NOT NULL DEFAULT '',
    amount INT UNSIGNED NOT NULL,
    instructions VARCHAR(140) NOT NULL DEFAULT '',
    status ENUM('active','paid','expired') NOT NULL DEFAULT 'active',
    evidence_case_id INT UNSIGNED DEFAULT NULL,
    paid_by_citizenid VARCHAR(64) DEFAULT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    expires_at TIMESTAMP NULL DEFAULT NULL,
    resolved_at TIMESTAMP NULL DEFAULT NULL,
    INDEX idx_palm6_ransom_cases_status (status),
    INDEX idx_palm6_ransom_cases_victim (victim_citizenid),
    INDEX idx_palm6_ransom_cases_kidnapper (kidnapper_citizenid)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
