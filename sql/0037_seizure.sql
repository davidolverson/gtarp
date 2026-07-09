-- 0037_seizure.sql — table for gtarp_seizure. Apply after the qbx base schema.
-- gtarp_-prefixed per the table-naming convention (see docs/GTA6-READINESS.md).

-- One row per forfeiture — the persistent record qbx_police's ephemeral
-- moneybag grab never writes. amount is the black_money (dirty dollars) taken
-- out of circulation; evidence_case_id links the gtarp_evidence case it was
-- attached to (nil if the case system was offline at seize time).
CREATE TABLE IF NOT EXISTS `gtarp_seizure_forfeitures` (
    id INT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
    officer_citizenid VARCHAR(64) NOT NULL,
    suspect_citizenid VARCHAR(64) NOT NULL,
    amount INT UNSIGNED NOT NULL,
    evidence_case_id INT UNSIGNED NULL DEFAULT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    INDEX idx_gtarp_seizure_suspect (suspect_citizenid),
    INDEX idx_gtarp_seizure_officer (officer_citizenid)
);
