# 14-OPERATIONS (gtarp)

Version: v0.9.0-rc.1 (Release Candidate)
Status: Active operational reference for the gtarp repository during the Palm6
Creative System restructuring. Introduced in Phase 2 (Organization).

---

## What lives here

Day-to-day operating rules for creative + functional assets in this repository.

| File | Purpose |
|---|---|
| `ASSET-LIFECYCLE.md` | The status ladder (Experimental → Candidate → Approved → Vault; Archived = retirement) every asset in this repo moves along. Canonical system reference, copied in. |
| `RFC-PROCESS.md` | How a significant change is proposed, reviewed, and recorded before it happens. See `19-RFC/`. |
| `VERSION-CONTROL.md` | Versioning scheme for the Creative System and individual assets. |
| `CREATIVE-DEBT-TRACKING.md` | The live register of shortcuts/placeholders taken in this repo, each with an owner and a resolution path. |

The populated per-repo Asset Registry lives in `../17-ASSET-REGISTRY/ASSET-REGISTRY.md`.

---

## ⚠️ Repo-local status note (read before trusting any "Approved v1.0.0" wording)

The copied system docs describe the Creative System's own governance, where the
system is promoted from **v0.9.0-rc.1 (Candidate)** to **v1.0.0 (Approved)** during
**Phase 0 (the Creative System Approval Gate)**, recorded in the *system's* Decision
Log as its promotion entry.

**In gtarp, Phase 0 has NOT been run.** Per `DEC-001`, gtarp adopted the Creative
System as **Candidate (v0.9.0-rc.1)** for additive, reversible work only. Therefore:

- Nothing in this repository is auto-Approved. The Creative System here is Candidate.
- An asset reaches **Approved** in gtarp **only** via an explicit gtarp Decision Log
  entry (`00-FOUNDATION/09-DECISION-LOG.md`), never by a status line in a copied doc.

### Decision-Log numbering reconciliation (DEC-002 collision)

The system package reserves **DEC-002** for the *Creative System rc.1 → v1.0.0
promotion* (a Phase 0 output). **gtarp's local `DEC-002` is already used** for the
Phase 1 post-execution audit + open-blocker registration. These are two different
things sharing an ID across two different logs.

**Resolution (logged in `DEC-003`):** gtarp's local Decision Log is authoritative for
this repository. gtarp will **not** renumber its already-logged `DEC-001`/`DEC-002`.
Where a copied system doc says "DEC-002 (promotion)", read it as *"the promotion
entry in the system's own log."* If/when gtarp runs Phase 0, the local promotion will
be logged under the **next free gtarp DEC id** (not `DEC-002`), and that id will be
cited as the local promotion reference. Until then, the system in gtarp is Candidate.
