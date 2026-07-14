# palm6_witnesses

**Every crime leaves living witnesses.** Fire a gun, rob a register, sell on
a corner — the server snapshots 1-4 ambient NPC peds who *saw it*, each
holding one or two partial facts about you: the colour of your top, whether
you wore a mask, what you drove, the first three characters of your plate.
Police canvass those witnesses to build a case file. You can press them at
gunpoint or buy their silence — but intimidating a witness in view of
*another* witness writes a brand-new crime with your name on it.

No inventory items, no new peds, no MLOs — the drama is a detective loop
layered onto crimes the city already commits, feeding the `palm6_evidence`
case files police already work.

Bridge-pattern (see `docs/GTA6-READINESS.md`): all logic is in `server/` and
`client/`; every framework/native call lives in `bridge/`.

## The loop

1. **The crime.** The event bus hooks the server's `weaponDamageEvent`
   (gunfire / armed assault), every robbery-style crime the qbx recipe
   reports through `police:server:policeAlert` (store registers/safes,
   corner selling, jewelery, house/bank robbery), and `palm6_robbery` ATM
   hold-ups. Sibling resources can feed it via the `ReportCrime` export.
2. **The snapshot.** The server finds up to 4 ambient NPC peds within 40m.
   If nobody was around, the crime went unseen — do it in the desert.
   Otherwise every witness is dealt 1-2 facts from what you *actually
   exposed*: top colour and mask state from your real ped variation,
   vehicle class and a **3-character partial plate** from server-side
   vehicle natives. You get one chilling notification: *someone saw that.*
3. **The canvass.** Witness markers persist ~30 minutes (they survive
   restarts). On-duty police see every marker; walking up and pressing E
   runs a short doorstep interview, and the statement lands in a
   `palm6_evidence` **case file** (one case per incident, created lazily on
   first canvass, suspect linked as an unknown-descriptor).
4. **The counterplay.** Only the incident's own suspect sees (and can work)
   their witnesses: hold a weapon on one for ~5 seconds and their memory
   goes conveniently wrong — future canvasses yield **corrupted facts**
   (wrong colour, flipped mask, scrambled plate) or nothing, and police
   cannot tell tainted testimony from real. Or pay them off ($750 cash)
   for guaranteed amnesia.
5. **The trap.** Pressing a witness within sight of another active witness
   spawns a fresh **witness-intimidation incident** against you — observed
   by exactly the bystanders who watched you do it. Silencing people has
   witnesses too.

## Integration contract (from the duplication review)

- **Silent by design.** Witness creation never pings police. The qbx
  resources this bus listens on (`qbx_storerobbery`, `qbx_drugs`
  cornerselling, …) already roll their own NPC-reported alerts for those
  same crimes — a second ping would double-dispatch every robbery. The
  alert layer (`Config.FirePoliceAlerts`, **default ON** since the
  double-alert verification against the deployed recipe tree passed) only
  ever fires for crimes nothing else alerts on (gunfire), and it reuses the
  recipe's own `police:server:policeAlert` event — no parallel dispatch.
- **Testimonial only.** No casings, blood, or fingerprints — physical
  forensics belong to `qbx_police`'s evidence system. Witnesses tell you
  what they *saw*.
- **Partial plates only.** 3 characters max, so `qbx_police` ANPR remains
  the full-plate source.
- **Case files via the frozen `palm6_evidence` v2 exports** (`EnsureCase` /
  `AppendEntry` / `LinkSuspect`) — this resource never writes to
  `palm6_evidence` tables and keeps no parallel evidence store. Witness
  state itself lives in its own `palm6_witnesses*` tables.
- **Rate limiting:** `palm6_eventguard` exposes no registration export for
  new events, so every client-triggerable event here carries its own
  per-source rate limit **and** per-citizen cooldown (the `palm6_pumpcoin`
  pattern), all server-side.

## Player surfaces

| Surface | Who | What |
| --- | --- | --- |
| Yellow witness markers/blips | on-duty police | E = canvass (5s interview → case-file entry) |
| Red witness markers/blips | the incident's suspect | E = pay off ($750 cash) · aim + G = press (5s hold) |
| `/evidence case <id>` | police | read accumulated witness statements (palm6_evidence) |

## Commands

| Command | Who | Effect |
| --- | --- | --- |
| `/witnesses` | admin | live incident/witness counts |
| `/witnesses sim` | admin | simulate a crime at your position (QA) |

Ace-restricted; grant once in your server cfg:
`add_ace group.admin command.witnesses allow`

## Server authority (what a modified client can NOT do)

- **All facts are minted server-side at crime time.** The peds on screen
  are cosmetic markers; testimony lives in server memory + MySQL. A client
  cannot invent, read, or delete a witness.
- Canvass and press are **two-phase** with min AND max elapsed windows on
  the server clock, fresh server-side proximity at start *and* finish, and
  a position anchor (the progress bar locks movement; skipping it to move
  through the window voids the action).
- The canvass gate (on-duty police) and the press gates (incident's own
  suspect + **server-read armed state**) are enforced server-side at both
  phases. The payoff charge is a server-side cash debit with framework
  affordability.
- Suspect appearance (top variation / mask) is the one client-assisted
  read — nonce-gated, one-shot, 3s hard timeout, integer-clamped, and it
  can only ever describe *the cheater's own outfit*; every other fact
  (vehicle class, partial plate, positions, distances) comes from
  server-side natives. Worst case for a spoofing client: witnesses
  misdescribe them — no payout, no state, no other player touched.
- Every client-triggerable event is rate-limited per source and
  cooldown-gated per citizen; the hot `weaponDamageEvent` path bails on a
  no-write cooldown peek before touching anything expensive.

## Config guide (`shared/config.lua`)

- **`Config.Hooks`** — the event bus: toggle each crime source; `qbxAlerts`
  marks crimes the recipe already alerts on (those can never re-alert).
- **`Config.FirePoliceAlerts`** — the shots-fired 911 layer (default ON;
  verified non-duplicating — the recipe alerts on nothing gunfire-shaped).
- **`Config.WitnessRadius` / `Min`/`MaxWitnesses` / `WitnessTtlMin`** —
  snapshot range, witness count, marker lifetime.
- **`Config.FactsPerWitness*` / `PlateChars` / `TopColors`** — the fact
  model (how much each witness knows, how vague they are).
- **`Config.Canvass` / `Config.Press` / `Config.Payoff`** — radii,
  durations, grace windows, cooldowns, the payoff price, the corrupted-
  fact chance.
- **`Config.Intimidation`** — the "pressed in view of a witness" radius.
- **`Config.RateLimits` / `IncidentCooldownSec`** — anti-spam.

## Install

1. Drop the folder in `resources/[custom]/` and add to `custom.cfg`:
   `ensure palm6_witnesses` — **after** `palm6_evidence` (its frozen v2
   exports are presence-checked at boot; without them canvassing still
   works but statements cannot reach case files, and the console says so
   loudly).
2. Apply `sql/0019_witnesses.sql` (creates the two `palm6_witnesses*`
   tables; `CREATE TABLE IF NOT EXISTS`, touches nothing else).
3. Grant the admin ace: `add_ace group.admin command.witnesses allow`.
4. Test fast: stand near some pedestrians and run `/witnesses sim`, then
   swap to an on-duty police character and canvass the yellow markers —
   the statement lands in a case you can read with `/evidence cases`.

Requires: `qbx_core`, `ox_lib`, `oxmysql`, `palm6_evidence` (v0.2.0+),
OneSync (the server-side ped snapshot reads the ambient population).

## Synergies

- **palm6_evidence** (hard, via frozen exports): every canvass appends a
  `fact` entry and links an unknown-suspect descriptor; `/evidence case
  <id>` is where the testimony pays off.
- **qbx recipe** (soft): robbery-style crimes create witnesses through the
  alert event they already fire — zero coupling, zero double alerts.
- **palm6_robbery** (soft): ATM hold-ups leave witnesses too.
- **Economy**: payoffs are a pure cash sink; pressing is free but risks a
  fresh intimidation case.

## Perf

48-slot safe. No unconditional per-frame loops: the client render loop
sleeps 1s when no marker is near (250ms approaching, per-frame only inside
30m); the server runs a single 30s expiry sweep; the `weaponDamageEvent`
hot path exits on a table peek during the per-suspect cooldown window; NPC
snapshots run only when a crime actually fires.

## GTA VI notes (Tier 2/3)

Everything here is logic + our own SQL (Tier 1/2): the fact model, witness
lifecycle, canvass/press/payoff rules and case wiring carry unchanged. The
bridge files wrap qbx identity/job/money, the recipe alert event, ped
population enumeration, vehicle plate/type reads, and blip/marker/progress
UI — rewrite those two files against the VI framework. Blip sprites and the
ped-component ids (11 = torso, 1 = mask) are the only GTA V values.

## Deferred to v2

- Witness relocation (markers drift a street over while they "walk home").
- A composite-sketch card in the case view once enough facts accumulate.
- Witness protection: police escorting a witness to lock in testimony
  before the suspect can reach them.
- Reputation: repeat intimidators become "known to witnesses" (fewer facts,
  faster 911).
