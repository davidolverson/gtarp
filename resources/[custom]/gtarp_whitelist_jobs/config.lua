-- ============================================================================
-- gtarp_whitelist_jobs/config.lua
--
-- Lists which identifiers are permitted to hold each whitelisted job.
-- Matching is EXACT string equality against each entry in
-- GetPlayerIdentifiers (server/main.lua's listContains) — NOT a substring
-- match. Use the full identifier (e.g. `license:abcdef0123...`), not a
-- prefix/fragment, or the roster entry will never match anyone.
--
-- Source of truth for emergency-services rosters. Allowlist (Phase 9)
-- will read this same table when wiring Discord-role gating.
-- ============================================================================

Config = {}

-- Whitelisted jobs and the principals allowed to hold them. Replace the
-- CHANGEME values with real identifiers (license:..., discord:..., fivem:...).
Config.Allowed = {
    police = {
        -- 'license:CHANGEME_OFFICER_1',
        -- 'discord:000000000000000000',
    },
    ambulance = {
        -- 'license:CHANGEME_EMT_1',
    },
}

-- Staff override: identifiers in this list bypass the whitelist for ANY
-- job (used by admins for test/setup). Keep tight.
Config.StaffOverride = {
    -- 'license:CHANGEME_OWNER',
}

-- Friendly message returned when a setjob is denied.
Config.DenyMessage = 'You are not on the whitelist for that job. Contact staff in Discord.'
