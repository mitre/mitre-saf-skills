# The Claims Register

The claims register is the document's test suite: every load-bearing statement the document will make, with its verification status and evidence pin. It is created at Frame time as a skeleton (claims listed before any are researched), filled during Research, and consumed during Drafting — prose may only assert what the register has verified.

## Format

A markdown table (or equivalent tracker artifact) per document:

```markdown
| # | Claim | Class | Status | Pin | Used in |
|---|-------|-------|--------|-----|---------|
| C1 | Guide v2.13 contains zero occurrences of the term "virtual machine" | external | VERIFIED | sources/guide-v2.13.pdf, full-text search, retrieved 2026-07-05 | §2 |
| C2 | Framework X's levels gate build integrity only, with no test-coverage dimension | external | VERIFIED | framework spec v1.1 §levels, cached, retrieved 2026-07-06 | §8 |
| C3 | Concept Y in the 2018 paper predates public framework Z | external | REFUTED — Z existed as academic work by 2016; reworded to "predates industry adoption" | Z's founding paper, 2016 | — |
| C4 | The dual-axis principle: single-axis evaluation produces false confidence | author | VERIFIED (fidelity) | author's source text §Foundations, wording preserved | §2, §4 |
| C5 | Because C1 and C2 hold, the two models are complements, not competitors | synthesis | OPEN — validity re-derivation pending review lens | derives from C1, C2 | §8 |
```

## Field rules

**Claim** — one falsifiable statement. If it can't be false, it isn't a claim (it's framing — no register entry needed). Compound statements split into separate rows.

**Class** — routes the claim to its check (see the skill body):
- `external` — full pin: verbatim quote or specific datum + pinpoint location + cached source + retrieval date
- `author` — fidelity pin: the author's source text location whose meaning the new wording must preserve
- `synthesis` — premise list: which register rows it derives from; a reviewer re-derives the inference

**Status** — the red/green state:
- `OPEN` — stated, not yet verified. A document with OPEN load-bearing claims is red; it does not ship.
- `VERIFIED` — pinned. Only VERIFIED claims may appear in prose.
- `REFUTED` — the check failed. The row stays in the register permanently (see do-not-resurrect below) with the corrected fact and pin.

**Pin** — enough information for a stranger to re-verify in under a minute: source file (cached), location within it, retrieval date. "The SLSA docs" is not a pin; "slsa.dev/spec/v1.0/levels, cached sources/slsa-v1.0-levels.html, retrieved <date>" is.

**Used in** — which sections assert this claim. Enables impact analysis when a pin goes stale: re-verify the pin, know instantly which prose is affected.

## The do-not-resurrect list

REFUTED rows are never deleted. Refuted claims are zombies — they return through later drafting sessions, summaries, or other writers, because the convenient version is more memorable than the correction. The register is the immune system: before adding any new claim, check it against the REFUTED rows first.

## The strength ladder in practice

Status claims about software, standards, or programs record their ladder rung in the claim text itself:

- "Feature X **shipped in** release 3.3" — verified against the release notes/tag
- "Feature X **is implemented on the main branch** and slated for release 3.4" — verified against the merged change; do NOT write "released"
- "Feature X **is planned**" — verified against the roadmap document, dated, because plans change

Each rung has a different authoritative source. Pinning a "shipped" claim to a merged pull request is a class error — the release is the source for "shipped."

## Register hygiene

- One register per document, living next to the document's plan file.
- The register is an internal working artifact — it does not ship with the document (but pins make the document's citations trivially derivable).
- When a document is revived after significant time, the register is re-verified before new work: every pin re-checked against its source, stale rows re-opened. This is the "run the old test suite first" step.
