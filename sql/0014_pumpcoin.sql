-- ============================================================================
-- 0014_pumpcoin.sql — palm6_pumpcoin player-issued token exchange tables.
--
-- Three tables, all `palm6_`-prefixed per the defensive convention adopted
-- after the 0010_properties.sql collision (see 0012_evidence.sql notes):
--
--   palm6_pumpcoin_coins     one row per minted coin. base_price / curve_k
--                            are SNAPSHOTTED at mint so later config changes
--                            never corrupt a live curve.
--   palm6_pumpcoin_holdings  who holds how many units of which coin.
--                            Invariant: SUM(units) per coin == supply_sold.
--   palm6_pumpcoin_trades    append-only tape. Feeds the NUI price chart and
--                            is the audit trail for rug forensics.
--
-- No framework tables are touched here. Apply after the qbx base schema.
-- ============================================================================

CREATE TABLE IF NOT EXISTS `palm6_pumpcoin_coins` (
    id INT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
    name VARCHAR(32) NOT NULL,
    ticker VARCHAR(8) NOT NULL,
    emoji VARCHAR(16) NOT NULL,
    creator_citizenid VARCHAR(64) NOT NULL,
    creator_name VARCHAR(100) NOT NULL,
    -- Bonding-curve parameters, frozen at mint time.
    base_price DECIMAL(12,2) NOT NULL,
    curve_k INT UNSIGNED NOT NULL,
    -- Units currently on the curve (includes the dev premine). Total units
    -- held across all holders always equals this number.
    supply_sold INT UNSIGNED NOT NULL DEFAULT 0,
    -- Units premined to the creator's hidden dev wallet at mint.
    dev_allocation INT UNSIGNED NOT NULL DEFAULT 0,
    -- 1 when the creator's gang held enough turf at mint (palm6_turf synergy).
    verified TINYINT(1) NOT NULL DEFAULT 0,
    status ENUM('live','rugged','delisted') NOT NULL DEFAULT 'live',
    rugged_at TIMESTAMP NULL DEFAULT NULL,
    -- 1 once the post-rug anonymity window has elapsed and the creator's
    -- identity has been broadcast.
    revealed TINYINT(1) NOT NULL DEFAULT 0,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    delisted_at TIMESTAMP NULL DEFAULT NULL,
    INDEX idx_palm6_pumpcoin_coins_status (status),
    INDEX idx_palm6_pumpcoin_coins_creator (creator_citizenid)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS `palm6_pumpcoin_holdings` (
    coin_id INT UNSIGNED NOT NULL,
    citizenid VARCHAR(64) NOT NULL,
    units INT UNSIGNED NOT NULL DEFAULT 0,
    PRIMARY KEY (coin_id, citizenid),
    INDEX idx_palm6_pumpcoin_holdings_citizenid (citizenid)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS `palm6_pumpcoin_trades` (
    id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
    coin_id INT UNSIGNED NOT NULL,
    citizenid VARCHAR(64) NOT NULL,
    side ENUM('mint','buy','sell','rug','delist') NOT NULL,
    units INT UNSIGNED NOT NULL,
    -- Average unit price for this fill (pre-fee), for the chart.
    unit_price DECIMAL(12,2) NOT NULL,
    -- What actually moved in/out of the player's bank (post-fee, whole $).
    total INT NOT NULL DEFAULT 0,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    INDEX idx_palm6_pumpcoin_trades_coin (coin_id, id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
