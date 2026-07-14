-- 0035_protection.sql — table for palm6_protection. Apply after the qbx base schema.
-- palm6_-prefixed per the table-naming convention (see docs/GTA6-READINESS.md).

-- One row per shakedown. The per-business collection cooldown is enforced by
-- "is there a row for this business_id newer than CollectIntervalSec", so
-- (business_id, created_at) is the hot index. evidence_case_id is populated
-- only when a shakedown was reported (palm6_evidence v2).
CREATE TABLE IF NOT EXISTS `palm6_protection_collections` (
    id INT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
    gang VARCHAR(50) NOT NULL,
    business_id VARCHAR(50) NOT NULL,
    zone_id VARCHAR(50) NOT NULL,
    citizenid VARCHAR(64) NOT NULL,
    amount INT UNSIGNED NOT NULL,
    flagged TINYINT(1) NOT NULL DEFAULT 0,
    evidence_case_id INT UNSIGNED NULL DEFAULT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    INDEX idx_palm6_protection_business_time (business_id, created_at),
    INDEX idx_palm6_protection_gang (gang)
);
