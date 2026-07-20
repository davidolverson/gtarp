# PALM6 Founding-Beta Content Pack — free, IP-safe, buzz-per-effort

Ranked plan to fill out the server fast with **legally-safe free content** and
add "wow" mechanics for the beta launch. Source: 2026-07-20 content-scout research
+ the website promise-vs-server-inventory diff.

## The one licensing rule that unlocks everything
We are a **server operator**, not a code reseller. GPL-3 governs *distributing
source*, not *running a service* — players receive gameplay, not our Lua. So
**GPL/LGPL/MIT are all SAFE to deploy AND modify for PALM6.** The entire modern
free FiveM stack (qbx_*, ox_*, Project Sloth ps-*, glitch-minigames, illenium,
rpemotes) is GPL/LGPL = usable.

The ONLY real landmines:
- 🟡 **Escrow leaks** — a "free" copy of a normally-paid script (Wasabi, JG, rcore,
  Lation, LB-Phone, gksphone) from a leak site = piracy → Cfx ban + legal risk.
  Reimplement the *design* clean instead; reading their public docs for ideas is fine.
- 🔴 **Ripped real-brand / real-likeness assets** — celebrity peds, real-brand
  MLOs/liveries/logos. Take-Two/Cfx IP strike = existential. Vet every asset's origin.

## Where each item goes (IMPORTANT)
This repo (`gtarp-fc-phase0`) only deploys the **`[custom]` layer** via CI. The
resources below are **base-server installs** — they go in the live box's
`resources/` (via txAdmin / the recipe), NOT this repo. They need David's box
access. The one thing already built in-repo (`palm6_business`) is the exception.

---

## TIER 1 — cheapest "the server feels alive + clippable" jump (do first)

| # | Resource | License | Effort | Why for beta |
|---|---|---|---|---|
| 1 | **glitch-minigames** (Gl1tchStudios) — 28+ standalone hack/lockpick/drill minigames | 🟢 GPL-3, standalone `exports` | Very low | Force multiplier: wire into every robbery/heist/chop/drug loop → each becomes a tense, clippable *moment*. Highest leverage single install. |
| 2 | **ps-dispatch** (Project Sloth) — police/EMS alerts + blips | 🟢 GPL-3, qbox-supported | Low | The connective tissue that makes crime *matter* → emergent cops-vs-robbers = the #1 clip engine. |
| 3 | **rpemotes-reborn** — emotes + walking styles + **synced 2-player emotes** (dances, handshakes, carry) | 🟢 GPL-3, standalone | Low | Best streamer/clip bait per KB. Fills social clips + Discord highlight reels. |
| 4 | **ragdoll standalone** (`/ragdoll`) + **photomode** + **client clip capture** (Cfx free releases) | 🟢 open, standalone | Very low each | Ragdoll = perennial highlight staple; photomode/clips lower the friction from "cool moment" → "posted clip" during beta. |
| 5 | **ps-hud** (Project Sloth) — health/armor/hunger/thirst/stress status HUD | 🟢 GPL-3, qbox | Low | The recognizable, streamer-familiar HUD = instant "this is a real server" credibility. |

## TIER 2 — retention spine ("what do I do at hour 3")

| # | Resource | License | Effort | Why for beta |
|---|---|---|---|---|
| 6 | **npwd** / `qbx_npwd` — smartphone: DMs, Twitter-style feed, marketplace, camera | 🟢 GPL-3, qbox port exists | Medium (phones are fiddly) | The single biggest retention + in-world social-graph tool. **Closes the site's "City Phone" promise — currently NO phone system at all.** Do NOT touch LB-Phone/gksphone (paid/leaked). |
| 7 | **Bennys-style tuning / mod shop** (free qbox-compatible) | 🟢 verify fork LICENSE | Low-med | Delivers the site's "BUILD IT / custom cars in a port-district garage" street-culture promise + car-meet clip content. |
| 8 | fishing / hunting / diving loops (`qbx_diving` + free) | 🟢 GPL-3 | Low | Low-stakes solo grind that keeps low-pop beta hours alive. |

## Already AHEAD of the free ecosystem (do NOT rebuild — we're better)
The research flagged progression/rep and gang-turf as the only meaningful *custom*
gaps in the free space. **PALM6 already ships both, deeper than the free options:**
`palm6_gangs` + `palm6_turf` + rep, `palm6_fc_progression`, `palm6_drugs` XP,
`palm6_racing` rep ladder. Plus a huge custom crime/economy layer (~60 resources)
no free pack matches. Spend effort on the installs above, not re-building these.

---

## Already built / decided (PALM6-specific)

- ✅ **`palm6_business`** (this repo, commit 510b13e) — player-owned businesses,
  the biggest site-promise gap. Ships DARK; enable when ready (below).
- ⏳ **Enable `palm6_racing` + the Def Jam fight club** — both code-complete, currently
  dark-by-default on the committed branch (David has them test-toggled). The
  "RACE IT" + underground-fights promises are one `Config.Enabled=true` + feel-test
  away, not a build.

## Go-live batching (one restart, per the "don't restart prod for inert changes" rule)
When David greenlights, batch into ONE deploy: flip `palm6_business` (+ any of
racing/fightclub) `Config.Enabled=true`, push origin/main → CI SFTP + restart →
hit **Start** in the RocketNode panel. dbmigrate 0068 lands on that boot. Revert =
flip false. Run a pre-enable ultracode faucet audit on `palm6_business` first.

## Suggested execution order
1. Tier 1 base installs (1 day, biggest "feels alive + clippable" jump).
2. Enable `palm6_business` + racing + fightclub (feel-test) — content we already own.
3. npwd phone (#6) — closes the last big system-promise gap.
4. Tier 1 remainder + Tier 2 as beta population grows.
