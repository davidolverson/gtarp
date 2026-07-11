-- ============================================================================
-- 0043_gang_web.sql - gang web-profile fields for the Palm6 RP site
--
-- Additive, nullable columns on gtarp_gangs so gangs can have a public page
-- (logo, blurb, brand colour) + leaderboards. Set from the website gang admin
-- page (images can't be uploaded in-game). Idempotent: guarded per-column so
-- re-running is safe even though MariaDB lacks ADD COLUMN IF NOT EXISTS on
-- older versions — apply-migrations.sh only runs this once via its ledger, and
-- the ADD COLUMN IF NOT EXISTS syntax below is supported on the prod
-- MariaDB 11.8 target.
-- ============================================================================

ALTER TABLE `gtarp_gangs`
    ADD COLUMN IF NOT EXISTS `logo_url`    VARCHAR(512) NULL AFTER `rep`,
    ADD COLUMN IF NOT EXISTS `description` VARCHAR(500) NULL AFTER `logo_url`,
    ADD COLUMN IF NOT EXISTS `color`       VARCHAR(9)   NULL AFTER `description`,
    ADD COLUMN IF NOT EXISTS `updated_at`  TIMESTAMP    NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP AFTER `created_at`;

-- Leaderboard read path hits (rep DESC, vault_balance DESC) frequently.
CREATE INDEX IF NOT EXISTS `idx_gtarp_gangs_rep`   ON `gtarp_gangs` (`rep`);
CREATE INDEX IF NOT EXISTS `idx_gtarp_gangs_vault` ON `gtarp_gangs` (`vault_balance`);
