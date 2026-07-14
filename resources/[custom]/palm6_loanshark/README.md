# palm6_loanshark

Credit for criminals — and the drama of stiffing it.

Borrow **dirty cash** (`black_money`) from a back-alley shark up to a cap; owe
principal plus flat interest by a deadline; repay in **clean bank money** at the
shark. Miss the deadline and you **default** — the shark puts a warrant on you
(`palm6_mdt`), which `palm6_bounty` then auto-posts as a hunting contract. The
real play isn't the loan economics (borrowing dirty to repay clean at interest
is a deliberately steep sink); it's the leverage: instant dirty liquidity now,
or take the money and run and become a wanted target.

## Commands

- **`/borrow <amount>`** — at the shark, take a loan (paid in `black_money`).
  One open loan at a time; you can't borrow while you already owe or while
  you're wanted.
- **`/repay <amount|all>`** — at the shark, pay down your debt from your bank.
- **`/loaninfo`** — your outstanding debt and the countdown to default.

## What makes it 1-of-1 (and not a dupe)

- **No loan/credit system exists** anywhere. Dup-gated against the real deployed
  recipe (Renewed-Banking has no loan module; there's no `qbx_banking`) and
  every `palm6_*` resource.
- **Composes through existing exports, no upstream change.** Default routes
  through `palm6_mdt:IssueWarrant(cid, reason, 'Loan Shark')`; `palm6_bounty`'s
  state sweep already auto-posts a contract on any active MDT warrant, so a
  defaulter becomes a bounty target with no direct bounty call. `palm6_mdt` is
  a **soft dependency** — absent, loans still work, they just don't escalate to
  warrants.
- **Feeds the dirty-money economy.** Principal is handed over as `black_money`
  (needs `palm6_laundering` to spend clean, or spends directly at the recipe's
  BlackMarketArms). Never `counterfeit_cash` (palm6_counterfeit's lane), never
  the unregistered `markedbills`.
- **Respects the city invariant.** A defaulted debt is settled with the *law*
  (a booking clears the warrant), not by paying the shark — the same
  "only a booking clears a warrant" rule `palm6_citations`/`bounty`/`ransom`
  establish. You can't `/repay` a defaulted loan.

## Anti-abuse (all server-side)

- Amount and position are validated/read server-side; the client sends nothing
  but the command. One open loan per citizen (re-checked under a per-citizen
  borrow lock); no borrowing while `HasActiveWarrant`.
- **Borrow** inserts the loan first, then hands over the dirty principal, and
  **deletes the loan if the hand-over fails** — you never owe for cash you
  didn't get.
- **Repay** takes the clean payment then applies it with a guarded
  `UPDATE ... WHERE status='open'`; if the default sweep flipped the loan in the
  same window, the payment is **refunded** rather than lost.
- The **default sweep** transitions overdue loans with the same guarded
  `WHERE status='open'`, so a repay-settle and a default can't both apply to one
  loan — whichever flips 'open' first wins.
- Per-character command cooldown; per-citizen borrow/repay locks. Chat commands
  aren't net events, so eventguard doesn't cover them — these are the guard.

## Data

`palm6_loanshark_loans` (`sql/0036_loanshark.sql`) — one row per loan:
principal, owed, repaid, status (open/repaid/defaulted), warrant_id, due_at.
Export `GetSummary()` → `{ open, repaid, defaulted, lentTotal }`.

## Tuning (`shared/config.lua`)

`MinPrincipal`/`MaxPrincipal`, `InterestBps`, `TermSec`, `DefaultSweepSec`,
`CooldownSec`, and `Config.Shark.coords` (a Tier-3 Los Santos placeholder —
verify the shark's spot in-game).
