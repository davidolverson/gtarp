# palm6_fightclub — the underground ring

Two citizens meet at the ring, one challenges the other, the challenged
fighter accepts, and the crowd bets cash on who walks out. Bare knuckles
only — the fight is unarmed, server-monitored, and ends in a real knockout,
a forfeit, or a timeout draw. Payouts are a **parimutuel pool**: every
spectator wager on both fighters is pooled, the house skims a rake, the
winner gets a purse cut straight off the top, and whatever's left splits
proportionally among everyone who bet on the winner.

**Architecture note (Def Jam Fight Club, Phase 0):** the match *lifecycle*
(challenge → select → betting → live → resolved) and all combat now live in
`palm6_fc_combat` / `palm6_fc_core`. This resource is the **money authority
only** — it exposes guarded exports (`OpenMatch`/`GoLive`/`ResolveMatch`/
`VoidMatch`/`LiveVoidMatch`) that open/advance/resolve a match row and runs
the recoverable, idempotent settlement (spectator pool + two-fighter entry
pot). There is no queue and no server-swept combat here anymore.

## Player surface

This resource's own player surface is spectator betting (server-only, no
NUI/client script). Fighters challenge/accept and pick a style through
`palm6_fc_combat`'s client prompts — not through this resource.

- `/fcbet [match #] [1 or 2] [$50-5000]` — spectator wager on fighter 1 or
  2. Fighters cannot bet on their own match. One bet per citizen per match.
- `/fcmatches` — the open board: betting windows (with time left) and live
  fights.

A match opens when a fighter challenges another at the ring and the target
accepts (via `palm6_fc_combat`). Both fighters ante the entry stake, a
betting window opens for `Config.Betting.WindowSec` (60s), and when it
closes the fight goes live under `palm6_fc_combat`'s server-authoritative
combat. Leaving the ring, drawing a weapon, or disconnecting is an instant
forfeit; no knockout inside the round cap is a draw. A pre-live abort
(disconnect during betting/countdown) is a no-contest — every bet and both
antes are refunded, nobody is paid.

## Why this can't be gamed from the client

- **Every fight-ending condition is server-derived.** HP, stamina, position,
  and the finisher are all server-owned per-match state in `palm6_fc_combat`
  (never ped health, never client-trusted). A modified client claiming "I
  won" or "I landed" changes nothing; the server validates every strike's
  window, reach, and block before applying authoritative damage.
- **Betting is a database-enforced atomic claim, not a Lua check.** The bet
  insert is `INSERT ... SELECT ... FROM palm6_fightclub_matches WHERE id=?
  AND status='betting'` — the row only lands if the match was still taking
  bets at the exact instant of insert, no read-then-write gap for a closing
  window to slip through. The `UNIQUE(match_id, citizenid)` key on
  `palm6_fightclub_bets` is what actually stops a citizen double-betting a
  match: it's a schema constraint, not an in-memory table, so two racing
  `/fcbet` commands from the same player can't both land the way
  `palm6_pumpcoin`'s ticker-uniqueness bug let two racing mints both pass a
  stale in-memory check before either insert had landed. Here the second
  insert just fails the constraint — caught and reported as "you already
  have a bet," no double charge possible.
- **Resolution is a guarded `UPDATE ... WHERE status='live'`** before any
  money moves, so a match can only be paid out once even if the resolver
  somehow fired twice in the same tick.
- **Fighters can't bet on themselves** — checked against both fighters'
  citizenids at bet time. (A fighter colluding with an *alt* to bet against
  themselves and intentionally throw the fight is an accepted economic/
  social risk in any wagering system, same category `palm6_bounty`
  documents for escrow self-dealing — not a security bug.)
- **Money only moves after the claim is safe.** A bet's row is inserted
  before the bank charge; if the charge fails the row is deleted
  immediately so no phantom, unpaid bet ever pollutes the pool math.

## Design notes

- Bridge-pattern (see `docs/GTA6-READINESS.md`): all logic is in
  `server/`; every qbx/native call lives in `bridge/sv_framework.lua`. No
  client script at all — matching `palm6_citations`/`palm6_mdt`/
  `palm6_bounty`'s "nothing for a modified client to abuse" precedent.
- Payouts credit by citizenid, online or offline (the
  `palm6_bounty`/`palm6_pumpcoin`/`palm6_insurance` pattern), so a bettor
  who logs off between placing a wager and the match resolving still gets
  paid.
- Parimutuel math: `rake = pool * RakePct`, `purse = pool * WinnerPursePct`
  paid straight to the winning fighter, and the remainder splits among
  winning bettors proportional to their stake, rounded down per bettor.
  Losing-side bets and rounding remainder are the sink — the same "buys
  round up, payouts round down" honesty `palm6_pumpcoin` documents. If
  nobody bet on the winning side, that remainder simply isn't paid to
  anyone (no winning bettors to pay).
- A no-contest (a disconnect during betting/countdown, or a timeout with no
  knockout) is a full refund to every bettor and both antes — no rake, no
  purse. A live disconnect / ring-out is a forfeit: the opponent is paid.
- Open matches (`betting`/`live` rows) survive a resource/server restart:
  `palm6_fc_combat` no-contests any stranded row at its boot, and this
  resource's boot reconcile re-drives any interrupted payout with no
  double-pay. There is no in-memory queue to lose.
- Exports: `GetSummary() -> { openMatches }`.
- `Config.Ring.coords` is a Tier-3 placeholder (see
  `docs/GTA6-READINESS.md` §2) — retune once a real MLO/prop is picked.

## Dup-gate (2026-07-08)

Checked against every documented recipe resource name collected across
this repo's own dup-gate paper trail (`docs/BUILD-ROADMAP.md`,
`docs/GTA6-READINESS.md`, and the "why this doesn't duplicate X" sections
of `palm6_bounty`, `palm6_counterfeit`, `palm6_robbery`, `palm6_turf`,
`palm6_legal`, `palm6_mdt`, `palm6_witnesses`, `palm6_pumpcoin` — the
recipe itself isn't vendored in this git repo, so those README trails are
the only queryable record of its resource surface): `qbx_police`,
`qbx_ambulancejob`, `qbx_management`, `qbx_pawnshop`, `qbx_scrapyard`,
`qbx_customs`, `qbx_streetraces`, `qbx_lapraces`, `qbx_drugs`, `qbx_weed`,
`qbx_houserobbery`, `qbx_truckrobbery`, `qbx_storerobbery`,
`qbx_bankrobbery`, `qbx_garages`, `qbx_vehicles`, `qbx_properties`,
`qbx_smallresources`, `qbx_truckerjob`, `qbx_taxi`, `qbx_garbagejob`. None
of them are a combat mechanic, a wagering/gambling system, or a spectator
economy of any kind — `qbx_streetraces`/`qbx_lapraces` are vehicle races
with no documented betting layer, and `qbx_police` has cuff/jail/MDT
plumbing but (per `palm6_bounty`'s own dup-gate) "no reward-for-capture
loop," let alone a PvP wagering one.

`grep -riE "\bbet\b|wager|duel|fight.?club|gambl|casino"` across every
`docs/*.md` and every `resources/[custom]/palm6_*/README.md` in this repo
returns nothing before this resource's own files — no existing custom
resource does spectator wagering, consensual PvP dueling, or any kind of
gambling/casino mechanic. The two closest neighbors are genuinely
different domains: `palm6_bounty` is asymmetric hunt-and-capture with
escrowed contracts on a specific citizen (not a scheduled, consensual,
two-sided duel with pool betting), and `palm6_turf` is zone capture
between gangs (not player-vs-player combat at all). `palm6_pumpcoin` is
the closest *mechanical* cousin — both are server-side pooled-economy
games with a house rake — but it's asset speculation on a bonding curve,
not wagering on a live combat outcome, and shares no code or tables with
this resource.

This is also **not** a repeat of the two documented near-misses
(`civilian_runs`, the early housing system) that got reverted for
skimming override configs instead of reading real recipe surface: this
dup-gate is against the *feature category* (combat wagering / gambling),
which the aggregated evidence above shows has zero footprint anywhere in
the recipe's documented surface, not just an absence of a
similarly-named config file.

## Install

1. `ensure palm6_fightclub` in `custom.cfg` (after `qbx_core`, `ox_lib`,
   `oxmysql`).
2. Apply `sql/0028_fightclub.sql` — creates `palm6_fightclub_matches`,
   `palm6_fightclub_bets`.
3. Tune `shared/config.lua` (at minimum, check `Config.Ring.coords` fits
   your map edits before launch).

No external APIs, no keys, no custom assets — config coordinates only.

## Deferred to v2

- Spectator betting is chat-command only (`/fcbet` / `/fcmatches`); the
  live board/HUD is `palm6_fc_hud`.
- No admin cancel command for a stuck match (the round cap + ring-out /
  disconnect forfeits always resolve a live match, and a betting/countdown
  strand is no-contested at boot, so nothing hangs forever — but there's no
  manual override yet).
- Single global ring; no per-location rings.
