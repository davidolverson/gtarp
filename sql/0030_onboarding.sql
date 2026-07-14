-- 0030_onboarding.sql — tables for palm6_onboarding. Apply after the qbx base schema.
-- palm6_-prefixed per the table-naming convention (see docs/GTA6-READINESS.md
-- history — an unprefixed table silently collided with a recipe resource once).
--
-- One row per citizen, ever. UNIQUE(citizenid) is the actual guard against a
-- double-grant race on /accept — the INSERT either lands once (server then
-- credits starter cash) or throws on the duplicate key (server treats that
-- as "already onboarded", grants nothing, same idiom as every other
-- guarded-write feature this session).
CREATE TABLE IF NOT EXISTS `palm6_onboarding` (
    id INT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
    citizenid VARCHAR(64) NOT NULL,
    accepted_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    starter_cash_granted TINYINT(1) NOT NULL DEFAULT 0,
    UNIQUE KEY uniq_palm6_onboarding_citizenid (citizenid)
);
