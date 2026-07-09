-- 0038_smuggling.sql — table for gtarp_smuggling. Apply after the qbx base schema.
-- gtarp_-prefixed per the table-naming convention (see docs/GTA6-READINESS.md).

-- One row per run. status: active (in transit) -> delivered | expired. The run
-- is server-tracked STATE (no carried item) — dropoff_id/mode/payout are fixed
-- at pickup, expires_at is the deadline. evidence_case_id links the trail a
-- completed run leaves (nil if the case system was offline).
CREATE TABLE IF NOT EXISTS `gtarp_smuggling_runs` (
    id INT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
    citizenid VARCHAR(64) NOT NULL,
    dropoff_id VARCHAR(50) NOT NULL,
    mode ENUM('land', 'sea', 'air') NOT NULL,
    payout INT UNSIGNED NOT NULL,
    status ENUM('active', 'delivered', 'expired') NOT NULL DEFAULT 'active',
    evidence_case_id INT UNSIGNED NULL DEFAULT NULL,
    started_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    expires_at TIMESTAMP NOT NULL,
    closed_at TIMESTAMP NULL DEFAULT NULL,
    INDEX idx_gtarp_smuggling_citizen_status (citizenid, status),
    INDEX idx_gtarp_smuggling_active (status, expires_at)
);
