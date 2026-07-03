-- ============================================================================
-- 0020_counterfeit.sql — gtarp_counterfeit: counterfeit cash with a memory.
--
-- Six tables, all `gtarp_`-prefixed per the defensive convention adopted
-- after the 0010_properties.sql collision (see 0012_evidence.sql notes):
--
--   gtarp_counterfeit_printers  placed presses: owner, district, coords,
--                               hopper reserves, placed/removed/seized.
--   gtarp_counterfeit_batches   one row per print cycle: code, printer,
--                               printer's citizenid, district, size, and
--                               `circulation` — the batch-level count of
--                               hands its paper has passed through (drives
--                               sink detection + fence rejection).
--   gtarp_counterfeit_wads      the serial REGISTRY — one row per printed
--                               wad. `serial` is carried in item metadata;
--                               status tracks its exit from circulation.
--   gtarp_counterfeit_hops      the provenance chain: (from, to, timestamp)
--                               per transfer, HARD-CAPPED at the newest
--                               Config.HopCap (6) rows per serial by the
--                               resource (old rows are deleted on append —
--                               the trail genuinely wears off).
--   gtarp_counterfeit_leads     cascade bookkeeping: how many hops of a
--                               serial's chain have been revealed into a
--                               gtarp_evidence case (case ids come from the
--                               gtarp_evidence v2 export API — no evidence
--                               data is duplicated here).
--   gtarp_counterfeit_heat      district heat, so decay/pings survive restarts.
--
-- No framework tables are touched here. Apply after the qbx base schema
-- (and after 0018_evidence_v2.sql if you want the serial terminal live).
-- ============================================================================

CREATE TABLE IF NOT EXISTS `gtarp_counterfeit_printers` (
    id INT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
    owner_citizenid VARCHAR(64) NOT NULL,
    owner_name VARCHAR(100) NOT NULL DEFAULT '',
    district_id VARCHAR(32) NOT NULL,
    coords TEXT NOT NULL,                 -- json {x,y,z} (server-side position)
    heading FLOAT NOT NULL DEFAULT 0.0,
    paper SMALLINT UNSIGNED NOT NULL DEFAULT 0,
    ink SMALLINT UNSIGNED NOT NULL DEFAULT 0,
    status ENUM('placed','removed','seized') NOT NULL DEFAULT 'placed',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    seized_at TIMESTAMP NULL DEFAULT NULL,
    INDEX idx_gtarp_counterfeit_printers_owner (owner_citizenid, status),
    INDEX idx_gtarp_counterfeit_printers_status (status)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS `gtarp_counterfeit_batches` (
    id INT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
    code CHAR(6) NOT NULL UNIQUE,         -- human-readable batch code (in serials)
    printer_id INT UNSIGNED NOT NULL,
    printed_by VARCHAR(64) NOT NULL,      -- citizenid of the printer operator
    printed_by_name VARCHAR(100) NOT NULL DEFAULT '',
    district_id VARCHAR(32) NOT NULL,
    face_value INT UNSIGNED NOT NULL,
    wads_printed SMALLINT UNSIGNED NOT NULL DEFAULT 0,
    -- Hands this batch's paper has passed through (trades + sink/fence
    -- passes). Quality decays with greed: detection and rejection curves
    -- read this number.
    circulation INT UNSIGNED NOT NULL DEFAULT 0,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    INDEX idx_gtarp_counterfeit_batches_printer (printer_id),
    INDEX idx_gtarp_counterfeit_batches_printed_by (printed_by)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS `gtarp_counterfeit_wads` (
    id INT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
    serial VARCHAR(20) NOT NULL UNIQUE,   -- e.g. "CF-K7M2PQ-03"; in item metadata
    batch_code CHAR(6) NOT NULL,
    -- circulating: out in the world.  spent: sunk at a vendor for goods.
    -- fenced: cashed out at a fence.  burned: caught and kept by an NPC.
    -- seized: bagged by police (unlocks /runserial).
    status ENUM('circulating','spent','fenced','burned','seized')
        NOT NULL DEFAULT 'circulating',
    seized_by VARCHAR(64) DEFAULT NULL,   -- officer citizenid, when seized
    seized_at TIMESTAMP NULL DEFAULT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    INDEX idx_gtarp_counterfeit_wads_batch (batch_code),
    INDEX idx_gtarp_counterfeit_wads_status (status)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS `gtarp_counterfeit_hops` (
    id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
    serial VARCHAR(20) NOT NULL,
    -- print: minted (THE PRESS -> operator).  trade: player -> player.
    -- drop/pickup: through the ground or a stash.  sink/fence: passed to an
    -- NPC counter (to_name carries the venue label).
    kind ENUM('print','trade','drop','pickup','sink','fence') NOT NULL,
    from_citizenid VARCHAR(64) DEFAULT NULL,
    from_name VARCHAR(100) NOT NULL DEFAULT '',
    to_citizenid VARCHAR(64) DEFAULT NULL,
    to_name VARCHAR(100) NOT NULL DEFAULT '',
    detail VARCHAR(190) DEFAULT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    -- Capped at the newest Config.HopCap rows per serial by the resource
    -- (delete-on-append). The index serves both the append trim and the
    -- newest-first chain reads.
    INDEX idx_gtarp_counterfeit_hops_serial (serial, id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS `gtarp_counterfeit_leads` (
    id INT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
    case_id INT UNSIGNED NOT NULL,        -- gtarp_evidence case (via v2 exports)
    serial VARCHAR(20) NOT NULL,
    batch_code CHAR(6) NOT NULL,
    -- How many hops (newest-first) have been revealed into the case.
    -- /runserial seeds Config.Police.LeadsPerRun; each successful
    -- /interrogate adds Config.Police.LeadsPerPress.
    depth SMALLINT UNSIGNED NOT NULL DEFAULT 0,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    UNIQUE KEY uq_gtarp_counterfeit_leads_case_serial (case_id, serial),
    INDEX idx_gtarp_counterfeit_leads_case (case_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS `gtarp_counterfeit_heat` (
    district_id VARCHAR(32) NOT NULL PRIMARY KEY,
    heat FLOAT NOT NULL DEFAULT 0,
    last_ping INT UNSIGNED NOT NULL DEFAULT 0,   -- unix seconds, server clock
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
