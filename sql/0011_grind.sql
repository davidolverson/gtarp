-- 0011_grind.sql — per-character grind XP for gtarp_grind. Apply after the
-- qbx base schema. One row per (citizenid, activity).
CREATE TABLE IF NOT EXISTS `grind_skill` (
    `citizenid` VARCHAR(64)  NOT NULL,
    `activity`  VARCHAR(32)  NOT NULL,
    `xp`        INT UNSIGNED NOT NULL DEFAULT 0,
    PRIMARY KEY (`citizenid`, `activity`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;
