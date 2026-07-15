-- ===========================================================================
-- palm6_dbmigrate — ONE-SHOT idempotent migration applier
-- ---------------------------------------------------------------------------
-- The prod DB (db-dtx-06) is not reachable from outside the panel network and
-- CI never touches the DB, so migrations 0040 + 0042-0047 are applied here
-- using the game server's own oxmysql connection on boot. Every statement is
-- IF NOT EXISTS, so re-running is a harmless no-op. Each runs independently
-- (pcall-guarded) so one failure never blocks the rest. REMOVE this resource
-- after the console shows all statements OK and the tables are confirmed.
-- ===========================================================================

local STATEMENTS = {
    { name = '0040 palm6_drugs_processes', sql = [[
CREATE TABLE IF NOT EXISTS `palm6_drugs_processes` (
    id INT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
    owner_cid VARCHAR(64) NOT NULL,
    station_id INT UNSIGNED NOT NULL,
    kind VARCHAR(16) NOT NULL DEFAULT 'dry',
    input_json JSON NULL,
    started_at BIGINT UNSIGNED NOT NULL,
    finish_at BIGINT UNSIGNED NOT NULL,
    status VARCHAR(16) NOT NULL DEFAULT 'running',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    UNIQUE KEY uniq_drugs_processes_slot (kind, station_id),
    INDEX idx_drugs_processes_owner (owner_cid)
)]] },
    { name = '0042 palm6_drugs_dealers', sql = [[
CREATE TABLE IF NOT EXISTS `palm6_drugs_dealers` (
    owner_cid          VARCHAR(64) NOT NULL PRIMARY KEY,
    hired_at           BIGINT UNSIGNED NOT NULL,
    last_tick_at       BIGINT UNSIGNED NOT NULL,
    stash_json         JSON NULL,
    dirty_owed         INT UNSIGNED NOT NULL DEFAULT 0,
    dirty_earned_total BIGINT UNSIGNED NOT NULL DEFAULT 0,
    day_key            VARCHAR(10) NOT NULL DEFAULT '',
    day_dirty          INT UNSIGNED NOT NULL DEFAULT 0,
    created_at         TIMESTAMP DEFAULT CURRENT_TIMESTAMP
)]] },
    { name = '0043 palm6_gangs web columns', sql = [[
ALTER TABLE `palm6_gangs`
    ADD COLUMN IF NOT EXISTS `logo_url`    VARCHAR(512) NULL AFTER `rep`,
    ADD COLUMN IF NOT EXISTS `description` VARCHAR(500) NULL AFTER `logo_url`,
    ADD COLUMN IF NOT EXISTS `color`       VARCHAR(9)   NULL AFTER `description`,
    ADD COLUMN IF NOT EXISTS `updated_at`  TIMESTAMP    NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP AFTER `created_at`
]] },
    { name = '0043 idx_palm6_gangs_rep', sql = [[CREATE INDEX IF NOT EXISTS `idx_palm6_gangs_rep` ON `palm6_gangs` (`rep`)]] },
    { name = '0043 idx_palm6_gangs_vault', sql = [[CREATE INDEX IF NOT EXISTS `idx_palm6_gangs_vault` ON `palm6_gangs` (`vault_balance`)]] },
    { name = '0044 palm6_gang_web_tokens', sql = [[
CREATE TABLE IF NOT EXISTS `palm6_gang_web_tokens` (
    token       VARCHAR(64)     NOT NULL PRIMARY KEY,
    gang_id     INT UNSIGNED    NOT NULL,
    created_at  BIGINT UNSIGNED NOT NULL,
    expires_at  BIGINT UNSIGNED NOT NULL,
    used_at     BIGINT UNSIGNED NULL,
    created_at_ts TIMESTAMP DEFAULT CURRENT_TIMESTAMP
)]] },
    { name = '0044 idx_palm6_gang_web_tokens_gang', sql = [[CREATE INDEX IF NOT EXISTS `idx_palm6_gang_web_tokens_gang` ON `palm6_gang_web_tokens` (`gang_id`)]] },
    { name = '0045 palm6_onboarding starter-grant flags', sql = [[
ALTER TABLE `palm6_onboarding`
    ADD COLUMN IF NOT EXISTS starter_vehicle_granted TINYINT(1) NOT NULL DEFAULT 0,
    ADD COLUMN IF NOT EXISTS starter_outfit_granted  TINYINT(1) NOT NULL DEFAULT 0
]] },
    { name = '0046 palm6_market_state', sql = [[
CREATE TABLE IF NOT EXISTS `palm6_market_state` (
    commodity VARCHAR(64) NOT NULL PRIMARY KEY,
    price     DOUBLE      NOT NULL,
    last_ts   BIGINT      NOT NULL
)]] },
    { name = '0046 palm6_market_trades', sql = [[
CREATE TABLE IF NOT EXISTS `palm6_market_trades` (
    id        INT NOT NULL AUTO_INCREMENT PRIMARY KEY,
    citizenid VARCHAR(64) NOT NULL,
    commodity VARCHAR(64) NOT NULL,
    qty       INT NOT NULL,
    total     INT NOT NULL,
    ts        BIGINT NOT NULL,
    INDEX idx_palm6_market_trades_cid (citizenid),
    INDEX idx_palm6_market_trades_commodity (commodity)
)]] },
    { name = '0047 palm6_yard_sentence', sql = [[
CREATE TABLE IF NOT EXISTS `palm6_yard_sentence` (
    citizenid        VARCHAR(64) NOT NULL PRIMARY KEY,
    baseline_minutes INT         NOT NULL DEFAULT 0,
    shaved_minutes   INT         NOT NULL DEFAULT 0,
    updated_at       BIGINT      NOT NULL DEFAULT 0
)]] },
    { name = '0047 palm6_yard_labor', sql = [[
CREATE TABLE IF NOT EXISTS `palm6_yard_labor` (
    citizenid       VARCHAR(64) NOT NULL PRIMARY KEY,
    last_task_at    BIGINT      NOT NULL DEFAULT 0,
    tasks_completed INT         NOT NULL DEFAULT 0
)]] },
    { name = '0047 palm6_yard_commissary_log', sql = [[
CREATE TABLE IF NOT EXISTS `palm6_yard_commissary_log` (
    citizenid VARCHAR(64) NOT NULL,
    item      VARCHAR(64) NOT NULL,
    ymd       INT         NOT NULL,
    qty       INT         NOT NULL DEFAULT 0,
    PRIMARY KEY (citizenid, item, ymd)
)]] },
    { name = '0047 palm6_yard_bail', sql = [[
CREATE TABLE IF NOT EXISTS `palm6_yard_bail` (
    id               INT         NOT NULL AUTO_INCREMENT PRIMARY KEY,
    citizenid        VARCHAR(64) NOT NULL,
    amount           INT         NOT NULL,
    released_minutes INT         NOT NULL,
    rearrest_until   BIGINT      NOT NULL DEFAULT 0,
    created_at       BIGINT      NOT NULL DEFAULT 0,
    INDEX idx_palm6_yard_bail_cid (citizenid)
)]] },
    { name = '0048 palm6_pulse_windows', sql = [[
CREATE TABLE IF NOT EXISTS `palm6_pulse_windows` (
    id            INT          NOT NULL AUTO_INCREMENT PRIMARY KEY,
    kind          VARCHAR(32)  NOT NULL,
    domain        VARCHAR(16)  NOT NULL,
    modifier      DOUBLE       NOT NULL,
    target        VARCHAR(64)  NULL,
    reason        VARCHAR(128) NOT NULL,
    online_start  INT          NOT NULL DEFAULT 0,
    started_at    BIGINT       NOT NULL,
    ends_at       BIGINT       NOT NULL,
    INDEX idx_palm6_pulse_windows_ends (ends_at)
)]] },
    { name = '0048 palm6_pulse_checkins', sql = [[
CREATE TABLE IF NOT EXISTS `palm6_pulse_checkins` (
    id          INT          NOT NULL AUTO_INCREMENT PRIMARY KEY,
    window_id   INT          NOT NULL,
    citizenid   VARCHAR(64)  NOT NULL,
    ts          BIGINT       NOT NULL,
    UNIQUE KEY uq_palm6_pulse_checkin (window_id, citizenid),
    INDEX idx_palm6_pulse_checkins_cid (citizenid)
)]] },
    { name = '0048 palm6_pulse_streaks', sql = [[
CREATE TABLE IF NOT EXISTS `palm6_pulse_streaks` (
    citizenid       VARCHAR(64) NOT NULL PRIMARY KEY,
    streak          INT         NOT NULL DEFAULT 0,
    best_streak     INT         NOT NULL DEFAULT 0,
    pulse_points    INT         NOT NULL DEFAULT 0,
    last_window_id  INT         NOT NULL DEFAULT 0,
    updated_at      BIGINT      NOT NULL DEFAULT 0
)]] },
    -- 0049: reconcile turf ownership after the gang-identity change (turf now
    -- keys on palm6_gangs.name). Idempotent — only nulls turf whose owner_gang
    -- is NOT a current palm6_gangs name, so it is safe to re-run every boot and
    -- also auto-releases turf held by a since-disbanded gang. See sql/0049.
    { name = '0049 palm6_turf identity reset', sql = [[
UPDATE `palm6_turf`
   SET `owner_gang` = NULL, `captured_by` = NULL, `captured_at` = NULL
 WHERE `owner_gang` IS NOT NULL
   AND `owner_gang` NOT IN (SELECT `name` FROM `palm6_gangs`)]] },
}

CreateThread(function()
    Wait(3000) -- let oxmysql establish its connection first
    print('[palm6_dbmigrate] ============================================')
    print('[palm6_dbmigrate] applying pending idempotent migrations...')
    local ok, fail = 0, 0
    for _, stmt in ipairs(STATEMENTS) do
        local success, err = pcall(function() MySQL.query.await(stmt.sql) end)
        if success then
            ok = ok + 1
            print(('[palm6_dbmigrate]   OK   %s'):format(stmt.name))
        else
            fail = fail + 1
            print(('[palm6_dbmigrate]   FAIL %s -> %s'):format(stmt.name, tostring(err)))
        end
    end
    -- verification: confirm the meth-lab-critical table exists
    local present = false
    local vok, vres = pcall(function() return MySQL.query.await("SHOW TABLES LIKE 'palm6_drugs_processes'") end)
    if vok and vres and #vres > 0 then present = true end
    print(('[palm6_dbmigrate] done: %d ok, %d failed. palm6_drugs_processes present = %s'):format(ok, fail, tostring(present)))
    print('[palm6_dbmigrate] SAFE TO REMOVE this resource now (all statements are IF NOT EXISTS).')
    print('[palm6_dbmigrate] ============================================')
end)
