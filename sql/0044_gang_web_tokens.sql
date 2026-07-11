-- 0044_gang_web_tokens.sql — single-use web-manage tokens for gtarp_gangs.
-- A gang LEADER runs /gangweb in-game to mint a one-time token; the Palm6
-- website's POST /api/gang/branding claims it (unused + unexpired + matching
-- gang) to prove in-game leadership without a full user-auth system. Wall-clock
-- UNIX epoch seconds (BIGINT), like the rest of the schema. Idempotent
-- (CREATE TABLE / CREATE INDEX IF NOT EXISTS, MariaDB 11.8). Do NOT edit once
-- applied — add a new migration instead.
CREATE TABLE IF NOT EXISTS `gtarp_gang_web_tokens` (
    token       VARCHAR(64)     NOT NULL PRIMARY KEY,
    gang_id     INT UNSIGNED    NOT NULL,
    created_at  BIGINT UNSIGNED NOT NULL,
    expires_at  BIGINT UNSIGNED NOT NULL,
    used_at     BIGINT UNSIGNED NULL,
    created_at_ts TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Housekeeping / claim lookups hit gang_id and the (used_at, expires_at) pair.
CREATE INDEX IF NOT EXISTS `idx_gtarp_gang_web_tokens_gang` ON `gtarp_gang_web_tokens` (`gang_id`);
