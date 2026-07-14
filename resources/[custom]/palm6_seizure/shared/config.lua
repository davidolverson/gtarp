-- ============================================================================
-- palm6_seizure/shared/config.lua — engine-agnostic tunables (Tier 1).
--
-- DESIGN INTENT — the law's counter-lever on the dirty-money economy. Every
-- crime resource on this server pays out DIRTY (`black_money`): bank robbery,
-- numbers winnings, protection shakedowns, loan-shark principal. All of it
-- flows toward palm6_laundering's wash. Nothing lets police INTERDICT it.
-- palm6_seizure is that: an on-duty officer standing over a WANTED suspect can
-- forfeit the suspect's dirty money — it's removed from circulation, written to
-- a persistent forfeiture ledger, and attached to a palm6_evidence case.
--
-- NOT qbx_police /seizecash. That grabs a suspect's CLEAN `cash` account into a
-- `moneybag` item, records nothing, and never touches black_money. This touches
-- ONLY `black_money`, records a durable ledger row, and links evidence — the
-- additive layer, same as palm6_citations vs the recipe's paperless BillPlayer.
--
-- NOT palm6_counterfeit. `counterfeit_cash` (fake money) is seized by
-- palm6_counterfeit's own /seizefake ledger — this resource never touches it.
-- Scope here is strictly `black_money` (real dirty money).
-- ============================================================================
Config = {}

Config.Debug = false

Config.DirtyItem = 'black_money'   -- the only thing this resource forfeits

-- How close the officer must be to the suspect to forfeit (server-measured
-- against the suspect's real ped position).
Config.SeizeRadius = 3.0

-- Probable cause: only a WANTED suspect (active palm6_mdt warrant) can have
-- their dirty money forfeited. Ties seizure to the crime→warrant system and
-- stops officers shaking down innocent/RP-clean players. If palm6_mdt is
-- offline HasActiveWarrant is false, so seizure simply can't fire — intended.
Config.RequireWarrant = true

-- Forfeited dirty money is DESTROYED (booked into evidence / state forfeiture),
-- NOT handed to the officer — so police can't farm dirty money by seizing it.
-- (Left as a documented constant in case a future society-account payout is
-- wanted; keep false to avoid the corruption vector.)
Config.PayOfficer = false

-- /seizedirty and /seizures are chat commands, not net events — eventguard
-- doesn't cover them; the per-officer cooldown + per-suspect lock are the guard.
Config.CooldownSec = 3             -- per-officer, between /seizedirty attempts

Config.Evidence = {
    IncidentKeyPrefix = 'forfeiture:',
    CaseTitle         = 'Asset forfeiture — dirty money',
}
