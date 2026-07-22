# PALM6 — Living AI-NPC World: Roadmap

_Researched 2026-07-22 (3 parallel streams: state-of-the-art, ped-control engineering, LLM brain architecture). This is the plan to make the server feel alive off-peak — NPCs that talk, order, spend, deal, rob, and get chased — without melting the box or the budget._

---

## The goal (David's words)

> "I want NPCs to have brains and actually have talks and order and send money and keep the economy going, and rob and do stuff for the cops too... so everything is still going as the server is growing. It's gonna be dead at points of the day."

The real problem is **off-peak deadness on a growing server.** AI NPCs are the fix: a world that keeps moving with 2 players on at 4am.

---

## Honest reality check (so we build the real thing, not the demo)

- **Talking LLM NPCs in FiveM: shipped, cheap, solved.** Multiple paid + open-source resources exist (kiqrr/ai_npc blueprint, GRP AI World, Matehun00). ~$0.01–0.03 per voice exchange, or free on Groq/Gemini/local tiers.
- **Autonomous NPCs that ACT** (order, pay, deal, flee cops): proven in **single-player** GTA mods (Los Santos Alive, Sentience, Living LS AIs) and research sandboxes (Stanford Generative Agents, Altera Project Sid — 1,000+ agents that formed markets and gangs in Minecraft).
- **🔴 Nobody has shipped a multiplayer FiveM server where LLM agents autonomously live in the economy.** That last mile is **greenfield engineering** — assemblable from existing parts, but the glue is novel. We'd be early.
- **The ceiling nobody's beaten:** per-ped 24/7 autonomous agents at population scale (cost/latency killer), and open-ended emergent economy with real human players (coherence drift, exploit farming). Anyone selling "every NPC has a real brain 24/7" is selling the demo.
- **Legal note:** Take-Two DMCA'd *Sentient Streets* (a distributed single-player mod). FiveM **server scripts** (not distributed game files) have not been targeted. Use fictional GTA brands, keep it server-side, and we're in the same lane as every other RP script.

**Takeaway:** the winning design is **game-engine behaviors driven by a low-frequency server-side LLM "director"** — NOT an LLM per ped. That's what every serious stack (PUBG Ally's 2B model, Project Sid, Lyfe Agents) converges on.

---

## Architecture (the shape that works)

Three layers, each degrades gracefully if the one above it fails:

```
┌─ CHARACTER tier (LLM, on-demand) ── a player talks to an NPC → 1 conversation,
│                                     seeded with that NPC's memory + goal
├─ DIRECTOR tier (LLM, 1 batched call / 30–60s) ── looks at the whole world,
│                                     assigns goals to the WHOLE population at once,
│                                     spawns events (robbery, customer wave, drug corner)
└─ REFLEX tier (Lua, free, always on) ── ped tasks: walk, drive, flee gunshots,
                                          fight when attacked, follow schedules
```

**Deployment:** a FiveM Lua resource (`palm6_brain`) owns the NPCs + executes ped tasks; a small Node "cortex" sidecar on the same VPS holds all LLM/auth/memory logic and talks to the game over localhost HTTP.

**The two non-negotiable engineering facts:**
1. **The server has no game engine.** Peds "think" only on the client that owns them; OneSync migrates ownership and silently drops tasks. So: server orchestrates (data), client actuates (tasks), and NPCs re-assert their task on ownership change (via entity state bags).
2. **Virtualize by default, materialize on demand.** An NPC is a row in a table — you can have thousands. Real ped *bodies* only spawn near players (~10–15 per busy zone, ~40–60 networked server-wide). A business earns from "customers" on a server timer whether or not anyone's watching; the ped walking in is **theater** for when someone *is* watching.

**The economy is server-authoritative and cheat-proof.** The LLM never touches money. NPC actions carry an `amount` *request*; the server clamps it against a bounded **NPC treasury** (a daily faucet = your inflation dial) and executes through the same money functions players use. A cheater triggering an NPC event can at most complete a sale the server already scheduled.

**On-rails AI:** the model picks from a **closed action enum** (`goTo`, `orderAt`, `buyFrom`, `rob`, `attack`, `flee`, `complyWithPolice`, `talkTo`…) with typed, clamped args, via strict JSON schema. Three validation layers (schema → referential check → Lua legality check) mean the model literally cannot name an action or target we didn't define. Compound actions (`orderAt`, `rob`) are small scripted Lua choreographies — the LLM picks the verb, the engine performs the dance.

---

## The phased build

Each phase ships something that makes the server more alive, and each is feature-flagged (dark-ship discipline, like every other PALM6 gate).

### Phase 0 — Ambient life, ZERO AI  · ~1–2 days
NPCs with homes, jobs, schedules, and scenario animations that populate the world and despawn when unobserved. Lua reaction rules (flee gunfire, comply with cuffs). **This alone noticeably de-deadens a low-pop server** and is the substrate everything else steers.
- Build on: **7_popmanager** (density/scenarios, GPL), server-side spawner + schedule tables.
- Cost: $0. Risk: low.

### Phase 1 — The minimum viable "living NPC"  · ~a weekend
~5 named characters with authored identity cards (a dealer, a shopkeeper, a fence, a cab driver, a bum who knows things). Add: on-demand **dialogue** (text bubble, non-streamed v1), a per-NPC **event log + relationship map**, and 2–3 in-conversation tools (`offer_sale`, `give_info`).
- **This is the smallest thing that makes players text each other "dude the dealer remembered me."**
- Build on: forked **kiqrr/ai_npc** pipeline, ox_target on peds.
- Cost: pennies/day (Max plan or GLM free tier).

### Phase 2 — The AI Director + economy/crime loop  · ~1–2 weeks
The batched Director tick: action schema + validation + ped-task mapping, the **NPC treasury + ledger**, `customer_wave` events that send NPCs into player-owned storefronts (ties directly into the storefront gate that's already live), and crime events wired to **ps-dispatch** so on-duty police get real calls off-peak.
- **This is the pragmatic "living world"** — coordinated activity is what players actually perceive.
- Cost: ~$0–2/day (see math below).

### Phase 3 — Full agentic polish  · ongoing
Nightly reflection cron (NPCs summarize their day), faction/retaliation dynamics (rob a dealer → his crew remembers → Director spawns payback days later), scene escalation to a stronger model for flagship moments, NPC-to-NPC overheard chatter, and optionally voice (Whisper in / TTS out).

---

## Cost math (this is the part that makes it real)

| Approach | Calls/day | Cost/day |
|---|---|---|
| Naive: every NPC its own agent, thinks every 15s | ~115,000 | **$200+ — dead on arrival** |
| **Batched Director, 60s tick, ~8 active hrs** | **~480** | **~$1.30 (paid Haiku)** |
| Event-driven Director + on-demand dialogue | ~200–600 | **$0.50–1.50** |

- The batching trick: **one 2.5k-token call for 20 NPCs** beats twenty 1.5k-token calls by ~12× *and* gives coherence for free.
- **On your Claude Max plan the Director tick is ~zero marginal cost** (headless Claude, no per-token billing — the standing "No API, use Max" pattern), with **GLM-4.5-Flash free tier** as overflow. Worst case, fully on paid Haiku: ~$50/mo.
- Heuristics run 95% of behavior in Lua for free; the LLM only fires for interesting moments (a player watching, money moving, crime).

---

## What to build on vs. build new

**Reuse (don't reinvent):**
- `7_popmanager` — ambient density + scenarios (Phase 0 foundation)
- `ps-dispatch` — the Qbox police-alert bus (crime→cops)
- `ox_target` / `ox_lib` (`lib.points`, `lib.zones`) — NPC interaction + cheap spawn triggers
- `kiqrr/ai_npc` — conversation pipeline blueprint to fork
- Existing PALM6 systems — the business income faucet, robbery, and police-alert hooks already exist to plug NPC actions into
- Reference (deterministic economy loops that already do the job): NPC Food Orders, Rob NPC V2, AI NPC Police Toggle (auto-enables NPC cops when no humans on-duty — exactly the off-peak case)

**Build new (the novel glue):**
- `palm6_brain` Lua resource (NPC lifecycle, task execution, state bags)
- `cortex` Node sidecar (Director loop, dialogue, model router, memory DB)
- The action schema + validation + treasury/ledger

---

## Risks & hard parts (honest)

- **The hard part is FiveM, not the AI.** Ped jank — navmesh path failures, tasks dropping on ownership migration, GTA's driving AI — is more work than the prompts. Every compound action needs a timeout + fallback.
- **Economy safety:** the treasury faucet + per-NPC/per-player caps + full ledger are the guardrails. Per the browser-walk rule, walk every money path (rob an NPC, farm a friendly NPC, weird-price a sale) before flipping the economy gate on.
- **Graceful degradation:** LLM outage or Max-window exhaustion → NPCs fall back to Phase-0 heuristics automatically (the Lua layer never blocks on the sidecar).
- **Moderation:** LLM NPC speech in an RP context needs a content filter; keep dialogue server-side and logged.

---

## Recommended next step

**Build Phase 0 first** — ambient life with zero AI. It's 1–2 days, $0, de-deadens the server immediately, and is the foundation the Director steers later. It also lets us prove the ped-lifecycle + virtualize/materialize plumbing before any AI is involved. Then Phase 1 (the 5 named NPCs) is the first "wow, it's alive" moment for a weekend of work.

We'd feature-flag it dark like everything else, and light it up after a feel-test.
