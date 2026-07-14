# palm6_bounty — the wanted board

A cash bounty economy layered on the city's existing law-and-order systems.
The city auto-posts a **state contract** on every citizen carrying an
active `palm6_mdt` warrant — funded from nothing, scaled by warrant count,
kept in sync every sweep. Any citizen can also post a **private contract**
on another citizen, cash escrowed from their bank up front. Either way, a
hunter doesn't collect by walking up: the target has to actually be beaten
down (server-read health) and the hunter has to be standing right on top of
them when they claim it.

## Player surface

All chat commands (server-only resource, no NUI/client script):

- `/postbounty [citizenid] [$100-10000] [reason]` — post a private
  contract. Requires standing at the Bounty Board (Alta St, near the
  bail-bonds strip); escrows the amount from your bank immediately. Max 3
  open contracts per citizen, 30s cooldown between posts.
- `/cancelbounty [contract #]` — cancel your own unclaimed contract; 90%
  refund (10% posting fee kept — discourages post/cancel spam).
- `/bounties` — the open board, highest reward first, state and private
  mixed together.
- `/capture [contract #]` — claim it. Server checks: you're within 3m of
  the target, their health is at/under the "beaten down" threshold (120 on
  GTA's 100-200 ped health scale — ~20% effective HP left), the contract is
  still active, and you aren't the poster or the target. 10s cooldown per
  hunter.

Unclaimed private contracts auto-expire after 24h (full refund, no fee).
State contracts have no TTL — they live and die with the underlying
warrant: cleared/served with no capture just quietly closes, no money
involved either way.

**Capturing a state contract does not itself clear the warrant.** This
resource only reads `palm6_mdt_warrants`; it never calls `SealBooking` or
touches the warrant row. Paying out is the cash-bounty resolution — the
target still has to be walked to a cop and booked for the underlying
warrant to actually clear (same "paying doesn't lift the warrant"
separation `palm6_citations` documents for fine payment vs. warrant
service).

## Why this can't be gamed from the client

- **Both halves of a claim are server-derived.** Proximity is a server-side
  `GetEntityCoords` diff between the hunter's and target's live peds;
  "beaten down" is a server-side `GetEntityHealth` read on the target's
  synced ped. Nothing about who's near whom or how hurt they are comes from
  the client.
- **The claim UPDATE is the race guard.** `UPDATE ... SET status='claimed'
  WHERE id=? AND status='active'` — exactly one of two hunters racing the
  same contract gets `affected_rows = 1` and gets paid; the loser sees
  "someone beat you to that contract," not a duplicate payout.
- **Self-dealing is blocked at the obvious seams**: you can't post a
  contract on yourself, can't claim your own posted contract, and can't
  claim a bounty on your own head. (A poster colluding with an *alt* or a
  friend to recycle their own escrow back is an accepted economic risk in
  any bounty system — same category as insurance fraud being flagged-but-
  paid, not a security bug.)
- **Cancel/refund is guarded the same way insurance's claim sweep is**:
  status flips before money moves, so a crash mid-payout leaves a visible,
  fixable row instead of a silent double-pay.

## State contracts — read-only cross-read of `palm6_mdt`

Every sweep (`Config.State.SweepSec`, default 180s) runs `SELECT citizenid,
citizen_name, COUNT(*) FROM palm6_mdt_warrants WHERE status='active' GROUP
BY citizenid, citizen_name` and upserts one state contract per warrant
holder (`BaseAmount` + `PerWarrantExtra` per warrant beyond the first,
capped at `Cap`). This resource **never writes** to `palm6_mdt`'s tables —
same read-only cross-resource pattern `palm6_pumpcoin`, `palm6_clout`, and
`palm6_flashdrop` already use to read `palm6_turf`. If `palm6_mdt` isn't
running, state contracts simply stop posting/syncing (`Config.
State.RequireMdt`); private contracts are unaffected.

## Design notes

- Bridge-pattern (see `docs/GTA6-READINESS.md`): all logic is in
  `server/`; every qbx/native call lives in `bridge/sv_framework.lua`. No
  client script — every command is server-validated chat, matching
  `palm6_citations`/`palm6_mdt`.
- Payouts credit by citizenid, online or offline (the `palm6_insurance`/
  `palm6_pumpcoin` pattern) so a hunter who logs off between the claim and
  the credit still gets paid.
- Deliberately does **not** notify a target the moment a bounty is posted —
  the board is public (`/bounties`), but there's no instant "you've been
  bountied" ping. The only notify a target gets is after the fact, when
  someone actually collects.
- Exports: `GetSummary() -> { activeContracts, totalAmount }`.
- `Config.Board.coords` is a Tier-3 placeholder (see
  `docs/GTA6-READINESS.md` §2) — retune once a real MLO/prop is picked.

## Dup-gate (2026-07-08)

`grep -riE "bounty|contract kill|hitman|smuggl"` across the deployed
recipe's entire `[qbx]` tree (43 resources incl. `qbx_police`,
`qbx_management`, `qbx_pawnshop`, `qbx_scrapyard`, `qbx_streetraces`,
`qbx_lapraces`, `qbx_drugs`, `qbx_weed`, `qbx_customs`,
`qbx_houserobbery`/`qbx_truckrobbery`/`qbx_storerobbery`/
`qbx_bankrobbery`) returns nothing — no bounty, wanted-poster, or contract
system anywhere in the recipe. `qbx_pawnshop` fences jewelry/electronics
(melts stolen chains into gold bars), not a person-hunting mechanic.
`qbx_police` has cuff/jail/MDT plumbing but no reward-for-capture loop.
Same grep across every `resources/[custom]/palm6_*` README/server file in
this repo also returns nothing — the closest existing systems are
`palm6_mdt` (warrants are paperwork, no reward), `palm6_turf` (gang zone
control, not person-targeted), and `palm6_citations` (debt collection, no
capture mechanic). This resource is the first thing in either tree that
puts a cash reward on a specific citizen and pays out for physically
catching them.
