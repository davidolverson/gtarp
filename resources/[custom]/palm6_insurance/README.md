# palm6_insurance — Mors Mutual vehicle policies (agent NPC, plan tiers, forensic fraud)

Vehicle insurance whose claim pipeline reads the city's own forensics. Every
input the payout math trusts is server-read: ownership from `player_vehicles`,
damage from the synced entity's live health, theft from state-plus-absence, and
the fraud score from `palm6_replay`'s black-box scenes.

**What you're really buying is protection against LOSING the car.** Theft and
total-loss (the car is gone) pay the full plan coverage. A repairable-damage
claim (you keep the car) pays a modest **repair subsidy**, deliberately capped
below the premium you paid, so a real accident is softened but "wreck your own
car and claim" is always net-negative — no reliance on the fraud path to hold.

## The agent

A Mors Mutual **agent NPC** stands at the desk (Little Seoul, map blip). Talk to
it (ox_target eye, or an E-prompt if ox_target is absent) for a menu:

- **Buy a policy** — quotes all three tiers for the car you drove up in; pick one.
- **File a claim** — pick one of your insured plates, then damage or theft.
- **My policies & claims** — active cover + pending payouts.

The menu is presentation only: every option fires a server event that re-runs
all authority (rate limit, at-desk, ownership, and — on buy — a full underwrite
that recomputes the premium from the chosen tier). A modified client can only
choose *which* plan/plate/kind; it can't forge a price, ownership, or a tier.
The five agent events are DoS-budgeted in `palm6_eventguard`.

## Plan tiers

A policy records its tier; claims pay at that tier's coverage/deductible, payout
speed, and theft %. `standard` reproduces the old flat plan exactly (pre-tier
policies backfill to it via `sql/0064`).

| Tier | Premium | Coverage | Deductible | Term | Payout | Theft |
|---|---|---|---|---|---|---|
| Basic | 3% | 40% | 15% | 48h | 15 min | 70% of coverage |
| Standard | 5% | 60% | 10% | 72h | 10 min | 100% |
| Premium | 8% | 85% | 5% | 120h | 3 min | 100% |

## Claims

- **Theft** — the city's records say it's out AND it's nowhere in the synced
  world. Pays `coverage × tier theft% − deductible`. The vehicle is **written
  off** (`player_vehicles` row deleted): you lose the car, you get the money.
- **Total loss** — assessed damage ≥ `TotalLossFrac` (85%). Pays
  `coverage × frac − deductible` and also writes the car off.
- **Damage** — assessed damage ≥ `MinDamageFrac` (25%) and < 85%. A **repair
  subsidy**, NOT a slice of value: `min(value × DamageRepairPct × frac,
  DamageMaxPayout)` minus the owner's share, then **capped at
  `DamagePayoutVsPremiumPct` of the premium paid**. The car is **kept** (not
  written off). Because the payout is always below the premium and each claim
  retires the policy (re-buy premium to claim again), self-inflicted damage
  never profits at any tier/value.
- One claim per policy: a claim retires the policy to `status='claimed'`
  (`sql/0065` added that enum member — writing it under strict SQL mode used to
  fail and leave the policy re-claimable). A plate with a recent paid/processing
  damage claim also can't be re-insured for `ReinsureLockHours`.
- Payout is recoverable: the sweep claims a `credited_at` flag before crediting,
  and a boot reconcile re-drives any claim interrupted by a restart (no double-pay).

## Fraud handling (server-derived)

Two distinct outcomes:

- **Hard DENY** — a damage/total-loss claim with **no `palm6_replay` incident
  scene** near the vehicle (in the last `SceneWindowMin`), when replay forensics
  is online. No corroborating scene ⇒ the adjuster can't verify the damage ⇒ the
  claim is refused outright. (If `palm6_replay` is offline this signal is
  disabled — absence of the black box isn't evidence.)
- **FLAG (still pays)** — other signals sum to a risk score; at/above
  `FlagThreshold` the claim still pays but opens a `palm6_evidence` case for
  police to work in RP (lands on the police Discord feed via `palm6_discord`).

| Signal | Score |
|---|---|
| Policy under `FreshPolicyMin` old at filing | 30 |
| Each prior claim in `RepeatWindowH` | 20 |
| Claim maxes the coverage cap | 15 |

## Design notes

- Commands still work as a fast path: `/insure [plate] [basic|standard|premium]`
  (defaults to standard), `/fileclaim [plate] [damage|theft]`, `/policy`.
- Payout credits by citizenid, online or offline.
- Soft deps: `palm6_replay` missing → no-scene deny disabled; `palm6_evidence`
  missing → flagged claims still pay, just no case file.
- Exports: `GetSummary() -> { activePolicies, pendingClaims }`.

## Dup-gate (2026-07-06)

No insurance functionality anywhere in the deployed recipe tree (only unrelated
`insurance|claim` hits: admin reports, ox_lib grid cells, tattoo names).
qbx_garages' depot fee is an impound charge, not a policy/claim system. The
replay-forensics fraud loop exists nowhere on Tebex — it needs `palm6_replay`.
