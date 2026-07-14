-- ============================================================================
-- 0025_calls.sql — palm6_mdt v0.3.0 dispatch call history.
--
-- `palm6_`-prefixed per the defensive convention. No FK constraints
-- (house style).
--
-- One row per police:server:policeAlert that flows through the recipe's
-- central alert funnel. The recipe notifies on-duty officers and forgets;
-- this table is the 911 log the MDT reads back (/calls). Rows older than
-- the retention window are pruned by the resource, not by the DB.
-- ============================================================================

CREATE TABLE IF NOT EXISTS `palm6_mdt_calls` (
    id INT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
    text VARCHAR(160) NOT NULL,
    x DOUBLE DEFAULT NULL,
    y DOUBLE DEFAULT NULL,
    z DOUBLE DEFAULT NULL,
    src_label VARCHAR(64) NOT NULL DEFAULT '',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    INDEX idx_palm6_mdt_calls_created (created_at)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
