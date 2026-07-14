-- ============================================================================
-- palm6_lottery/shared/config.lua - engine-agnostic tunables (Tier 1, carries
-- to VI). Mirrors the Config / Config.RateLimits shape from palm6_citations
-- and palm6_ems.
--
-- The lottery is an ECONOMY SINK. Players buy tickets with CLEAN bank money
-- into a shared pot. On a scheduled draw a random ticket wins the pot minus a
-- house rake, and the rake is the sink: that money was charged from buyers and
-- is never credited back, so it leaves circulation for good. Every amount here
-- is server-enforced; the client never sends a price or a pot value.
-- ============================================================================
Config = {}

Config.Debug = false

-- Ticket economics (all server-computed; a modified client cannot change any
-- of these).
Config.TicketPrice         = 500    -- clean bank $ per ticket
Config.MaxTicketsPerDraw   = 50     -- cap per player, per draw (exposure limit)
Config.MaxPerBuy           = 25     -- most tickets a single /lottery buy may add
Config.RakePercent         = 20     -- house cut of the pot, in percent (the SINK)
Config.MinPotToDraw        = 5000   -- a draw only fires once the pot reaches this
Config.DrawIntervalMinutes = 60     -- real minutes between scheduled draws
Config.TickSeconds         = 30     -- how often the timer checks for a due draw

-- Admin ace for /lotterydraw. Grant once (NOT added to custom.cfg by this
-- resource): add_ace group.admin command.lotterydraw allow
-- The server console (src 0) can always force a draw without the ace.
Config.AdminAce = 'command.lotterydraw'

-- Per-source command cooldowns (seconds), mirroring palm6_ems.RateLimits.
Config.RateLimits = {
    buy    = 3,
    status = 2,
    draw   = 5,
}
