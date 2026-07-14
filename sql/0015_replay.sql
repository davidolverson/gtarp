-- ============================================================================
-- 0015_replay.sql — palm6_replay scene storage (the city black-box).
--
-- Two tables, both `palm6_`-prefixed per the defensive convention adopted
-- after the 0010_properties.sql collision:
--
--   palm6_replay_scenes       one row per flagged incident. Numeric coord
--                             columns (not JSON) so the nearby-scene query
--                             can bounding-box in SQL instead of parsing.
--   palm6_replay_participants one row per player captured in a scene; the
--                             4 Hz telemetry frames live here as a JSON
--                             array, server-sanitised and hard-capped
--                             (Config.Incident.MaxFrames / MaxParticipants)
--                             before insert, so row size is bounded.
--
-- No FK constraint (house style — no other migration uses them); the
-- resource deletes participants alongside their scene on prune.
-- ============================================================================

CREATE TABLE IF NOT EXISTS `palm6_replay_scenes` (
    id INT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
    incident_type VARCHAR(32) NOT NULL,       -- shots | damage | downed | robbery | bodycam | manual
    label VARCHAR(120) NOT NULL,
    x DOUBLE NOT NULL,
    y DOUBLE NOT NULL,
    z DOUBLE NOT NULL,
    flagged_by VARCHAR(64) DEFAULT NULL,      -- citizenid for officer-initiated scenes, NULL for automatic
    participant_count TINYINT UNSIGNED NOT NULL DEFAULT 0,
    case_ref VARCHAR(120) DEFAULT NULL,       -- set by /replayattach (evidence-exhibit note)
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    expires_at TIMESTAMP NULL DEFAULT NULL,
    INDEX idx_palm6_replay_scenes_created (created_at),
    INDEX idx_palm6_replay_scenes_expires (expires_at),
    INDEX idx_palm6_replay_scenes_xy (x, y)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS `palm6_replay_participants` (
    id INT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
    scene_id INT UNSIGNED NOT NULL,
    citizenid VARCHAR(64) NOT NULL,
    player_name VARCHAR(100) NOT NULL,
    ped_model VARCHAR(32) NOT NULL,           -- model hash as string (fallback applied at playback)
    frame_count SMALLINT UNSIGNED NOT NULL DEFAULT 0,
    frames MEDIUMTEXT NOT NULL,               -- sanitised JSON array of 4 Hz frames
    INDEX idx_palm6_replay_participants_scene (scene_id),
    INDEX idx_palm6_replay_participants_citizenid (citizenid)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
