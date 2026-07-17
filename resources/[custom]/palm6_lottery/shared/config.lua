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
    buy     = 3,
    status  = 2,
    draw    = 5,
    scratch = 2,   -- instant scratch card play
}

-- Instant scratch cards (bought at the kiosk). A pure server-side RNG money
-- SINK: you pay Price, the server rolls a weighted prize, and the house keeps
-- the difference. Expected payout is deliberately BELOW Price (a house edge), so
-- over time it drains clean cash from the economy like the draw's rake. Each
-- prize has a weight (relative odds) and a payout ($; 0 = no win). Tune freely —
-- keep the summed weighted payout under Price to keep the edge. Current table:
-- EV = (25*300 + 12*700 + 6*1500 + 2*5000)/100 = $349 vs $500 price (~30% edge).
Config.Scratch = {
    Price  = 500,
    Prizes = {
        { weight = 55, payout = 0,     label = 'No luck this time' },
        { weight = 25, payout = 300,   label = 'Small win' },
        { weight = 12, payout = 700,   label = 'Nice!' },
        { weight = 6,  payout = 1500,  label = 'Big win!' },
        { weight = 2,  payout = 5000,  label = '💎 JACKPOT!' },
    },
}

-- The lottery kiosk: a clerk NPC + map blip you walk up to, so the lottery is a
-- discoverable destination (with a visible growing jackpot) instead of a hidden
-- command. Purely presentation — every action fires a server event that re-runs
-- the same authority as /lottery. PLACEHOLDER coords near the Innocence Blvd 24/7
-- (Davis) — reposition in-game to taste.
Config.Kiosk = {
    model   = 'mp_m_shopkeep_01',
    coords  = { x = 25.7, y = -1347.3, z = 29.5 },
    heading = 270.0,
    label   = 'City Lottery kiosk',
    icon    = 'fa-solid fa-ticket',
    blip    = { sprite = 279, color = 5, scale = 0.8, label = 'City Lottery' },
}

-- Quick-buy buttons shown in the kiosk menu (each is a ticket count). A custom
-- amount is always available too, bounded by Config.MaxPerBuy / MaxTicketsPerDraw.
Config.QuickBuys = { 1, 5, 10 }
