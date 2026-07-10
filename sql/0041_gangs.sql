-- 0041_gangs.sql — tables for gtarp_gangs (player-run gang management layer).
-- Apply after the qbx base schema. Restart-safe (CREATE TABLE IF NOT EXISTS).
--
-- NAMING: gtarp_-prefixed on purpose. The logical names are gangs /
-- gang_members / gang_vault_log, but qbx_core's gang DATA model is a STATIC
-- config registry (not a DB table), and the QBCore ecosystem's gang add-ons
-- (qb-gangs / ps-gangs) DO ship unprefixed `gangs` / `gang_members` tables.
-- An unprefixed table already silently collided with a recipe resource once
-- in this repo (see 0033_laundering.sql), so we prefix to stay collision-safe.
-- These three tables are OURS — the missing player-created/vault/rep layer
-- Qbox does not provide — so they carry to GTA VI as-is (Tier 1).

-- One row per player-created gang. name + tag are unique (display identity).
-- vault_balance is the shared CASH vault (whole dollars). rep is the gang
-- reputation integer other resources reward via the AddRep export.
CREATE TABLE IF NOT EXISTS `gtarp_gangs` (
    id INT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
    name VARCHAR(32) NOT NULL,
    tag VARCHAR(8) NOT NULL,
    leader_cid VARCHAR(64) NOT NULL,
    vault_balance BIGINT UNSIGNED NOT NULL DEFAULT 0,
    rep INT NOT NULL DEFAULT 0,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    UNIQUE KEY uniq_gtarp_gang_name (name),
    UNIQUE KEY uniq_gtarp_gang_tag (tag),
    INDEX idx_gtarp_gang_leader (leader_cid)
);

-- Membership. PRIMARY KEY on citizenid enforces ONE gang per player at the
-- schema level (the server also re-checks, but this is the hard guarantee).
-- rank: 1 = member, 2 = officer, 3 = leader. name is the character name at
-- join time, cached so the roster renders for offline members too.
CREATE TABLE IF NOT EXISTS `gtarp_gang_members` (
    citizenid VARCHAR(64) NOT NULL PRIMARY KEY,
    gang_id INT UNSIGNED NOT NULL,
    rank TINYINT UNSIGNED NOT NULL DEFAULT 1,
    name VARCHAR(64) NULL DEFAULT NULL,
    joined_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    INDEX idx_gtarp_gang_members_gang (gang_id)
);

-- Append-only vault ledger. One row per deposit/withdraw, with the resulting
-- balance snapshot so the ledger is auditable independent of the live row.
CREATE TABLE IF NOT EXISTS `gtarp_gang_vault_log` (
    id INT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
    gang_id INT UNSIGNED NOT NULL,
    citizenid VARCHAR(64) NOT NULL,
    action VARCHAR(16) NOT NULL,
    amount BIGINT UNSIGNED NOT NULL,
    balance_after BIGINT UNSIGNED NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    INDEX idx_gtarp_gang_vault_gang (gang_id, created_at)
);
