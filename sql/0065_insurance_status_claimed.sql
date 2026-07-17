-- ============================================================================
-- 0065_insurance_status_claimed.sql — allow the 'claimed' policy status.
--
-- cmdFileClaim retires a policy after a claim with
--   UPDATE palm6_insurance_policies SET status = 'claimed' WHERE ... status='active'
-- (the one-payout-per-policy guard), and doInsure's comments say the same. But
-- the column was created as ENUM('active','lapsed','cancelled') (sql/0021) — it
-- never allowed 'claimed'. Under strict SQL mode (STRICT_TRANS_TABLES, the
-- MariaDB/MySQL prod default) writing an out-of-range ENUM value is a HARD ERROR,
-- so the retire UPDATE threw, was swallowed by its pcall, and the policy stayed
-- 'active' — letting a DAMAGE claim (which keeps the car) be re-filed on the same
-- policy indefinitely (a repeatable payout faucet). Adding 'claimed' at the END
-- of the enum is an INSTANT metadata change (no table rebuild) and is idempotent:
-- re-applying the same definition every boot is a harmless no-op.
-- ============================================================================

ALTER TABLE `palm6_insurance_policies`
    MODIFY COLUMN `status` ENUM('active','lapsed','cancelled','claimed') NOT NULL DEFAULT 'active';
