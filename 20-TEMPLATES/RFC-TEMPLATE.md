# RFC Template (Templates Copy)

Version: v0.9.0-rc.1 (Release Candidate)
Status: Release Candidate, reusable copy, mirrors the canonical template
Owner: PALM6 Creative System Governance

---

## About this copy

The canonical RFC template lives in `19-RFC/RFC-TEMPLATE.md`. That file is the source of truth. This file is a convenience copy kept in `20-TEMPLATES/` alongside the other reusable templates, so that anyone browsing the templates folder finds the RFC form in one place with the Decision Log and Phase Completion templates.

The two files hold the same fields and the same guidance. If they ever differ, `19-RFC/RFC-TEMPLATE.md` wins. When the RFC template is revised, update the canonical file first, then bring this copy into line. Do not let this copy drift.

For the review timeline, who reviews, and how an RFC advances, see `14-OPERATIONS/RFC-PROCESS.md`.

---

## How to use this template

An RFC (Request for Change) is the formal way to propose any change to the PALM6 Creative System or to the way the four repositories are restructured and maintained. Use an RFC when a change is large enough that it needs a written record and a decision, rather than a quick edit. Typical triggers are a new visual direction, a change to an approved standard, a new asset category, a change to folder structure, or anything that affects more than one repository.

Follow these steps:

1. Copy this file (or the canonical one in `19-RFC/`). Do not edit either template in place. Create a new file inside `19-RFC/` named `RFC-XXX-short-title.md`, where `XXX` is the next free RFC number in sequence.
2. Fill in every section below. If a section does not apply, write "None" and give one sentence of reasoning. Do not delete sections.
3. Open the RFC with Status set to `Draft` while you are still writing. Move it to `Open` when it is ready for review.
4. Route the RFC through the process described in `14-OPERATIONS/RFC-PROCESS.md`. That document owns the review timeline, who reviews, and how an RFC advances.
5. When a decision is reached, record it in `00-FOUNDATION/09-DECISION-LOG.md` using the format in `20-TEMPLATES/DECISION-LOG-ENTRY-TEMPLATE.md`, then set this RFC's Status to `Accepted` or `Rejected` and add the Decision Log reference at the bottom.

An RFC does not approve itself. Nothing is Approved without a matching Decision Log entry. Keep the writing calm and factual. State the change, the reason, and the cost. Avoid marketing language.

---

## RFC ID

`RFC-XXX`

Assign the next number in sequence. Numbers are never reused, even for withdrawn or rejected RFCs.

## Title

A short, plain statement of the change. One line. Example form: "Adopt a secondary monospace typeface for technical surfaces".

## Author

Name or handle of the person proposing the change, plus the date they started drafting.

## Date

`YYYY-MM-DD`. The date the RFC first moved to `Open`. Do not backdate.

## Status

One of:

- `Draft`, still being written, not yet ready for review.
- `Open`, submitted and under review.
- `Accepted`, approved and recorded in the Decision Log.
- `Rejected`, declined and recorded in the Decision Log.
- `Withdrawn`, pulled by the author before a decision was reached.

Update this field as the RFC moves through the process. The current status must always be accurate.

## Summary

Two to four sentences. State what is being proposed and the outcome you expect. A reader should understand the whole change from this section alone, without reading the rest.

## Motivation

Explain why this change is needed now. Describe the problem, gap, or opportunity in concrete terms. Reference the standard or principle that the current state falls short of, for example a rule in `00-FOUNDATION/07-QUALITY-STANDARDS.md` or a commitment in `00-FOUNDATION/04-NORTH-STAR.md`. If the change is prompted by real friction during restructuring, describe the friction. Do not argue from taste alone. Show the cost of doing nothing.

## Proposed Change

Describe the change in full and unambiguous detail. Someone should be able to execute it from this section without asking questions. Cover:

- What is added, altered, or removed.
- Which documents, folders, or assets are affected, named exactly (for example `00-FOUNDATION/05-DUAL-VISUAL-SYSTEM.md` or `01-BRAND/BRAND-GUIDELINES.md`).
- Where the change sits in the dual visual system. Is it part of System A (Identity: minimal, timeless, ownable, works in one color and at small sizes) or System B (Marketing: cinematic, atmospheric, supports but never replaces System A)? A change to System A carries a higher bar because it touches the ownable core.
- Any change to asset status. New assets enter at `Experimental`, then advance `Experimental -> Candidate -> Approved -> Vault`. Only Approved items enter `15-VAULT/`. `Archived` is the retirement state, not a step on the ladder.

## Alternatives Considered

List the other options you weighed and why you did not choose them. Include the option of making no change. An RFC with no alternatives is incomplete. Honest treatment of the rejected paths is what makes the chosen path defensible later.

## Impact

State the effect of this change across each area. Be specific. If an area is untouched, write "None" and say why.

- Brand: effect on identity, voice, or the brand pyramid in `00-FOUNDATION/06-BRAND-PYRAMID.md`. Note any risk to consistency across surfaces.
- Structure: effect on folder layout, file names, or cross-references. If any manifest name changes, list every document that points to it.
- Assets: effect on the asset registry in `17-ASSET-REGISTRY/`, on status ladder positions, or on the contents of `15-VAULT/`.
- Commercial: effect on the Commercial Scripts repository, on anything sold or distributed, or on external-facing marketing. Flag licensing or reuse concerns.

## Rollback

Describe how to undo this change if it proves wrong. State the steps, the assets or documents to restore, and any point of no return. If rollback is not clean, say so plainly and describe what would be lost. A change that cannot be rolled back needs a stronger justification in Motivation.

## Decision Log Reference

Leave blank while the RFC is `Draft` or `Open`. Once a decision is made, record it in `00-FOUNDATION/09-DECISION-LOG.md` and enter the Decision ID here, for example `DEC-XXX`. This link is what makes the outcome official. An RFC marked `Accepted` or `Rejected` without a Decision Log reference is not yet closed.

---

## Reviewer notes

Reserved for the review pass. Reviewers add comments, questions, and conditions here during the `Open` phase. The author may respond inline. Clear this section only after the RFC reaches a terminal status and the Decision Log entry is filed.
