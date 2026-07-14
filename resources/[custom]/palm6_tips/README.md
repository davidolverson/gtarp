# palm6_tips — anonymous payphone tips

Snitching as a scene. `/tip [what you saw]` works only within reach of
a real payphone — the tip lands on the police 911 log (`palm6_mdt`
`/calls`) with **no identity attached**, tagged `[TIP]` and carrying
the payphone's location, not yours. The cost of anonymity is physical:
you have to walk to the phone, and anyone watching the street sees you
make the call.

## Design notes

- **Server-only** — no client script, no net events. The payphone check
  is a server-side position read against a configured coordinate list
  (8 starter phones; tune to your map).
- **Genuinely anonymous**: the tipper's citizenid is used for an
  in-memory cooldown only (one tip per citizen per 5 min) and is never
  written anywhere. Wipe-proof by design — there is nothing to leak.
- Tips land via `palm6_mdt`'s additive `LogCall` export — this resource
  touches no tables at all and needs no SQL migration.
- On-duty officers get a soft "a tip just came in" notify
  (configurable off).
- Exports: `GetSummary() -> { payphones }`.

## Dup-gate (2026-07-07)

No payphone, tip-line, or anonymous-report system anywhere in the
deployed `[qbx]`/`[ox]`/`[standalone]` tree (the only grep hit is a
locale file's unrelated word). The recipe's `police:server:policeAlert`
funnel is automated crime detection — there is no player-authored
report path at all.
