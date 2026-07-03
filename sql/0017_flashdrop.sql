-- ============================================================================
-- 0017_flashdrop.sql — gtarp_flashdrop hype-drop economy tables.
--
-- Four tables, all `gtarp_`-prefixed per the defensive convention adopted
-- after the 0010_properties.sql collision (see 0012_evidence.sql notes):
--
--   gtarp_flashdrop_drops       one row per drop EVENT (a catalog item armed
--                               at a location with a hard supply cap).
--   gtarp_flashdrop_serials     the serial REGISTRY — the server-side source
--                               of truth for authentic / counterfeit / dirty.
--                               `uid` is the opaque token carried in item
--                               metadata; `serial` is the display string
--                               (fakes may duplicate a real display serial —
--                               that is the scam — so only `uid` is UNIQUE).
--   gtarp_flashdrop_provenance  append-only transfer/audit tape per uid:
--                               claim, listing, sale, fence, stolen report,
--                               legit check, counterfeit mint.
--   gtarp_flashdrop_listings    the consignment shelf.
--
-- No framework tables are touched here. Apply after the qbx base schema.
-- ============================================================================

CREATE TABLE IF NOT EXISTS `gtarp_flashdrop_drops` (
    id INT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
    catalog_code VARCHAR(8) NOT NULL,
    label VARCHAR(100) NOT NULL,
    location_id VARCHAR(50) NOT NULL,
    retail INT UNSIGNED NOT NULL,
    supply_cap SMALLINT UNSIGNED NOT NULL,
    claimed SMALLINT UNSIGNED NOT NULL DEFAULT 0,
    status ENUM('announced','revealed','live','sold_out','expired','cancelled')
        NOT NULL DEFAULT 'announced',
    -- Timeline (unix seconds, server clock): riddle at hint_at, coords at
    -- reveal_at, checkout opens at live_at, closes at closes_at.
    hint_at INT UNSIGNED NOT NULL,
    reveal_at INT UNSIGNED NOT NULL,
    live_at INT UNSIGNED NOT NULL,
    closes_at INT UNSIGNED NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    INDEX idx_gtarp_flashdrop_drops_status (status)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS `gtarp_flashdrop_serials` (
    id INT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
    -- Opaque token in item metadata. Identical in shape on real and fake
    -- pairs so client-side inspection can never tell them apart.
    uid CHAR(16) NOT NULL UNIQUE,
    -- Display serial, e.g. "GRAL-004/6". NOT unique: counterfeits clone a
    -- plausible real serial on purpose.
    serial VARCHAR(32) NOT NULL,
    drop_id INT UNSIGNED NOT NULL,
    catalog_code VARCHAR(8) NOT NULL,
    is_fake TINYINT(1) NOT NULL DEFAULT 0,
    is_dirty TINYINT(1) NOT NULL DEFAULT 0,
    -- Last owner seen through a MEDIATED transfer (claim/sale/fence). Street
    -- trades and robberies move the item without touching this — that gap is
    -- what stolen reports and legit checks exist for.
    owner_citizenid VARCHAR(64) NOT NULL,
    -- Original claimant (or counterfeiter). Immutable; enforces one-per-
    -- citizen at the drop and feeds provenance.
    claimed_by VARCHAR(64) NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    INDEX idx_gtarp_flashdrop_serials_owner (owner_citizenid),
    INDEX idx_gtarp_flashdrop_serials_drop (drop_id),
    INDEX idx_gtarp_flashdrop_serials_claim (drop_id, claimed_by)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS `gtarp_flashdrop_provenance` (
    id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
    uid CHAR(16) NOT NULL,
    event ENUM('drop_claim','counterfeit_mint','consign_list','consign_cancel',
               'consign_sale','fenced','reported_stolen','legit_check')
        NOT NULL,
    actor_citizenid VARCHAR(64) NOT NULL,
    actor_name VARCHAR(100) NOT NULL DEFAULT '',
    counterparty_citizenid VARCHAR(64) DEFAULT NULL,
    price INT DEFAULT NULL,
    detail VARCHAR(190) DEFAULT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    INDEX idx_gtarp_flashdrop_prov_uid (uid, id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS `gtarp_flashdrop_listings` (
    id INT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
    uid CHAR(16) NOT NULL,
    seller_citizenid VARCHAR(64) NOT NULL,
    seller_name VARCHAR(100) NOT NULL,
    price INT UNSIGNED NOT NULL,
    status ENUM('active','sold','cancelled') NOT NULL DEFAULT 'active',
    buyer_citizenid VARCHAR(64) DEFAULT NULL,
    listed_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    resolved_at TIMESTAMP NULL DEFAULT NULL,
    INDEX idx_gtarp_flashdrop_listings_status (status),
    INDEX idx_gtarp_flashdrop_listings_seller (seller_citizenid, status)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
