-- ============================================================================
-- gtarp_onboarding/shared/config.lua — engine-agnostic tunables (Tier 1, carries to VI).
-- ============================================================================
Config = {}

Config.Debug = false

-- Rate limit on the accept-rules net event (server-authoritative; a real
-- accept only ever fires once per citizen, this just bounds retry/replay
-- spam from a modified client).
Config.AcceptCooldownSec = 5

Config.Rules = {
    header = 'City Rules',
    -- Plain-text content shown in the mandatory first-load dialog and via
    -- /rules any time after. Edit for your server's real rules. Kept short
    -- on purpose — a wall of legalese gets skimmed, not read.
    content = table.concat({
        '1. **Roleplay first.** Stay in character. Metagaming and powergaming break the story for everyone else.',
        '2. **Fear for your life.** Take fights, arrests, and injuries seriously — no combat logging, no instant-forgetting a robbery at gunpoint.',
        '3. **New Life Rule.** A character who dies loses memory of the events leading to it.',
        '4. **No exploiting.** Bugs, dupes, and out-of-bounds areas get reported to staff, not abused.',
        '5. **Staff calls are final in the moment.** Disagree after the fact via a ticket, not in the moment.',
        '',
        'Breaking these gets you warned, then kicked, then banned. Full rules and the ban-appeal process are pinned in Discord.',
    }, '\n'),
}

-- Short post-accept tour — kept accurate to what this server actually has.
-- Update this list if a referenced command/system is renamed or removed.
Config.Tour = {
    header = 'Getting Started',
    content = table.concat({
        'Bank & cash — check your phone/inventory for your balance; ATMs are marked on the map.',
        'Jobs — visit a job center or the relevant NPC to get started; `/rules` re-shows this text anytime.',
        'Need help? Ping staff in Discord — an admin can `/tp` to you if something is stuck.',
        'Planning on going into law enforcement? The MDT (`/mdt`) is your case log, warrants, and BOLOs once on duty.',
    }, '\n'),
}

Config.StarterCash = {
    enabled = true,
    amount = 1500,
    account = 'bank',
    reason = 'onboarding-starter-cash',
}
