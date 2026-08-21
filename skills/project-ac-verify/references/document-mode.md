# Document-Mode AC Verification

What the independent reviewer checks when the card's diff is PROSE, not code. The mechanism
is unchanged — gate at card start, independent review of every AC against the diff AND the
referenced contract, gate resolved only on PASS. Only the evidence types translate. Full
stack instantiation for document cards: project-card `references/document-stack.md`.

Document projects have no compiler and no test suite: nothing catches a prose lie
mechanically. The independent reader IS the type checker. This is why outward-facing
document work is always full-mode — and why the round-1 panel evidence matters: the
implementing agent believed rev 2 of a reviewed document was correct; independent review
found ~170 findings including two criticals. Self-assessment demonstrably fails on prose.

## The "design doc" analogue

For document cards the referenced contract is usually a change list, review-findings
report, or spec section (e.g., `research/08-panel-round-1/CONSOLIDATED-CHANGE-LIST.md §D3`).
Read it exactly as Step 2 reads an ADR section — the review compares the diff against the
CONTRACT's requirements, never against the card author's summary of them.

## What the reviewer checks on a prose diff

- **Diff vs contract, item by item.** Did each contracted edit land with the contracted
  SUBSTANCE — not a summary, not a nearby paraphrase?
- **Exact-phrasing ACs.** Where the AC quotes required phrasing, the diff contains that
  phrasing (or an equivalent in substance, stated as such) — a softened cousin is a FAIL.
- **Moves are moves.** "Merge X into Y" / "dissolve Z" / "cut and redistribute" ACs:
  verify ARRIVAL at every named destination, not just departure. Silent content drops in
  merges are the skipped-YAML-AC of documents.
- **Sourced claims.** Capability names, vendor facts, and standards wording match the cited
  verification report or primary source verbatim — and were verified against the RIGHT
  target (right platform, right document, right version).
- **Grep gates actually ran and can actually fail.** Run the card's Verification command;
  flag any gate that would stay green while the finding it represents still stands.
- **Citation integrity.** No invented bibliographic details; verbatim quotations unmodified;
  no orphaned or unbracketed references introduced in the diff's scope.

## Code → document failure-mode mapping

| Known code failure | Document equivalent the reviewer must catch |
|---|---|
| XLSX AC implemented as TSV | cited/used the wrong document or standard; "trimmed" where the contract said "dissolve"; substituted a preferred format for the contracted one |
| YAML AC skipped entirely | contracted content silently dropped during a merge/move/rewrite |
| `typeof === 'function'` test | a trivially-green grep gate or read-back checklist that cannot fail |
| `as unknown` cast | hedge-wording that makes a claim unfalsifiable instead of fixing it |
| ADR says O(1), code does O(n) | contract says exact phrasing/structure; diff ships an approximation |
| closed without live-test evidence | closed without primary-source re-check evidence in card notes |

## Structured-output notes for document reviews

The schema is unchanged. Map the code-shaped fields rather than dropping them:
`type_safety_issues` → unfalsifiable hedges and weasel substitutions;
`weak_tests` → grep gates / checklists that cannot fail. Report both explicitly —
an empty array must mean "checked and none found," never "not applicable, skipped."
