-- ============================================================================
-- 0021_insurance.sql — gtarp_insurance policy + claim storage.
--
-- `gtarp_`-prefixed per the defensive convention adopted after the
-- 0010_properties.sql collision. No FK constraints (house style).
--
-- Claims are the interesting rows: risk_factors carries the server-computed
-- fraud signals as JSON, and case_id links a flagged claim to the
-- gtarp_evidence case the adjuster opened. Payouts are deferred (due_at) —
-- the sweep thread pays them out, so a restart never eats a claim.
-- "One active policy per plate" is enforced in code, not by key (plates
-- accumulate many lapsed/cancelled rows over a wipe's lifetime).
-- ============================================================================

CREATE TABLE IF NOT EXISTS `gtarp_insurance_policies` (
    id INT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
    plate VARCHAR(15) NOT NULL,
    citizenid VARCHAR(64) NOT NULL,
    vehicle_model VARCHAR(50) NOT NULL,
    vehicle_value INT UNSIGNED NOT NULL,
    premium_paid INT UNSIGNED NOT NULL,
    coverage INT UNSIGNED NOT NULL,
    deductible INT UNSIGNED NOT NULL,
    status ENUM('active','lapsed','cancelled') NOT NULL DEFAULT 'active',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    expires_at TIMESTAMP NOT NULL,
    INDEX idx_gtarp_insurance_policies_plate (plate, status),
    INDEX idx_gtarp_insurance_policies_cid (citizenid),
    INDEX idx_gtarp_insurance_policies_expires (expires_at)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS `gtarp_insurance_claims` (
    id INT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
    policy_id INT UNSIGNED NOT NULL,
    plate VARCHAR(15) NOT NULL,
    citizenid VARCHAR(64) NOT NULL,
    kind ENUM('damage','total_loss','theft') NOT NULL,
    assessed INT UNSIGNED NOT NULL,
    risk_score TINYINT UNSIGNED NOT NULL DEFAULT 0,
    risk_factors TEXT DEFAULT NULL,
    status ENUM('processing','paid','flagged_paid') NOT NULL DEFAULT 'processing',
    case_id INT UNSIGNED DEFAULT NULL,
    filed_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    due_at TIMESTAMP NOT NULL,
    resolved_at TIMESTAMP NULL DEFAULT NULL,
    INDEX idx_gtarp_insurance_claims_cid (citizenid),
    INDEX idx_gtarp_insurance_claims_status_due (status, due_at)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
