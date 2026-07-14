# palm6_clout — go live, chase clout, become evidence

IRL-streamer culture as a game mechanic. Any player with a **streamer phone**
goes live to a **simulated audience**: the viewer count is pure server math
that reacts to what actually happens around them — gunfire pulls viewers,
police chases spike them, standing around bleeds them, dying live goes viral
once. Donations drip in as in-game cash, sustained milestones unlock one-time
**brand-deal payouts**, and the twist that makes it 1-of-1: **everything
witnessed while live lands on the VOD**, and police can subpoena a streamer's
last 24 hours of clips. Streamers are walking evidence cameras — with a big
red LIVE tag over their head so every gang knows exactly who to run off the
block.

No external APIs, no real chat, no keys — the audience, chat, and donors are
all simulated server-side and in the overlay. Existing "streamer" scripts are
cosmetic overlays; this one is an economy, a job, and a liability.

Bridge-pattern (see `docs/GTA6-READINESS.md`): all logic is in `server/` and
`client/`; every qbx/native/engine-event call lives in `bridge/`.

## The loop

1. **Go live** — hold a `streamer_phone` and run `/golive`. A LIVE head tag
   appears over you (everyone can see it), an optional server-wide ping
   announces you, and the overlay opens: viewer count + rolling chat.
2. **Make content** — every 5s the server scores your last 5 seconds:

   | On camera (within 30m) | Viewers |
   | --- | --- |
   | gunfire (real damage events — blanks don't count) | +8 per shooter, capped |
   | explosion | +25, capped |
   | you fleeing police at speed | +30 per tick |
   | each bystander in frame | +2, capped |
   | filming on a **gang-owned turf zone** | ×1.5 on all gains |
   | nothing happening | −6% per tick |
   | dying on stream | one-time viral spike, then reset |

3. **Get paid** — every 90s a donation may fire, probability scaled to
   viewers (in-game cash, hourly-capped). Hold a viewer milestone for 3
   consecutive ticks and a **one-time brand deal** unlocks — cash it at the
   pawnshop broker ped (default milestones: 50/$500 up to 1,000/$20,000).
4. **Become evidence** — everything scored is also written to your VOD:
   who shot, where, when, on whose turf. On-duty police serve
   `/subpoena <player id>` **in person** to pull your last 24h of clips, and
   the served subpoena files itself into the police evidence log
   (`palm6_evidence`). Gangs now have a mechanical reason to chase streamers
   off the block; cops have a reason to protect them.

## Commands / interactions

| Interaction | Who | Effect |
| --- | --- | --- |
| `/golive` | anyone with a streamer phone | start streaming (60s cooldown) |
| `/endstream` | live streamer | end the stream, save stats |
| `/clout` | anyone | career dashboard: streams, peak, donations, deals |
| `/streamers` | anyone | top-10 all-time peak-viewer leaderboard |
| `[E]` at the broker | anyone | cash out unclaimed brand deals |
| `/subpoena <id>` | on-duty police, within 15m of target | pull the target's last 24h VOD |

## Server authority

Everything that matters is enforced server-side: viewers are computed from
OneSync-observed positions/speeds/health and engine damage/explosion events —
the client never reports what happened; the overlay is display-only (it never
takes NUI focus and has **zero** NUI callbacks). Donations roll server-side
against a rolling per-character hourly cap; milestone deals need a *sustained*
viewer count (a one-tick death spike can't unlock one), are snapshotted at
unlock, and are claimed through a conditional UPDATE so a double-fired claim
can never pay twice. Go-live, claims, subpoenas, and sync requests are all
rate-limited per character; broker and subpoena interactions are
proximity-checked server-side; the phone item is re-checked every tick, not
just at go-live. Streams have a min-elapsed warmup (no donations/milestones
in the first 60s) and a max-elapsed hard stop (auto-end at 2h).

## Config (`shared/config.lua`)

- `PhoneItem` — inventory gate (`false` to disable).
- `TickIntervalMs`, `GoLiveCooldownSec`, `WarmupSec`, `MaxStreamSec`,
  `AnnounceGoLive` — lifecycle.
- `StartViewers*`, `Min/MaxViewers`, `IdleDecayPct`, `WitnessRadius`,
  `Gain.*`, `ChaseSpeedMs`, `PoliceChaseRadius`, `DeathSpikeMult`,
  `DeadHealthThreshold` — the viewer sim.
- `DangerZone*`, `TurfRefreshSec`, `DangerZones` — palm6_turf synergy (zone
  ids/coords must mirror palm6_turf's `Config.Zones`).
- `Donation*`, `DonorNames` — donation economy + fake donor pool.
- `MilestoneSustainTicks`, `Milestones` — brand deals (payout snapshotted at
  unlock).
- `Pawnshop*`, `InteractRadius`, `ClaimCooldownSec` — the broker (Tier 3
  coords + ped model).
- `Vod*`, `Subpoena*`, `WriteEvidenceOnSubpoena` — the evidence pipeline.
- `TopStreamersLimit`, `LiveTagText`, `ClientTagRefreshMs`, `SweepIntervalMs`.

## Install

1. `ensure palm6_clout` in `custom.cfg` (after `qbx_core`, `ox_lib`,
   `oxmysql`).
2. Apply `sql/0016_clout.sql` — creates `palm6_clout_streamers`,
   `palm6_clout_deals`, `palm6_clout_vod`.
3. Add the streamer phone to your inventory items catalog (e.g. the
   `[config_overrides]/ox_inventory_overrides` ExtraItems table):

   ```lua
   ['streamer_phone'] = {
       label = 'Streamer Phone',
       weight = 500,
       stack = false,
       close = true,
       description = 'Gimbal, ring light, zero shame. /golive to start streaming.',
   },
   ```

   (Optionally add it to a shop; until the item exists, nobody can go live —
   or set `Config.PhoneItem = false` to drop the gate.)
4. Tune `shared/config.lua` (at minimum check the pawnshop coords fit your
   map edits, and that `DangerZones` mirrors your palm6_turf zones).

## Synergies (all soft dependencies — degrade silently if absent)

- **palm6_evidence** — every served subpoena files a case-log entry
  (`/evidence` shows it); the description points detectives at the full tape
  in `palm6_clout_vod`.
- **palm6_turf** — streaming on a gang-OWNED zone multiplies viewer gains
  (ownership read live from the `palm6_turf` table). Streamers hunt owned
  blocks for content; gangs get a mechanical reason to run them off.
- **Economy** — donations are capped cash drip; brand deals are one-time
  sinks-free payouts tuned well below job money; both flow through the
  normal framework money API via the bridge.

## Performance

No unconditional per-frame client loops: the broker prompt idles at 1000ms
and only tightens at the counter (palm6_evidence pattern); the LIVE-tag loop
sleeps 2s and does literally nothing unless someone is live; the overlay is
event-driven. Server-side there is one tick pass over live streamers every
5s (positions come from one shared snapshot per tick) plus a 30s
housekeeping sweep. Engine damage/explosion events are buffered only while
someone is live and pruned every tick. VOD writes are capped per-minute and
deduped per suspect/type — a sustained firefight is a handful of rows, not a
flood.

## GTA VI notes

`PawnshopCoords`, `PawnPedModel`, `DangerZones` coords, and
`DeadHealthThreshold` are Tier 3 (add to `docs/GTA6-TIER3-RETUNE.md`). The
viewer sim, donation/deal economy, VOD pipeline, SQL, and overlay are Tier
1/2 and carry — porting is the standard two-bridge-file rewrite (the server
bridge also quarantines the engine's damage/explosion event names).

## Deferred to v2

- Donation ledger (the hourly cap) is in-memory — it resets on resource
  restart. Deals, stats, and the VOD are DB-backed and survive.
- No spectate/watch mode for other players; the audience is simulated only.
- One VOD per streamer; no per-stream clip grouping or case numbers.
- No streamer-vs-streamer raid mechanic (shared-audience events).
- Subpoena reads the last 24h regardless of how many streams that spans.
