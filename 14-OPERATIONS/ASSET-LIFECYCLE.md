# Asset Lifecycle

Version: v0.9.0-rc.1 (Release Candidate)
Status: Governing rule document. Compliance is mandatory. The lifecycle defined here may not be bypassed, shortened, or waived for any asset.
Owner: Creative System Governance (PALM6)

---

## 1. Purpose

This document defines the single, non-negotiable lifecycle every creative asset must pass through before it can be used, shipped, sold, or archived. An asset is anything the studio produces or commissions that carries brand meaning or commercial value: logos, wordmarks, icons, color tokens, type systems, marketing renders, key art, UI kits, motion pieces, sound marks, templates, and any sellable or distributable derivative built on top of them.

The lifecycle exists to guarantee three things:

1. Nothing reaches the public, a client, or a storefront by accident or by shortcut.
2. Every promotion of an asset is deliberate, reviewed against a fixed quality bar, and recorded.
3. Ownership and licensing of anything with commercial value is known and provable before it is sold.

This is a rule document, not a suggestion. The package forbids bypassing it. If a stage cannot be satisfied, the asset does not advance. There is no informal fast path.

---

## 2. The Lifecycle at a Glance

Every asset moves through four forward stages, plus one retirement state that can be entered from any stage.

```
Experimental  ->  Candidate  ->  Approved  ->  Vault
                                    |
                                    v
                                 Archived  (retirement, reachable from any stage)
```

- Experimental: exploration and early work. Cheap to create, cheap to discard.
- Candidate: a serious proposal, ready to be reviewed against the quality gates.
- Approved: passed review, recorded in the Decision Log, cleared for real use.
- Vault: the canonical home of the approved, locked, master version. Only Approved items enter 15-VAULT/.
- Archived: the retirement state for anything withdrawn, superseded, or rejected. Preserved for history, never used as live.

Movement is always one stage at a time and always forward, except retirement. An asset may not skip from Experimental straight to Approved. It may not enter the Vault without being Approved first. An asset can be sent to Archived from any stage.

This ladder is the status ladder referenced across the package (echoed in 07-QUALITY-STANDARDS.md and 14-OPERATIONS/README.md): Experimental -> Candidate -> Approved -> Vault, with Archived as the retirement state.

---

## 3. Stage Definitions

Each stage below specifies entry criteria, exit criteria, who approves the transition, and the artifacts the stage must produce. The artifacts are not optional. If an artifact is missing, the transition has not happened.

### 3.1 Experimental

The workspace stage. This is where directions are explored, roughed out, and pressure-tested without commitment.

Entry criteria
- A brief, request, or creative question exists. This can be as light as a note in a working folder.
- The asset is registered in the Asset Registry with status Experimental. See 17-ASSET-REGISTRY/ASSET-REGISTRY-TEMPLATE.md.

Exit criteria (to advance to Candidate)
- The exploration has resolved into one clear proposal, not a spread of options.
- The proposal is self-consistent and complete enough to be judged as a whole.
- The maker believes it meets the intent of the brief and is worth a formal review.

Who approves
- The asset owner (the maker or the assigned creative lead) decides an Experimental asset is ready to become a Candidate. No external sign-off is required to move up to Candidate, because Candidate is a proposal, not an approval.

Artifacts produced
- Working files and exploration notes, kept in the asset's working area.
- An updated Asset Registry entry recording the move to Candidate, with a link to the proposed artifact.

Notes
- Experimental work carries no authority. It may never be used in production, shown to a client as final, or sold. It is not covered by any approval.
- Most Experimental assets should be discarded. That is the stage working correctly.

### 3.2 Candidate

The proposal stage. A Candidate is a finished-enough piece put forward for formal review against the studio's fixed quality bar.

Entry criteria
- Comes only from Experimental. Nothing enters as a Candidate from outside the lifecycle.
- The proposal is complete: for an identity asset, that means it satisfies System A discipline (works in one color, at small sizes, with no scenery, glows, or effects), per 05-DUAL-VISUAL-SYSTEM.md. For a marketing asset (System B), it must clearly support and not replace the System A identity.
- The Asset Registry entry is updated to Candidate.

Exit criteria (to advance to Approved)
- The Candidate passes the Foundation Review gates in full:
  - It meets every applicable standard in 07-QUALITY-STANDARDS.md.
  - It passes 08-DESIGN-REVIEW-CHECKLIST.md with no unresolved items.
- Any material creative choice the Candidate depends on is either already settled in 09-DECISION-LOG.md or is raised for decision as part of this review.
- For assets that change a system, a set direction, or anything cross-cutting, an RFC has been run and resolved. See 14-OPERATIONS/RFC-PROCESS.md and 19-RFC/RFC-TEMPLATE.md.

Who approves
- The Creative Lead (or a review group they designate) conducts the review using 08-DESIGN-REVIEW-CHECKLIST.md. Passing the review is what qualifies a Candidate for promotion. The promotion itself is not final until it is recorded in the Decision Log (see 3.3).

Artifacts produced
- A completed design review record against 08-DESIGN-REVIEW-CHECKLIST.md.
- The reviewed master artifact in its intended delivery formats.
- Any RFC that the change required, in resolved state.
- An updated Asset Registry entry.

Notes
- A Candidate may be sent back to Experimental for rework, or to Archived if rejected. Being reviewed is not a promise of approval.
- A Candidate carries no more authority than Experimental. It may not be shipped or sold. Only Approved status grants use.

### 3.3 Approved

The authority stage. Approval is the point at which an asset becomes real: cleared for production use and, where relevant, cleared to be sold.

Entry criteria
- Comes only from Candidate, and only after that Candidate has passed both review gates (07-QUALITY-STANDARDS.md and 08-DESIGN-REVIEW-CHECKLIST.md).
- A Decision Log entry has been created in 09-DECISION-LOG.md recording the approval. This is the hard governance rule of the entire system: nothing is Approved without a Decision Log entry. If there is no DEC entry, the asset is not Approved, regardless of who said otherwise.

Exit criteria (to advance to Vault)
- The approved master is finalized, versioned, and ready to be locked as the canonical source.
- The Decision Log entry references the exact version being locked.

Who approves
- Approval is granted by the authority named in the governance model for that asset class, and it becomes valid only when the corresponding DEC entry is written. The Decision Log entry, not a verbal or chat approval, is the record of truth.

Artifacts produced
- A Decision Log entry (DEC-XXX) in 09-DECISION-LOG.md using the standard fields: Date (YYYY-MM-DD), Decision ID (DEC-XXX), Topic, Decision Made, Reasoning, Impact Areas, Status (Approved), Related Documents. The template is 20-TEMPLATES/DECISION-LOG-ENTRY-TEMPLATE.md.
- An Asset Registry entry updated to Approved, carrying the DEC ID, the version, and, for commercial assets, the licensing and ownership record required in section 5.
- The finalized master artifact.

Notes
- Approval is the only status that authorizes use in production, delivery to a client, or sale.
- Approval is version-specific. If the asset changes materially, the change is a new pass through Candidate and a new DEC entry. An old approval does not cover a new version.
- Precedents in this package worded "Approved Creative System (v1.0.0 or later)" are satisfied through this mechanism. The system itself is currently v0.9.0-rc.1 (Release Candidate). It becomes v1.0.0 (Approved) when Phase 0, the Creative System Approval Gate, runs the Foundation Review and logs DEC-002 promoting the system from rc.1 to v1.0.0. The same discipline that promotes a single asset promotes the system as a whole.

### 3.4 Vault

The canonical-master stage. The Vault holds the locked, authoritative version of each Approved asset. It is the place downstream repos and executors are told to trust.

Entry criteria
- The asset is Approved, with a valid DEC entry.
- Only Approved items enter 15-VAULT/. Nothing at Experimental or Candidate status may be placed there, without exception.

Exit criteria
- An asset leaves the Vault only by being superseded (a newer Approved version replaces it) or retired (moved to Archived). The Vault is never edited in place. Changes come from a new Approved version, which then supersedes the prior one in the Vault.

Who approves
- Vaulting follows automatically from Approval plus finalization. The authority is the same DEC entry that approved the asset. No separate approval body is needed to place an already-Approved master into the Vault, but the placement must be recorded in the Asset Registry.

Artifacts produced
- The locked master files in 15-VAULT/, organized per 15-VAULT/README.md.
- An Asset Registry entry marked Vault, pointing at the locked master and its DEC ID.

Notes
- The Vault is the single source of truth for approved identity and system assets. When a downstream precondition says an Approved asset is available, it means the asset is in the Vault with a DEC entry behind it.

### 3.5 Archived (retirement)

The retirement state. Archived is where assets go when they are withdrawn, rejected, superseded, or deprecated. It is reachable from any stage.

Entry criteria
- A decision to retire, reject, or supersede the asset. If the asset was ever Approved or is being deliberately withdrawn from a set direction, the retirement is recorded with a Decision Log entry (Status Rejected or, for a superseded item, a note referencing the DEC that approved its replacement).

Exit criteria
- Archived is a terminal state. An archived asset is not reactivated. If the studio wants to revive an old direction, it re-enters the lifecycle at Experimental as new work and is judged fresh.

Who approves
- The asset owner or the reviewer, depending on the asset's current stage. Retiring an Approved asset requires a Decision Log entry, because unwinding an approval is itself a governed decision.

Artifacts produced
- Archived masters and history preserved in 21-ARCHIVE/, per 21-ARCHIVE/README.md.
- An Asset Registry entry marked Archived, with the reason and any related DEC ID.

Notes
- Archived assets are kept for provenance and learning. They are never used as live, shipped, or sold assets.

---

## 4. Governance Ties

The lifecycle does not stand alone. It is bound to the rest of the operating system.

### 4.1 Decision Log

The Decision Log (09-DECISION-LOG.md) is the ledger of authority. The rule is absolute: nothing is Approved without a Decision Log entry.

- Promotion from Candidate to Approved requires a DEC entry.
- Retirement of an Approved asset requires a DEC entry.
- Promotion of the Creative System itself from rc.1 to v1.0.0 is DEC-002, created during Phase 0.
- DEC-001 records the Dual Visual System decision (Approved) and underlies the System A / System B distinction the lifecycle enforces at the Candidate gate.

Every DEC entry uses the standard fields defined in 09-DECISION-LOG.md and 20-TEMPLATES/DECISION-LOG-ENTRY-TEMPLATE.md: Date, Decision ID, Topic, Decision Made, Reasoning, Impact Areas, Status, Related Documents.

### 4.2 RFC Process

Assets that set or change a system, a color foundation, a naming convention, or any cross-cutting direction do not go straight to review. They go through an RFC first, per 14-OPERATIONS/RFC-PROCESS.md, using 19-RFC/RFC-TEMPLATE.md. The RFC resolves the direction; the design review then judges the execution against that resolved direction. An RFC that lands a decision produces or feeds a DEC entry. Routine single-asset work that does not change a system does not require an RFC, but still requires the full review at the Candidate gate.

### 4.3 Review Gates

The two review gates are fixed and apply at the Candidate-to-Approved transition:

- 07-QUALITY-STANDARDS.md is the quality bar. The asset must meet every applicable standard.
- 08-DESIGN-REVIEW-CHECKLIST.md is the review procedure. The asset must pass every applicable item.

These are the same gates used at the project level in Phase 0's Foundation Review. A single asset and the whole system are held to the same bar.

### 4.4 The Vault

15-VAULT/ receives only Approved items. This is the enforcement point that keeps unreviewed work out of the canonical source. The Vault rule and the Decision Log rule together mean that anything a downstream repo trusts as canonical has, by construction, a review and a recorded decision behind it.

### 4.5 The Asset Registry

Every asset, at every stage, has a live entry in the Asset Registry (17-ASSET-REGISTRY/, template at 17-ASSET-REGISTRY/ASSET-REGISTRY-TEMPLATE.md). The Registry is where current status, version, owning DEC ID, and, for commercial assets, licensing and ownership live. If an asset is not in the Registry, it is not under governance and may not be used.

---

## 5. Extra Protection for Commercial and Sellable Assets

Assets that can be sold, licensed, or distributed carry additional, stricter controls on top of the standard lifecycle. Commercial value raises the cost of a mistake, so the bar is raised to match. The Commercial Scripts repository and any storefront-bound asset fall under this section.

The rules are non-negotiable:

1. No sale or distribution without Approved status. A commercial asset may not be sold, licensed, bundled, listed on a storefront, or handed to a customer until it is Approved with a valid Decision Log entry. Experimental and Candidate commercial assets are internal only. There is no exception for a rush, a demo, or a favor.

2. Licensing and ownership must be recorded in the Asset Registry before sale. Before a commercial asset can be sold or distributed, its Asset Registry entry must record:
   - Ownership: who holds the rights to the asset and every embedded component.
   - Provenance: the origin of any third-party or commissioned material inside it, and the terms under which it was obtained.
   - License terms: exactly what the buyer or recipient is and is not permitted to do.
   - Any restrictions, encumbrances, or attribution obligations.
   If ownership or licensing is unknown or unrecorded, the asset is not sellable, regardless of its design-quality status.

3. Approval of a commercial asset is a governed decision with its own DEC entry. The DEC entry for a sellable asset must state, in Impact Areas and Reasoning, that commercial release is authorized and that ownership and licensing have been verified and recorded. Approving the design is not the same as clearing the sale. Both must be true and both must be logged.

4. Distribution follows the Vault. The version sold or distributed is the Approved, Vaulted master. Selling a Candidate or a working file is prohibited.

5. Withdrawal is also governed. Pulling a commercial asset from sale, or changing its license, is a decision recorded in the Decision Log and reflected in the Asset Registry. A sold asset that is later retired moves to Archived, with the withdrawal reason recorded.

These protections exist so that the studio can always answer, for anything it sells, three questions with a document rather than a memory: Do we own it? What did we license it as? Who approved the sale, and when?

---

## 6. Enforcement

- An asset's authority is its status, and its status is only what the Asset Registry and the Decision Log say it is. Verbal approval, a message in a channel, or a maker's confidence is not a status.
- Use in production, delivery to a client, entry into the Vault, and any sale all require Approved status backed by a DEC entry. No other path grants them.
- Skipping a stage, editing a Vaulted master in place, or selling a non-Approved commercial asset is a governance violation, not a workflow variation.
- If any required gate, artifact, or record is missing, the transition did not occur and the asset remains at its prior status.

This lifecycle is part of the operating system described in 14-OPERATIONS/README.md and is versioned under 14-OPERATIONS/VERSION-CONTROL.md. It is maintained through the same governance it describes.

---

Related documents: 05-DUAL-VISUAL-SYSTEM.md, 07-QUALITY-STANDARDS.md, 08-DESIGN-REVIEW-CHECKLIST.md, 09-DECISION-LOG.md, 14-OPERATIONS/README.md, 14-OPERATIONS/RFC-PROCESS.md, 14-OPERATIONS/VERSION-CONTROL.md, 14-OPERATIONS/CREATIVE-DEBT-TRACKING.md, 15-VAULT/README.md, 17-ASSET-REGISTRY/ASSET-REGISTRY-TEMPLATE.md, 19-RFC/RFC-TEMPLATE.md, 20-TEMPLATES/DECISION-LOG-ENTRY-TEMPLATE.md, 21-ARCHIVE/README.md
