-- ============================================================================
-- 0019_witnesses.sql — gtarp_witnesses NPC-witness tables.
--
-- Two tables, both `gtarp_`-prefixed per the defensive convention adopted
-- after the 0010_properties.sql collision (see 0012_evidence.sql notes):
--
--   gtarp_witnesses_incidents  one row per witnessed CRIME (event-bus hit
--                              that found NPC bystanders). Holds the full
--                              server-captured fact pool and, once the
--                              first canvass lands, the gtarp_evidence
--                              case id (cases are created lazily through
--                              the frozen EnsureCase export — this file
--                              touches NO gtarp_evidence table).
--   gtarp_witnesses            the witness markers themselves: a street
--                              position + the 1-2 facts dealt to that
--                              witness, plus press/payoff state. The peds
--                              players see are cosmetic; these rows are
--                              the testimony.
--
-- Timestamps on incidents are unix seconds (server clock) so the expiry
-- sweep and restart reload compare against os.time() without TZ math.
--
-- No framework tables are touched here. Apply after the qbx base schema
-- (and after 0018_evidence_v2.sql if you want canvasses to reach case
-- files — the resource degrades gracefully without it).
-- ============================================================================

CREATE TABLE IF NOT EXISTS `gtarp_witnesses_incidents` (
    id INT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
    -- Opaque incident token; feeds the gtarp_evidence EnsureCase
    -- incident_key ('gtarp_witnesses:<uid>') so concurrent canvasses of
    -- the same incident converge on one case.
    uid CHAR(16) NOT NULL UNIQUE,
    crime VARCHAR(32) NOT NULL,
    label VARCHAR(64) NOT NULL,
    suspect_citizenid VARCHAR(64) NOT NULL,
    -- Crime location (marker anchor for the incident, not the witnesses).
    x DOUBLE NOT NULL,
    y DOUBLE NOT NULL,
    z DOUBLE NOT NULL,
    -- Everything the suspect exposed at crime time, captured server-side
    -- (JSON array of { key, text }). Witnesses hold subsets of this.
    fact_pool TEXT NOT NULL,
    -- Set on first canvass via the gtarp_evidence v2 EnsureCase export.
    case_id INT UNSIGNED DEFAULT NULL,
    created_at INT UNSIGNED NOT NULL,
    expires_at INT UNSIGNED NOT NULL,
    INDEX idx_gtarp_witnesses_incidents_suspect (suspect_citizenid),
    INDEX idx_gtarp_witnesses_incidents_expires (expires_at)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS `gtarp_witnesses` (
    id INT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
    incident_id INT UNSIGNED NOT NULL,
    -- Street-corner position the witness was snapshotted at (the marker).
    x DOUBLE NOT NULL,
    y DOUBLE NOT NULL,
    z DOUBLE NOT NULL,
    -- The 1-2 facts this witness actually holds (JSON array of
    -- { key, text }) — dealt from the incident's fact_pool at crime time.
    facts TEXT NOT NULL,
    -- Generated when the witness is pressed: same shape as `facts` but
    -- wrong (wrong colour, flipped mask, scrambled plate). A canvass of a
    -- pressed witness feeds these to the case file as if they were real.
    corrupted_facts TEXT DEFAULT NULL,
    -- active    -> marker live, canvass yields real facts
    -- pressed   -> canvass yields corrupted facts or nothing
    -- paid      -> canvass yields nothing ("never saw you")
    -- canvassed -> spent; marker gone (each witness talks once)
    status ENUM('active','pressed','paid','canvassed') NOT NULL DEFAULT 'active',
    -- citizenid of whoever changed the status (canvassing officer,
    -- pressing/paying suspect) — audit trail.
    status_by VARCHAR(64) DEFAULT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    INDEX idx_gtarp_witnesses_incident (incident_id),
    INDEX idx_gtarp_witnesses_status (status)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
