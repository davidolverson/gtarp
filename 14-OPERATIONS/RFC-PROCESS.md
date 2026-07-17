# RFC Process

Version: v0.9.0-rc.1 (Release Candidate)
Status: Release Candidate. Governs how significant changes to the Creative System are proposed, reviewed, and recorded.
Owner: Creative System Steward

---

## 1. Purpose

The RFC (Request for Comment) process is how the PALM6 Creative System absorbs change without losing coherence. It gives every non-trivial structural, brand, or governance change a single, visible path: a written proposal, a review by the people accountable for the system, and a recorded outcome in the Decision Log.

The process exists to protect two things at once. First, the integrity of the system, so that changes are considered against the standards in `07-QUALITY-STANDARDS.md` and `08-DESIGN-REVIEW-CHECKLIST.md` rather than made in isolation. Second, the speed of the team, so that small and reversible changes are never slowed by ceremony they do not need.

An RFC is not a request for permission to do good work. It is a request for the collective judgment of the system's stewards before a change alters shared foundations that other repositories and future contributors will depend on.

---

## 2. When an RFC Is Required

File an RFC before making any non-trivial change to the shared foundations of the Creative System. In practice this means a change is a candidate for an RFC whenever it is structural, touches the brand, or alters governance.

An RFC is required for changes such as:

- **Structural changes.** Adding, removing, renaming, or re-scoping a top-level folder (00 through 21), changing the meaning or ownership of a folder, or altering how the Foundation set, the Vault (`15-VAULT/`), or the operational documents relate to one another.
- **Brand changes.** Any change to the identity or marketing systems described in `05-DUAL-VISUAL-SYSTEM.md`, `06-BRAND-PYRAMID.md`, `01-BRAND/BRAND-GUIDELINES.md`, or `00-FOUNDATION/COLOR-SYSTEM.md`. This includes changes to System A (Identity), changes to how System B (Marketing) supports but never replaces System A, changes to the color system, and changes to logo or wordmark usage.
- **Governance changes.** Any change to how the system is governed, including the phase model, the asset status ladder (Experimental, Candidate, Approved, Vault, with Archived as the retirement state), the quality standards, the review checklist, the roles who approve work, or the RFC process itself.
- **Foundation document changes.** Any material change to a document in `00-FOUNDATION/` that alters intent rather than fixing a typo, including the Design Manifesto, the Project Principles, the North Star, and the Quality Standards.
- **Cross-repository impact.** Any change that would affect more than one of the four repositories (gtarp, Website, Discord Bot, Commercial Scripts) or that would change what a downstream precondition depends on.

If you are unsure whether a change needs an RFC, treat the doubt as a signal to file one. The cost of a short RFC is low. The cost of an unreviewed change to a shared foundation is paid by everyone who inherits it.

---

## 3. Changes That Do Not Need an RFC

Small, reversible, and local changes should not go through the RFC process. Requiring an RFC for work that can be undone in minutes would slow the team without protecting the system.

You do not need an RFC for:

- **Typos, grammar, and formatting.** Fixing spelling, punctuation, broken Markdown, or a broken cross-reference.
- **Clarifications that do not change intent.** Rewording a sentence so it reads more clearly while preserving its meaning.
- **Adding examples or references** that illustrate an existing rule without changing the rule.
- **Routine asset movement within its lifecycle** that follows the process already defined in `14-OPERATIONS/ASSET-LIFECYCLE.md`, such as promoting an asset from Experimental to Candidate under existing criteria. Promotion of an asset into `15-VAULT/` still follows the Approved gate defined in the asset lifecycle, not a new RFC, unless the promotion criteria themselves are being changed.
- **Reversible internal edits** to a working document that do not alter a foundation, a brand rule, or a governance rule, and that any reviewer could revert with a single edit.

The test is simple. If the change is small, local, and reversible, and it does not touch structure, brand, or governance, make it directly. If it is any of those three, or if reverting it would be costly or confusing, file an RFC.

---

## 4. RFC States

Every RFC moves through a defined lifecycle. The current state is recorded at the top of the RFC document itself.

1. **Draft.** The author is still writing. The proposal is not yet ready for review. Others may see it, but no decision is expected. An RFC can stay in Draft as long as needed.
2. **Open.** The author has submitted the RFC for review. Reviewers are invited to comment. This is the active discussion state, and it is where the substance of the proposal is tested against the Quality Standards and the Design Review Checklist.
3. **Accepted.** The reviewers have agreed to adopt the proposal. The change may now be implemented, and a corresponding entry is recorded in the Decision Log (`00-FOUNDATION/09-DECISION-LOG.md`) with Status "Approved".
4. **Rejected.** The reviewers have decided not to adopt the proposal. The RFC is kept for the record, and the decision is logged in `09-DECISION-LOG.md` with Status "Rejected" so the reasoning survives.
5. **Withdrawn.** The author has retracted the proposal before a decision was reached, for example because it was superseded, no longer needed, or replaced by a better proposal. A Withdrawn RFC is kept for the record. If the underlying question still matters, it is logged as Deferred; otherwise it is simply closed without a Decision Log entry.

State transitions run forward: Draft moves to Open, and Open moves to Accepted, Rejected, or Withdrawn. An Accepted or Rejected RFC is closed. If a closed decision needs to be revisited later, file a new RFC that references the earlier one rather than reopening it.

---

## 5. How to File an RFC

1. **Create the RFC document.** Add a new file in `19-RFC/` using `19-RFC/RFC-TEMPLATE.md` as the starting structure. A copy of the same template is also maintained at `20-TEMPLATES/RFC-TEMPLATE.md`; use the one in `19-RFC/` for filing so the proposal lives alongside the other RFCs.
2. **Number and name it.** Give the RFC the next sequential identifier and a short, descriptive title, following the naming convention shown in `19-RFC/README.md`.
3. **Fill in the template completely.** State the problem, the proposed change, the alternatives you considered, the impact areas (which folders, documents, brand systems, or repositories are affected), and the reversibility of the change. A proposal that hides its trade-offs is not ready for review.
4. **Set the state to Draft** while you write, then change it to **Open** when you are ready for review.
5. **Announce it** to the reviewers using the team's normal channel so the review can begin. An Open RFC that no one is told about is not actually open.

---

## 6. Who Reviews

RFCs are reviewed by the stewards of the Creative System: the roles accountable for the affected foundation, brand, or governance area. The Creative System Steward is responsible for making sure every Open RFC is reviewed and reaches a clear outcome.

Reviewers judge the proposal against the shared standards, not personal preference. Every RFC is measured against `07-QUALITY-STANDARDS.md` and `08-DESIGN-REVIEW-CHECKLIST.md`. Brand RFCs are additionally measured against `05-DUAL-VISUAL-SYSTEM.md`, `06-BRAND-PYRAMID.md`, and `01-BRAND/BRAND-GUIDELINES.md`, with particular attention to the rule that System B (Marketing) supports but never replaces System A (Identity).

A proposal is Accepted only when the accountable reviewers agree it strengthens the system rather than eroding it. Where reviewers disagree and cannot resolve the disagreement in discussion, the conflict is escalated through the resolution path defined in the operational documents rather than settled informally.

---

## 7. Recording the Decision

No change to a shared foundation is considered Approved until it has a Decision Log entry. This rule is preserved from the system's governance model and is not waived by the RFC process. The RFC captures the discussion; the Decision Log captures the outcome.

When an RFC reaches Accepted or Rejected:

1. **Record the decision** in `00-FOUNDATION/09-DECISION-LOG.md` using the entry format defined there and in `20-TEMPLATES/DECISION-LOG-ENTRY-TEMPLATE.md`. The entry carries the fields Date (YYYY-MM-DD), Decision ID (DEC-XXX), Topic, Decision Made, Reasoning, Impact Areas, Status (Approved, Rejected, or Deferred), and Related Documents.
2. **Reference the RFC.** List the RFC file in the Related Documents field so the decision and its full reasoning stay linked.
3. **Update the RFC state** to match the outcome, so the RFC in `19-RFC/` and the entry in `09-DECISION-LOG.md` tell the same story.

For reference, `DEC-001` records the Dual Visual System decision (Approved). `DEC-002` records the promotion of the Creative System from v0.9.0-rc.1 to v1.0.0, created during Phase 0, the Creative System Approval Gate. New RFC-driven decisions continue the sequence from there.

---

## 8. After Acceptance

An Accepted RFC authorizes the change; it does not complete it. Once an RFC is Accepted and logged:

- Implement the change as described. If implementation reveals that the change must differ materially from what was Accepted, file a follow-up RFC rather than quietly diverging from the recorded decision.
- Update every document affected by the change so the system stays internally consistent and no cross-reference is left pointing at the old state.
- If the change alters how future work is governed, make sure the relevant operational documents in `14-OPERATIONS/` reflect the new rule.

The RFC process is complete only when the change is made, the affected documents are consistent, and the Decision Log tells the truth about what was decided and why.

---

## 9. Related Documents

- `19-RFC/RFC-TEMPLATE.md`, the template used to file an RFC
- `19-RFC/README.md`, RFC folder conventions and numbering
- `20-TEMPLATES/RFC-TEMPLATE.md`, mirror of the RFC template in the templates set
- `00-FOUNDATION/09-DECISION-LOG.md`, the record of every Approved, Rejected, and Deferred decision
- `20-TEMPLATES/DECISION-LOG-ENTRY-TEMPLATE.md`, the Decision Log entry format
- `07-QUALITY-STANDARDS.md`, the standard every RFC is measured against
- `08-DESIGN-REVIEW-CHECKLIST.md`, the checklist reviewers apply
- `14-OPERATIONS/ASSET-LIFECYCLE.md`, routine asset movement that does not require an RFC
- `14-OPERATIONS/VERSION-CONTROL.md`, how versioned changes are tracked
- `05-DUAL-VISUAL-SYSTEM.md`, `06-BRAND-PYRAMID.md`, `01-BRAND/BRAND-GUIDELINES.md`, brand foundations that brand RFCs must respect
