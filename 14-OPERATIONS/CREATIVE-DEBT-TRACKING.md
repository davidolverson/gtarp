# Creative Debt Tracking (gtarp)

Version: v0.9.0-rc.1 (Release Candidate)
Status: Active register. Every known shortcut, placeholder, or deferred item in this
repository is recorded here with an owner and a resolution path. No undocumented
creative debt may remain at the end of a phase.

Severity: Critical (blocks release/sale) · High · Medium · Low.
Status values: Open · In Progress · Resolved · Accepted (a deliberate, owned trade-off).

---

## Register

### CD-001 — Brand art: System B emblems placed; System A core mark still pending
- **Severity:** Medium (was High) · **Status:** In Progress · **Owner:** David Olverson
- **Detail:** Phase 2 created the `01-BRAND/` scaffold + guidelines. David sent a batch
  of **6 Palm6 government-department emblems** (System B) on 2026-07-17 — these are now
  placed in `01-BRAND/logos/departments/` and registered (Candidate) in the Asset
  Registry. **Still missing:** the **System A core identity mark** (the primary ownable
  Palm6 logo), which is a different asset class from the department crests.
- **Resolution:** (a) DONE — 6 department emblems placed + registered. (b) OPEN — supply
  the System A core mark, place in `01-BRAND/logos/`, register it, and fill the System A
  specifics in `BRAND-GUIDELINES.md`. Confirm the emblems' intended home is gtarp
  `01-BRAND` (canonical) vs the website repo. The brand half of the Phase 2 gate closes
  when the System A core mark lands.

### CD-002 — `prop_spawn` dev resource is stopped, not removed
- **Severity:** Medium · **Status:** Accepted (for now) · **Owner:** Dev Lead
- **Detail:** `resources/[custom]/prop_spawn` is a dev-only test helper (ungated
  networked `CreateObject`). It is neutralized in production via `stop prop_spawn` in
  `custom.cfg` (execs after the panel's root server.cfg ensures it), because the panel
  server.cfg is outside this repo and cannot be edited to un-ensure it.
- **Resolution:** When panel access is available, remove the ensure from the root
  server.cfg and delete/relocate the resource. Until then the `stop` is the correct,
  documented mitigation. See `docs/RESTRUCTURING/PHASE-2-DEPRECATIONS.md`.

### CD-003 — Placeholder in-world coordinates on new NPC destinations
- **Severity:** Low · **Status:** Open · **Owner:** David Olverson (in-game feel-test)
- **Detail:** Several discoverable destinations use placeholder coords pending an
  in-game pass: lottery kiosk (near Davis 24/7), gunrunning dealer (scrapyard lot),
  fightclub ring (Vanilla Unicorn back lot — config marks it placeholder pending MLO),
  black market (Config). All are flagged VERIFY IN-GAME in their configs.
- **Resolution:** David retunes coords/headings in-game; update the resource configs.

### CD-004 — Downstream repo identities undefined (DEC-002a)
- **Severity:** Medium · **Status:** Open · **Owner:** David Olverson
- **Detail:** Canonical remotes confirmed for Main Server (`BlacklineDevs/gtarp`) and
  Discord Bot (`BlacklineDevs/palm6-bot`). The **Website** and **Commercial Scripts**
  canonical repos are still undeclared (DEC-002a). Does not block gtarp Phase 2/3; does
  block starting the Website repo.
- **Resolution:** David declares the two remotes; log the ruling as a Decision Log entry.

### CD-005 — Creative System is Candidate in gtarp (Phase 0 not run)
- **Severity:** Medium · **Status:** Accepted · **Owner:** David Olverson (Project Lead)
- **Detail:** gtarp adopted the Creative System as Candidate (v0.9.0-rc.1) per DEC-001.
  Phase 0 (the project-level Approval Gate that promotes the system to v1.0.0) has not
  run. Phase 2's entry condition is only "Phase 1 complete," so Phase 2 proceeds under
  the Candidate system; Phase 3 (Alignment) should run against an Approved system.
- **Resolution:** Run Phase 0 (Foundation Review + promotion) before gtarp Phase 3.
  See `14-OPERATIONS/README.md` for the DEC-numbering reconciliation.
