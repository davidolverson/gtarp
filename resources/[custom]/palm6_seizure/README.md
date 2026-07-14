# palm6_seizure

The law's counter-lever on the dirty-money economy.

Every crime resource on this server pays out **dirty** (`black_money`): bank
robbery, `palm6_numbers` winnings, `palm6_protection` shakedowns,
`palm6_loanshark` principal — all of it flowing toward `palm6_laundering`'s
wash. Nothing let police **interdict** it. `palm6_seizure` is that: an on-duty
officer standing over a **wanted** suspect can forfeit the suspect's dirty
money. It's removed from circulation, written to a persistent forfeiture ledger,
and attached to a `palm6_evidence` case.

## Commands

- **`/seizedirty`** — on-duty police only. Forfeits the dirty money of the
  nearest wanted suspect (within ~3 m). The money is **destroyed** (booked to
  the state / evidence), never paid to the officer.
- **`/seizures`** — on-duty police: forfeiture totals (all-time + last 24 h).

## What makes it 1-of-1 (and not a dupe)

- **Not qbx_police `/seizecash`.** That grabs a suspect's **clean `cash`**
  account into a `moneybag` item, records nothing, and never touches
  `black_money`. There's no `/seizeitem` at all. This touches **only**
  `black_money`, writes a durable ledger row, and links evidence — the additive
  layer, exactly like `palm6_citations` vs the recipe's paperless BillPlayer.
- **Not `palm6_counterfeit`.** `counterfeit_cash` (fake money) is seized by
  `palm6_counterfeit`'s own `/seizefake` ledger. This scopes strictly to
  `black_money` (real dirty money) and never touches counterfeit cash.
- **Closes the interdiction gap** in the dirty-money loop — the first thing that
  gives police an economic move against laundering.

## Anti-abuse (all server-side)

- **On-duty police** gate (`PlayerData.job` read server-side). The target is the
  nearest player, chosen server-side — the client sends no target id or
  coordinate. (Note: like every FiveM proximity check, the ped positions the
  server compares are client-synced under OneSync, so a position-spoofing cheat
  on an *already-police* account could stand "next to" an *already-wanted*
  suspect from afar; the on-duty + active-warrant gates bound that.)
- **Probable cause:** only a suspect with an active `palm6_mdt` warrant can be
  seized from (`Config.RequireWarrant`), tying forfeiture to the crime→warrant
  system and preventing shakedowns of clean players. If `palm6_mdt` is offline,
  `HasActiveWarrant` is false and seizure simply can't fire.
- **No corruption vector:** forfeited money is destroyed, not credited to the
  officer (`Config.PayOfficer = false`), so police can't farm dirty money.
- **Race-safe:** per-officer command cooldown (set before the first yield) and a
  per-suspect in-flight lock, so two officers can't double-seize one suspect;
  the exact held amount is removed and only what ox confirms is logged.

## Data

`palm6_seizure_forfeitures` (`sql/0037_seizure.sql`) — one row per forfeiture:
officer, suspect, amount, evidence_case_id. Export `GetSummary()` →
`{ seizures, totalForfeited }`.

## Tuning (`shared/config.lua`)

`SeizeRadius`, `RequireWarrant`, `PayOfficer` (keep false), `CooldownSec`.
