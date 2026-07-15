-- 0051_turf_rep_at.sql — persist the per-zone rep-mint cooldown for turf
-- takeovers. Rep-on-takeover was gated by an IN-MEMORY per-zone timestamp, so a
-- server restart wiped it and re-enabled an instant rep mint on every zone.
-- Persisting the last-mint time on the turf row keeps the anti-farm cooldown
-- honest across restarts.
--
-- IDEMPOTENT (ADD COLUMN IF NOT EXISTS) — safe to re-run every boot, so it is
-- also embedded in palm6_dbmigrate (no ledger; CI never touches the DB).

ALTER TABLE `palm6_turf`
    ADD COLUMN IF NOT EXISTS `rep_at` BIGINT NOT NULL DEFAULT 0;
