-- 0047_yard.sql — gtarp_yard (Bolingbroke prison economy)
-- Sentence-shaving labor, buy-only commissary, superlinear bail bonds.
-- Every table is `gtarp_`-prefixed per the table-naming convention.
-- Idempotent (CREATE TABLE IF NOT EXISTS) — safe to re-run.
--
-- NOTE: the jail clock itself lives in xt-prison's `xt_prison(identifier,
-- jailtime)` table (created by xt-prison). gtarp_yard only READS/writes that row
-- via the bridge; it owns the four tables below.

-- Per-character sentence baseline for the 50%-shave cap. A new/longer sentence
-- (current jailTime above baseline_minutes) resets baseline + shaved so each
-- fresh stint gets a fresh budget. Keyed to citizenid (not session/entity).
CREATE TABLE IF NOT EXISTS gtarp_yard_sentence (
    citizenid        VARCHAR(64) NOT NULL PRIMARY KEY,
    baseline_minutes INT         NOT NULL DEFAULT 0,
    shaved_minutes   INT         NOT NULL DEFAULT 0,
    updated_at       BIGINT      NOT NULL DEFAULT 0
);

-- Persisted labor cooldown + task counter. Wall-clock last_task_at lives in the
-- DB (not the session) so relog-to-reset-labor is blocked.
CREATE TABLE IF NOT EXISTS gtarp_yard_labor (
    citizenid       VARCHAR(64) NOT NULL PRIMARY KEY,
    last_task_at    BIGINT      NOT NULL DEFAULT 0,
    tasks_completed INT         NOT NULL DEFAULT 0
);

-- Daily buy cap for the commissary (one row per character/item/day). ymd is an
-- integer YYYYMMDD. The composite PK makes the cap an atomic upsert.
CREATE TABLE IF NOT EXISTS gtarp_yard_commissary_log (
    citizenid VARCHAR(64) NOT NULL,
    item      VARCHAR(64) NOT NULL,
    ymd       INT         NOT NULL,
    qty       INT         NOT NULL DEFAULT 0,
    PRIMARY KEY (citizenid, item, ymd)
);

-- Bail audit trail + the re-arrest cooldown other systems read to kill the
-- bail-then-instant-crime loop.
CREATE TABLE IF NOT EXISTS gtarp_yard_bail (
    id               INT         NOT NULL AUTO_INCREMENT PRIMARY KEY,
    citizenid        VARCHAR(64) NOT NULL,
    amount           INT         NOT NULL,
    released_minutes INT         NOT NULL,
    rearrest_until   BIGINT      NOT NULL DEFAULT 0,
    created_at       BIGINT      NOT NULL DEFAULT 0,
    INDEX idx_gtarp_yard_bail_cid (citizenid)
);
