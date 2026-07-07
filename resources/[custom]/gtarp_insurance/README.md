# gtarp_insurance — Mors Mutual vehicle policies with forensic fraud detection

Vehicle insurance whose claim pipeline reads the city's own forensics.
Every input the payout math trusts is server-read: ownership from
`player_vehicles`, damage from the synced entity's live health, theft from
state-plus-absence, and the fraud score from `gtarp_replay`'s black-box
scenes. A damage claim with no corresponding incident scene near the
vehicle is exactly as suspicious as it sounds.

Flagged claims **still pay** (48-slot trust server) — they open a
`gtarp_evidence` case for police to work in RP. Insurance fraud is a story
hook, not a mechanical denial. Case creation lands on the police Discord
feed automatically when `gtarp_discord` is configured.

## Player surface

All at the Mors Mutual desk (Little Seoul, map blip):

- `/insure [plate]` — underwrite a vehicle you own. One-time premium (5% of
  catalog value), 60% coverage, 10% deductible, 72h term.
- `/fileclaim [plate] [damage|theft]` — damage claims need the vehicle
  present and ≥25% assessed damage (≥85% upgrades to total loss); theft
  claims need the city's records to say it's out AND it must be nowhere in
  the synced world. Payout lands in bank after ~10 minutes.
- `/policy` — active policies and processing claims.

## Fraud signals (server-derived, summed; ≥50 flags)

| Signal | Score |
|---|---|
| Policy under 60 min old at filing | 30 |
| Each prior claim in 48h | 20 |
| No replay scene near vehicle in last 45 min (damage only, and only when gtarp_replay is running) | 35 |
| Claim maxes the coverage cap | 15 |

## Design notes

- Deliberately **no client-trusted net events** — both commands act
  entirely on server-side reads; the client script is a map blip.
- Payout sweep marks a claim resolved BEFORE crediting: the cheap failure
  (visible unpaid row) is the recoverable one, a double payout isn't.
- Payouts credit by citizenid, online or offline (pumpcoin's pattern).
- Soft dependencies: gtarp_replay missing → no-scene signal disabled
  (absence of the black box is not evidence of fraud); gtarp_evidence
  missing → flagged claims still pay, just no case file.
- Exports: `GetSummary() -> { activePolicies, pendingClaims }`.

## Dup-gate (2026-07-06)

No insurance functionality anywhere in the deployed recipe tree (`grep -riE
"insurance|claim"` over `[qbx]`/`[ox]`/`[standalone]` — only unrelated hits:
admin reports, ox_lib grid cells, tattoo names). qbx_garages' depot fee is
an impound charge, not a policy/claim system. The replay-forensics fraud
loop exists nowhere on Tebex — it can't, it needs gtarp_replay.
