# Version Control

Version: v0.9.0-rc.1 (Release Candidate)
Status: Active reference for the Creative System and all governed assets.
Owner: Creative System Operations (14-OPERATIONS/)

---

## 1. Purpose

This document defines how the PALM6 Creative System and its assets are versioned. It sets one convention for the whole system so that any reader, human or Claude, can look at a version string or a Git tag and know exactly what they are holding, how mature it is, and whether it is safe to build on.

Version control here covers two related but distinct things:

1. The Creative System as a product. The full body of Foundation, Brand, and Operations documents (folders 00 through 21) carries a single system version. Today that version is v0.9.0-rc.1, status Release Candidate. It is not yet Approved.
2. Individual assets and documents inside the system. Each asset and each governed document carries its own status on the lifecycle ladder, and those statuses map onto the system version in the way described below.

The rules in this document work alongside ASSET-LIFECYCLE.md (status ladder for assets), 09-DECISION-LOG.md (the record that makes anything Approved), and 15-VAULT/ (where frozen Approved material lives). Where this document and those two disagree on a detail, treat all three as one system and raise the conflict through the RFC-PROCESS.md rather than picking one silently.

---

## 2. Semantic Versioning

The Creative System uses semantic versioning in the standard MAJOR.MINOR.PATCH form.

- MAJOR (x.0.0). Incremented when a change breaks compatibility with work already produced under the previous version. Examples: retiring or redefining a core principle in 00-FOUNDATION/, changing the meaning of the Dual Visual System recorded as DEC-001, or restructuring the folder model in a way that invalidates existing cross-references. A MAJOR bump signals that downstream repos may need rework to stay aligned.
- MINOR (x.y.0). Incremented when material is added or expanded in a backward-compatible way. Examples: adding a new template to 20-TEMPLATES/, publishing a new Operations protocol, or extending BRAND-GUIDELINES.md with additional guidance that does not contradict what came before. Existing work stays valid.
- PATCH (x.y.z). Incremented for corrections that change no meaning. Examples: fixing a typo, repairing a broken cross-reference, clarifying wording without altering intent. A PATCH never changes what is Approved, only how clearly it is stated.

The system version is a single number for the whole product. It is not per-folder and not per-document. Individual documents track their maturity through their own status field (Section 5), not through their own SemVer number.

---

## 3. The Release Candidate Suffix

A version may carry a pre-release suffix of the form `-rc.N`, read as Release Candidate number N.

The Release Candidate suffix means the system is feature-complete for the target version and believed correct, but has not yet passed the Foundation Review that would make it Approved. A Release Candidate is safe to read, safe to review, and safe to plan against. It is not yet the authoritative Approved baseline, and nothing in it should be treated as final until promotion.

The current state of the system is v0.9.0-rc.1. The standard label used everywhere for the creative system is "v0.9.0-rc.1 (Release Candidate)". The overall handoff package status is "Release Candidate, Ready for Execution". Neither is ever described as "Final", "Production Ready", or "Approved for use".

If review during the candidate stage surfaces changes that must be made before approval, those changes are applied and the candidate number is incremented: rc.1 becomes rc.2, and so on. Each new candidate supersedes the last. The rc counter resets when the target x.y.z version changes.

---

## 4. Promotion from Release Candidate to Approved

A Release Candidate becomes an Approved release only through Phase 0, the Creative System Approval Gate. This is the single mechanism by which `-rc.N` is dropped and a clean Approved version number takes its place.

The sequence is fixed:

1. Phase 0 is run once, at project level, before any repository work begins. It is not run per repo.
2. The Foundation Review is conducted against 07-QUALITY-STANDARDS.md and 08-DESIGN-REVIEW-CHECKLIST.md. The Foundation set in 00-FOUNDATION/ is examined against those two documents in full.
3. If the review passes, the Creative System is promoted from v0.9.0-rc.1 to v1.0.0, status Approved.
4. The promotion is recorded in 09-DECISION-LOG.md as entry DEC-002, "Creative System rc.1 to v1.0.0 promotion", status Approved. The governance rule is absolute: nothing is Approved without a Decision Log entry. Until DEC-002 exists and is logged, the system remains a Release Candidate no matter how complete it looks.
5. The approved Foundation set is moved into 15-VAULT/ as the frozen baseline (Section 6).

The removal of the `-rc` suffix is not a cosmetic edit. It is the visible result of DEC-002 being written. A reader who sees `v1.0.0` with no suffix can rely on the fact that Phase 0 completed and the promotion was logged. A reader who sees `-rc.N` knows Phase 0 has not yet run to completion.

Preconditions elsewhere in the package worded "Approved Creative System (v1.0.0 or later)" are satisfied the moment Phase 0 completes and DEC-002 is logged. They are not blocked by the fact that the shipped system is currently a candidate. This is by design: the candidate is the input to Phase 0, and Phase 0 produces the Approved version those preconditions require.

After v1.0.0, later releases follow ordinary SemVer. A backward-compatible addition takes the system to v1.1.0. A correction takes it to v1.0.1. A breaking change takes it to v2.0.0. Any release that carries the Approved status is produced the same way v1.0.0 was: through a review against the quality standards and a Decision Log entry recording the promotion. Approval is never assumed; it is always logged.

---

## 5. Document Status Mapping to SemVer

Individual documents and assets do not carry their own SemVer numbers. They carry a status on the lifecycle ladder, and that status is what maps onto the system version. The status ladder is defined in full in ASSET-LIFECYCLE.md. The four working statuses relevant to version control are Draft, Candidate, Approved, and Archived.

- Draft. The document is being written or substantially revised. Its content is not settled. A Draft document may live inside a system that is at any version, but its own material is not part of what the system version guarantees. Drafts correspond to work that would sit under a future MINOR or MAJOR bump, not the current Approved baseline.
- Candidate. The document is believed complete and correct and is put forward for review. It is the document-level parallel of the system-level Release Candidate. When the system as a whole is at `-rc.N`, its governed documents are typically at Draft or Candidate. A Candidate document is what Phase 0 or a later review examines.
- Approved. The document has passed review and been logged. An Approved document is part of the guarantee that the current Approved system version makes. When the system is at v1.0.0, the Approved Foundation documents are the content that v1.0.0 stands behind. A document reaching Approved is what justifies a MINOR bump when it is a genuine addition, or is part of the MAJOR baseline when the whole Foundation is approved together at v1.0.0.
- Archived. The document has been retired. Archived is the retirement state at the end of the ladder, distinct from the four active statuses. Archived material moves to 21-ARCHIVE/. It is kept for history and reference but is no longer part of any current version's guarantee. Retiring a document that other Approved material depended on is a compatibility change and forces a MAJOR bump.

The relationship in one line: system SemVer describes the product as a whole; document status describes each part. A MINOR or MAJOR bump of the system is the moment at which a set of documents crossing into Approved is recognized at the product level.

Full ladder, including the Experimental and Vault stations and the exact promotion criteria, lives in ASSET-LIFECYCLE.md. This document only defines how those statuses relate to the version number.

---

## 6. The Vault and the Frozen Approved Version

15-VAULT/ holds the frozen, Approved version of the system's Foundation. Only Approved items enter the Vault. Experimental, Candidate, and Draft material never do.

When Phase 0 promotes the system to v1.0.0, the approved Foundation set is moved into 15-VAULT/. From that point the Vault copy is immutable for that version. It is the reference of record: the exact state of the Foundation as it stood when v1.0.0 was Approved. Downstream repositories align to the Vault copy, not to any working draft that may have moved on since.

The Vault does not accumulate edits. When a later Approved version is produced, for example v1.1.0 or v2.0.0, the new Approved Foundation set enters the Vault as that version's frozen baseline, and the earlier frozen baseline is retained for history. The Vault therefore holds a chain of frozen Approved versions, each one matching a logged Decision Log promotion. A reader can always recover the precise Foundation that any Approved version stood behind.

The governing rule stays consistent with Section 4: an item is only Vault-eligible once it is Approved, and it is only Approved once a Decision Log entry records it. The Vault is the storage consequence of approval, never a shortcut around it. See 15-VAULT/README.md for the Vault's own handling rules.

---

## 7. Git Tagging Convention

The system version is reflected in Git through annotated tags. Tags make the version history navigable and give each Approved release a fixed, retrievable point.

Convention:

- Release Candidate tags. `v0.9.0-rc.1`, `v0.9.0-rc.2`, and so on. Each candidate is tagged when it is cut for review. The tag name matches the system label exactly, minus the trailing status words. The current candidate is tagged `v0.9.0-rc.1`.
- Approved release tags. `v1.0.0`, `v1.1.0`, `v1.0.1`, `v2.0.0`, and so on. An Approved tag is created only after Phase 0 or a later review passes and the corresponding Decision Log entry is written. The tag for the first Approved release, `v1.0.0`, is created as part of Phase 0 alongside DEC-002.
- Annotation. Every tag is annotated, not lightweight. The annotation message names the Decision Log entry that authorizes it, for example "v1.0.0, Approved per DEC-002" for the first Approved release, or "v0.9.0-rc.1 (Release Candidate), pending Phase 0" for the shipped candidate. The annotation ties the tag to the governance record so the two never drift apart.
- Ordering. Tags follow SemVer precedence. A pre-release tag such as `v1.0.0-rc.1` sorts before its final `v1.0.0`, which matches the meaning: the candidate precedes the Approved release it becomes.

A tag is a claim about the state of the system. An Approved tag must never exist without a matching Decision Log entry behind it. If a tag is created in error, it is corrected through the change process, not quietly deleted, so that history stays honest. Tagging discipline sits alongside the change and RFC processes in 14-OPERATIONS/; see RFC-PROCESS.md for how a version-affecting change is proposed and CREATIVE-DEBT-TRACKING.md for how deferred corrections are recorded until they are folded into a future PATCH or MINOR release.

---

## 8. Quick Reference

- System is versioned as one number in MAJOR.MINOR.PATCH form.
- `-rc.N` means Release Candidate: complete, reviewable, not yet Approved.
- Current state: v0.9.0-rc.1, Release Candidate. Not Final, not Production Ready, not Approved for use.
- Promotion to Approved happens only through Phase 0, and only once DEC-002 is logged in 09-DECISION-LOG.md.
- Document status (Draft, Candidate, Approved, Archived) tracks each part; system SemVer tracks the whole.
- Only Approved material enters 15-VAULT/, where it is frozen per version.
- Git tags mirror the version and are annotated with the Decision Log entry that authorizes them.
