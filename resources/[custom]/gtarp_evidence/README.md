# gtarp_evidence

Police evidence log + locker — the `docs/BUILD-ROADMAP.md` Phase 6 signature
feature candidate ("evidence-locker workflow extension for police") that
was never built. Confirmed non-duplicative: no evidence/case-log resource
exists anywhere in the deployed Qbox recipe tree.

Bridge-pattern (see `docs/GTA6-READINESS.md`): all logic is in `server/`
and `client/`; every qbx/native/ox_lib call lives in `bridge/`.

## How it works

- **Log.** On-duty police: `/logevidence <description>` writes a row to
  `gtarp_evidence` — officer identity, description, coords, timestamp.
  No proximity gate; evidence gets logged wherever the officer is.
- **Review.** On-duty police: `/evidence` shows the most recent
  `Config.LogEntryLimit` entries in a read-only dialog.
- **Locker.** A physical `[E]`-interact evidence locker (an `ox_inventory`
  stash) at the Mission Row police station — on-duty police only, gated
  server-side by job + proximity.

## Commands

| Command | Where | Effect |
| --- | --- | --- |
| `/logevidence <description>` | on-duty police, anywhere | log an entry |
| `/evidence` | on-duty police, anywhere | view recent entries |
| `[E]` at the locker | on-duty police, at the station | open the stash |

## Config (`shared/config.lua`)

- `InteractRadius`, `LockerCoords` — locker proximity gate.
- `LockerSlots`, `LockerMaxWeight` — stash capacity.
- `LogEntryLimit` — how many entries `/evidence` shows.

## Deploy

- `ensure gtarp_evidence` is wired into `custom.cfg`.
- SQL migration `sql/0012_evidence.sql` creates `gtarp_evidence` — named
  with the `gtarp_` prefix as a defensive convention after the
  `0010_properties.sql` collision with the recipe's own `qbx_properties`
  table (no collision exists here today; the prefix rules it out for good).

## GTA VI notes (Tier 3)

`Config.LockerCoords` is a Los Santos point (Mission Row PD); add it to
`docs/GTA6-TIER3-RETUNE.md` and re-author for the VI map. The log/locker
lifecycle itself is Tier 1 and carries.

## Deferred to v2

- No suspect linkage — entries are freeform text, not tied to a specific
  citizenid being investigated.
- No case numbers / grouping — a flat chronological log for v1.
- No search/filter on `/evidence` beyond "most recent N".
