-- ============================================================================
-- 0012_evidence.sql — palm6_evidence log table.
--
-- Named `palm6_evidence` (not `evidence`) as a defensive convention after
-- the 0010_properties.sql collision with the recipe's own qbx_properties
-- table — confirmed no collision exists today, but the prefix costs
-- nothing and rules it out permanently.
-- ============================================================================

CREATE TABLE IF NOT EXISTS `palm6_evidence` (
    id INT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
    citizenid VARCHAR(64) NOT NULL,
    officer_name VARCHAR(100) NOT NULL,
    description TEXT NOT NULL,
    coords TEXT DEFAULT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    INDEX idx_palm6_evidence_citizenid (citizenid)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
