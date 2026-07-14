# palm6_onboarding

New-player onboarding: mandatory rules acceptance + a short starter tour on
a citizen's first-ever character load, plus a one-time starter cash grant.

## Why this exists

The custom layer had zero onboarding before this: `server_base`'s
`Config.Welcome` is a single one-line toast shown on *every* load, and
nothing tracked whether a player had ever actually seen or agreed to the
rules. That's a real gap for a launch-imminent server — this resource
closes it without touching `server_base`.

## Flow

1. First character load ever (tracked per-citizenid in `palm6_onboarding`,
   `UNIQUE(citizenid)`): server pushes a mandatory rules dialog to the
   client. There is no decline/cancel button — the only way to close it is
   to acknowledge it.
2. Client reports the acknowledgement back. Server re-derives everything
   from its own state (`UNIQUE(citizenid)` guards the actual grant — the
   client event is never trusted as proof by itself, only as a trigger).
3. First (and only first) successful accept: grants `Config.StarterCash`
   to the citizen's bank, logs `onboarding_rules_accepted` to
   `palm6_staff`'s audit log (queryable for ban/dispute conversations),
   then shows a short tour panel pointing at what this server actually
   has (bank, jobs, `/rules`, MDT for cops).
4. Every later load is a no-op — the DB row already exists.

## Commands

- `/rules` — anyone, anytime. Re-shows the rules text read-only. Does not
  touch the DB and never re-triggers the accept/grant flow.

## Exports

- `GetSummary()` → `{ totalAccepted: number }` — total onboarded citizens,
  all-time. Consumed by `palm6_devtest`.

## Security notes

- Starter-cash grant is guarded by `UNIQUE(citizenid)` on the underlying
  `INSERT`, not by any client-side "first time" flag — a race between two
  near-simultaneous accept events (or a replayed event from a modified
  client) can only ever land the row once; the loser's `INSERT` throws and
  is treated as "already onboarded," granting nothing.
- The accept net event is rate-limited (`Config.AcceptCooldownSec`) as a
  spam guard, independent of the uniqueness guard above.

## GTA VI portability

Tier 2 — bridge rewrite only. `bridge/sv_framework.lua` wraps
`QBCore:Server:OnPlayerLoaded`, `AddMoney`, and citizen-id lookup;
`bridge/cl_game.lua` wraps `QBCore:Client:OnPlayerLoaded` and the
`ox_lib` mandatory-dialog/notify calls. `Config.Rules`/`Config.Tour` text
and `Config.StarterCash` are Tier 1 — pure data, no coords or models.
