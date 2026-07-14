-- ============================================================================
-- 0013_turf.sql — palm6_turf zone-ownership table.
--
-- One row per Config.Zones entry (seeded by the resource on first boot).
-- Named `palm6_turf` defensively, matching the `palm6_properties` /
-- `palm6_evidence` convention — no collision confirmed today, but the
-- prefix rules it out for good.
-- ============================================================================

CREATE TABLE IF NOT EXISTS `palm6_turf` (
    zone_id VARCHAR(50) NOT NULL PRIMARY KEY,
    owner_gang VARCHAR(50) DEFAULT NULL,
    captured_by VARCHAR(64) DEFAULT NULL,
    captured_at TIMESTAMP NULL DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
