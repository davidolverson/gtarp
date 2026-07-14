-- 0045_onboarding_starter_grants.sql — starter-kit grant flags for palm6_onboarding.
--
-- Additive to 0030_onboarding. Two per-citizen flags mirroring
-- starter_cash_granted, so the onboarding row records exactly which one-time
-- grants a character has received. The UNIQUE(citizenid) guard in 0030 is still
-- the real double-grant defense; these columns are audit/idempotence markers the
-- server flips after a successful grant (same pattern as starter_cash_granted).
--
-- MariaDB 11.8: ADD COLUMN IF NOT EXISTS is supported, so re-applying is a no-op.
ALTER TABLE `palm6_onboarding`
    ADD COLUMN IF NOT EXISTS starter_vehicle_granted TINYINT(1) NOT NULL DEFAULT 0,
    ADD COLUMN IF NOT EXISTS starter_outfit_granted  TINYINT(1) NOT NULL DEFAULT 0;
