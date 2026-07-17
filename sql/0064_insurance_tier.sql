-- ============================================================================
-- 0064_insurance_tier.sql — plan tier on vehicle policies.
--
-- palm6_insurance now sells three plan tiers (Basic / Standard / Premium) from
-- the agent NPC, each with its own premium %, coverage cap, deductible, term,
-- payout speed, and theft %. A policy records WHICH tier it was bought at so a
-- claim pays out at that tier's rates. DEFAULT 'standard' backfills every
-- policy issued before tiers existed to the Standard tier — which reproduces
-- the old flat plan exactly — so no in-flight policy changes behaviour.
-- Idempotent ADD COLUMN IF NOT EXISTS; safe to re-run every boot.
-- ============================================================================

ALTER TABLE `palm6_insurance_policies`
    ADD COLUMN IF NOT EXISTS `tier` VARCHAR(16) NOT NULL DEFAULT 'standard';
