-- 0050_courier_pickup.sql — add a persisted pickup-visited flag to courier
-- deliveries. Before this, :complete only verified DROPOFF proximity, so a
-- courier could accept a job and drive straight to the dropoff (or teleport)
-- without ever visiting the pickup. The new flag, set by a proximity-gated
-- :pickup event and required by :complete, forces the full run.
--
-- IDEMPOTENT (ADD COLUMN IF NOT EXISTS) — safe to re-run every boot, so it is
-- also embedded in palm6_dbmigrate (which has no ledger). CI never touches the
-- DB, so palm6_dbmigrate is the prod apply path.

ALTER TABLE `courier_postings`
    ADD COLUMN IF NOT EXISTS `picked_up` TINYINT NOT NULL DEFAULT 0;
