# gtarp_ransom — kidnapping ransom ledger

Hangs an economy and a felony paper trail off the recipe's own "Kidnap"/
"Take Hostage" mechanic (`qbx_police`/`qbx_radialmenu`: drag a restrained
citizen into a vehicle trunk). That mechanic is pure animation on its own —
nothing tracks it, monetizes it, or logs it. This resource does not
reimplement the restrain/trunk mechanic; it listens to the recipe's own
`police:server:KidnapPlayer` net event, re-validates it server-side, and
turns a real kidnapping into a ransom case with a paper trail that flows
into `gtarp_evidence` and `gtarp_mdt`.

## Player surface

All chat commands (server-only resource, no NUI/client script):

- `/demandransom [$250-15000] [instructions]` — only works within 10
  minutes of this same character being server-verified to have kidnapped
  someone (see "why this can't be gamed" below). One active ransom per
  victim.
- `/payransom [case #]` — pay a ransom in full. Requires standing at the
  drop point downtown. Cash moves straight from the payer's bank to the
  kidnapper's — anyone can pay, not just the victim.

Unpaid ransoms auto-expire after 20 minutes (`Config.Ransom.TimeoutMinutes`)
— no refund is owed (nobody paid), but the kidnapping is still a felony
either way.

**Every case closes into an `gtarp_mdt` warrant, paid or not.** Paying the
ransom buys the victim's release, not the kidnapper's freedom — same
"paying doesn't clear the underlying charge" separation `gtarp_citations`
(fine payment doesn't lift a warrant) and `gtarp_bounty` (capture doesn't
clear the warrant) already establish for this city.

## Why this can't be gamed from the client

`police:server:KidnapPlayer` is a net event the recipe's own `qbx_police`
already registers a handler on. Registering a second handler here (this
resource) does **not** run "after" or "gated by" that first handler —
FiveM fires every registered handler on an event independently, so a
modified client could `TriggerServerEvent` this event directly with a
fabricated victim id and skip the recipe's own checks entirely. This
resource re-derives the whole thing itself before it ever records a
kidnapping:

- Both the alleged kidnapper's and victim's citizenids are re-resolved
  server-side (`Bridge.GetCitizenId`) — not trusted from event params.
- The victim's restrained state (`ishandcuffed`/`isdead`/`inlaststand`) is
  re-read server-side (`Bridge.IsRestrained`) — the same gate the recipe's
  own handler checks, independently re-verified here.
- Proximity between kidnapper and victim is a server-side
  `GetEntityCoords` diff, not a client claim.

Only once all three pass does the pairing get recorded (in-memory, 10-
minute window) as something `/demandransom` is allowed to act on.

Paying is guarded the same way `gtarp_bounty`'s capture and
`gtarp_pumpcoin`'s mint are: `UPDATE ... SET status='paid' WHERE
id=? AND status='active'` — a race between two payers, or a payer and the
expiry sweep, can only land once. A lost race refunds the payer in full,
never silently drops their money.

## Design notes

- Bridge-pattern (see `docs/GTA6-READINESS.md`): all logic is in
  `server/`; every qbx/native call lives in `bridge/sv_framework.lua`. No
  client script — matches the `gtarp_bounty`/`gtarp_mdt`/`gtarp_citations`
  server-only precedent (every command is server-validated chat; there is
  nothing for a client script to do and therefore nothing for a modified
  client to abuse).
- `gtarp_evidence` integration uses only the frozen four exports
  (`EnsureCase`/`AppendEntry`/`LinkSuspect`/`GetCase`) — never touches its
  tables directly.
- `gtarp_mdt` integration uses only its additive `IssueWarrant` export
  (the same call `gtarp_citations`' overdue-fine escalation uses) — never
  touches its tables directly. `IssueWarrant` posts its own police-feed /
  Discord announcement internally; this resource does not duplicate that.
- Payouts credit by citizenid, online or offline (the `gtarp_bounty`/
  `gtarp_insurance`/`gtarp_pumpcoin` pattern).
- `Config.DropPoint.coords` is a Tier-3 placeholder (see
  `docs/GTA6-READINESS.md` §2) — retune once a real MLO/prop is picked.
- Exports: `GetSummary() -> { activeCases, totalDemanded }`.

## Known limitation

There is no reliable exported "release the victim" hook in the recipe's
kidnap/trunk flow (`qb-trunk`'s `isKidnapping`/`isKidnapped` are private
client-side locals, not events this resource can safely trigger without
guessing at undocumented internal state). Paying a ransom resolves the
case and notifies both parties, but does not force-release the victim from
the trunk/restrained state — that still needs an in-RP action (the
kidnapper letting them go, or police intervention). Documented rather than
worked around, same style as `gtarp_mdt`'s known truckrobbery/cam-command
alert-funnel gap.

## Dup-gate (2026-07-08)

`grep -riE "kidnap|hostage|ransom"` across both `resources/[custom]` (every
existing `gtarp_*` resource) and the deployed recipe's full `[qbx]` tree
returns hits only in `qbx_police/client/interactions.lua`
(`police:client:KidnapPlayer`, `police:client:TakeHostage`) and
`qbx_radialmenu/client+server/trunk.lua` (`qb-trunk:...:KidnapTrunk`) — the
recipe's raw physical restrain/trunk mechanic, confirmed to carry zero
economic or legal consequence (nothing in either file touches money, a
database, or a case file). No existing `gtarp_*` resource does ransom or
hostage-economy logic. Same shape as the gap `gtarp_mdt` closed for the
recipe's inert `mdt_tablet` item and unimplemented `qbx_police_overrides`
`GetMDT()` contract: the recipe owns the physical verb, the custom layer
owns the paper trail and the economy.
