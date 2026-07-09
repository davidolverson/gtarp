-- 0036_loanshark.sql — table for gtarp_loanshark. Apply after the qbx base schema.
-- gtarp_-prefixed per the table-naming convention (see docs/GTA6-READINESS.md).

-- One row per loan. status: open (owing) -> repaid (paid off) | defaulted
-- (missed the deadline; a warrant was issued and recorded in warrant_id). A
-- citizen may hold at most one 'open' loan at a time (enforced in code).
-- remaining owed = owed - repaid.
CREATE TABLE IF NOT EXISTS `gtarp_loanshark_loans` (
    id INT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
    citizenid VARCHAR(64) NOT NULL,
    principal INT UNSIGNED NOT NULL,
    owed INT UNSIGNED NOT NULL,
    repaid INT UNSIGNED NOT NULL DEFAULT 0,
    status ENUM('open', 'repaid', 'defaulted') NOT NULL DEFAULT 'open',
    warrant_id INT UNSIGNED NULL DEFAULT NULL,
    borrowed_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    due_at TIMESTAMP NOT NULL,
    closed_at TIMESTAMP NULL DEFAULT NULL,
    INDEX idx_gtarp_loanshark_citizen_status (citizenid, status),
    INDEX idx_gtarp_loanshark_due (status, due_at)
);
