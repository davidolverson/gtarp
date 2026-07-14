# palm6_numbers

The neighbourhood numbers racket. Stake clean cash on a number, win dirty.

You pick a two-digit number (00-99) and stake **clean cash** with a back-alley
bookie. Every draw interval the house pulls a winning number; hits are marked
won at a fixed multiple of their stake and paid out as **`black_money`** —
dirty money you then have to run through `palm6_laundering` before it spends
clean. The payout multiple sits below true odds (a house edge), so the stake
pool is a **net money sink**, never a printer.

## Commands

- **`/numbers <0-99> <stake>`** — place a slip at the bookie. Clean cash is
  taken immediately; the slip resolves at the next draw. Per-character cooldown
  and a per-draw slip cap.
- **`/collectnumbers`** — at the bookie, collect any winnings you've hit
  (delivered as `black_money`). Works even if you were offline at draw time.
- **`/numbersinfo`** — countdown to the next draw, your open slips, dirty
  winnings waiting to be collected, and the last winning number.

## What makes it 1-of-1 (and not a dupe)

- **Nothing else is a lottery.** Dup-gated against the real deployed recipe
  (no `qbx_casino`, no gambling/lottery/betting resource ships at all) and
  every `palm6_*` resource.
- **Distinct from `palm6_fightclub`.** Fightclub is *parimutuel* wagering on a
  live PvP fight's outcome (bettors split a pool by picking the real winner).
  This is a *fixed-odds* random draw against a staked number (house picks a
  number, pays a set multiple). Different mechanic, kept in its own lane.
- **Feeds the dirty-money economy.** Winnings pay in `black_money` (same item
  `qbx_bankrobbery` drops and `palm6_laundering` washes) — so a jackpot is a
  new *source* of dirty money that flows into the laundering sink. Never
  `counterfeit_cash` (that's `palm6_counterfeit`'s fake-money lane) and never
  `markedbills` (not a registered item on this server).

## Money honesty / balance

100 outcomes, `PayoutMultiple` = 60 → expected return **$0.60 per staked
dollar** (a ~40% house edge, a realistic numbers-game margin). The stake is the
sink; wins are strictly < true odds so the racket bleeds money over time.
`PayoutMultiple` must stay below `MaxNumber + 1` or the game turns +EV (a
printer) — the config says so out loud.

## Anti-abuse (all server-side)

- Number, stake, and position are validated/read server-side; the client sends
  nothing but the command. Stake is pulled with an **atomic** `RemoveMoney`
  (fails and removes nothing if you can't cover it); if the slip write then
  fails the stake is refunded.
- The bet cooldown is set **before** any DB yield (the `palm6_chopshop` rl()
  idiom) so two same-tick slips can't both bypass it.
- Collect is serialized by a per-character in-flight lock and marks **exactly
  the winning rows it summed** (guarded on `paid=0`), so a win the draw lands
  mid-collect can't be flipped paid without being paid, and no payout is ever
  double-claimed. If delivery fails the rows are restored.
- The draw resolves each bet with a guarded `UPDATE ... WHERE status='open'`,
  and survives restarts by resuming after the last resolved sequence (never
  behind an existing open bet's sequence).
- Chat commands aren't net events, so eventguard doesn't cover them — the
  cooldown, per-draw cap, and claim lock are the guard.

## Data

`palm6_numbers_bets` (one row per slip: number, stake, draw_seq, status,
payout, paid) and `palm6_numbers_draws` (one row per resolved draw: winning
number + volume). `sql/0034_numbers.sql`. Export `GetSummary()` returns
`{ draws, totalStaked, totalPaid, openDrawSeq }`.

## Tuning (`shared/config.lua`)

`PayoutMultiple`, `MaxNumber`, `MinStake`/`MaxStake`, `MaxBetsPerDraw`,
`BetCooldownSec`, `DrawIntervalSec`, and `Config.Bookie.coords` (a Tier-3 Los
Santos placeholder — verify the bookie spot in-game).
