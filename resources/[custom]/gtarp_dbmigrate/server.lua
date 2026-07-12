-- ===========================================================================
-- gtarp_dbmigrate — ONE-SHOT idempotent migration applier
-- ---------------------------------------------------------------------------
-- The prod DB (db-dtx-06) is not reachable from outside the panel network and
-- CI never touches the DB, so migrations 0040/0042/0043/0044 are applied here
-- using the game server's own oxmysql connection on boot. Every statement is
-- IF NOT EXISTS, so re-running is a harmless no-op. Each runs independently
-- (pcall-guarded) so one failure never blocks the rest. REMOVE this resource
-- after the console shows all statements OK and the tables are confirmed.
-- ===========================================================================

local STATEMENTS = {
    { name = '0040 gtarp_drugs_processes', sql = [[
CREATE TABLE IF NOT EXISTS `gtarp_drugs_processes` (
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
    { name = '0042 gtarp_drugs_dealers', sql = [[
CREATE TABLE IF NOT EXISTS `gtarp_drugs_dealers` (
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
    { name = '0043 gtarp_gangs web columns', sql = [[
ALTER TABLE `gtarp_gangs`
    ADD COLUMN IF NOT EXISTS `logo_url`    VARCHAR(512) NULL AFTER `rep`,
    ADD COLUMN IF NOT EXISTS `description` VARCHAR(500) NULL AFTER `logo_url`,
    ADD COLUMN IF NOT EXISTS `color`       VARCHAR(9)   NULL AFTER `description`,
    ADD COLUMN IF NOT EXISTS `updated_at`  TIMESTAMP    NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP AFTER `created_at`
]] },
    { name = '0043 idx_gtarp_gangs_rep', sql = [[CREATE INDEX IF NOT EXISTS `idx_gtarp_gangs_rep` ON `gtarp_gangs` (`rep`)]] },
    { name = '0043 idx_gtarp_gangs_vault', sql = [[CREATE INDEX IF NOT EXISTS `idx_gtarp_gangs_vault` ON `gtarp_gangs` (`vault_balance`)]] },
    { name = '0044 gtarp_gang_web_tokens', sql = [[
CREATE TABLE IF NOT EXISTS `gtarp_gang_web_tokens` (
    token       VARCHAR(64)     NOT NULL PRIMARY KEY,
    gang_id     INT UNSIGNED    NOT NULL,
    created_at  BIGINT UNSIGNED NOT NULL,
    expires_at  BIGINT UNSIGNED NOT NULL,
    used_at     BIGINT UNSIGNED NULL,
    created_at_ts TIMESTAMP DEFAULT CURRENT_TIMESTAMP
)]] },
    { name = '0044 idx_gtarp_gang_web_tokens_gang', sql = [[CREATE INDEX IF NOT EXISTS `idx_gtarp_gang_web_tokens_gang` ON `gtarp_gang_web_tokens` (`gang_id`)]] },
}

CreateThread(function()
    Wait(3000) -- let oxmysql establish its connection first
    print('[gtarp_dbmigrate] ============================================')
    print('[gtarp_dbmigrate] applying pending idempotent migrations...')
    local ok, fail = 0, 0
    for _, stmt in ipairs(STATEMENTS) do
        local success, err = pcall(function() MySQL.query.await(stmt.sql) end)
        if success then
            ok = ok + 1
            print(('[gtarp_dbmigrate]   OK   %s'):format(stmt.name))
        else
            fail = fail + 1
            print(('[gtarp_dbmigrate]   FAIL %s -> %s'):format(stmt.name, tostring(err)))
        end
    end
    -- verification: confirm the meth-lab-critical table exists
    local present = false
    local vok, vres = pcall(function() return MySQL.query.await("SHOW TABLES LIKE 'gtarp_drugs_processes'") end)
    if vok and vres and #vres > 0 then present = true end
    print(('[gtarp_dbmigrate] done: %d ok, %d failed. gtarp_drugs_processes present = %s'):format(ok, fail, tostring(present)))
    print('[gtarp_dbmigrate] SAFE TO REMOVE this resource now (all statements are IF NOT EXISTS).')
    print('[gtarp_dbmigrate] ============================================')
end)
