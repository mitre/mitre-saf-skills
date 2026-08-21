# Document / AI-Research-Writing Stack — Card Instantiation

How to instantiate this skill when the deliverable is a DOCUMENT, not code: practice-guide
contributions, use-case catalogs, research reports, white papers, ADR-heavy design writing,
STIG/SRG prose. The template (Phase 0 + 12 sections), all gates, and every quality rule are
unchanged — only the evidence types translate. Derived 2026-07-31 on the NCCoE agentic-AI
rev-3 board, where this mapping had to be re-derived ad hoc because no documentation row
existed in the Stack Adaptation table.

The one structural difference that matters: **prose has no compiler.** In code, the type
checker and test suite mechanically catch a fraction of self-assessment failures. In a
document, nothing does except an independent reader. That makes the independent-review
gates MORE valuable here, not less — and it is why outward-facing document projects stay
full-mode (never `tdd:lite`).

## The stack table

| Concern | Code instance | Document instance |
|---|---|---|
| Failing test | a failing unit test | a NAMED review finding (panel finding ID, factual error, missing contracted content). The card is green when each named finding is verifiably fixed |
| Regression suite | full test suite | a fresh independent review panel (facts / tech / doubter / sweep) run against the changed document |
| Verification command | `pnpm test && pnpm typecheck` | grep gates that can actually fail (banned phrases, orphaned refs, placeholder hits, dropped-content probes) + a read-back checklist against the change contract |
| Live test | run real code against real data / curl a running server | re-verify every EDITED claim at its PRIMARY source: the ground-truth document, the vendor's own docs, the standard's own text — with the check evidence captured in card notes |
| Design system | theme tokens, shared components | the TARGET document's format vocabulary: its table shapes, ID schemes, component/term vocabulary, citation style. Conforming to the destination format IS the design-system AC |
| Compiler / type gate | tsc / srb | none exists — see above; independent review carries this weight |
| Linter | eslint / rubocop | the consistency-and-style sweep (acronym discipline, vocabulary normalization, citation style) — run as its own late card, after content settles |
| Rendering / Playwright | screenshots light+dark | no analogue — STATE "nothing renders — no Playwright" in the card; do not silently drop the section |
| Response-shape contract | 7-layer OpenAPI rule | no analogue unless the document publishes a schema — STATE it |

## 12-section template translations

- **First failing test:** name the review finding(s) or the absent contracted content — never "n/a". For epics: "See child cards."
- **Files:** the document(s) being edited + research-archive files being created. Test: "none" stated explicitly.
- **Acceptance criteria:** quote exact-phrasing requirements verbatim (a softened cousin of the required phrasing is a FAIL). Content-move ACs ("merge X into Y", "dissolve Z") name the source AND every destination — a move is not a delete, and the reviewer must be able to check arrival, not just departure.
- **Verification:** at least one grep gate that can actually fail, plus the read-back checklist. A grep that goes green while the finding stands is the `typeof === 'function'` of documents.
- **Live-test AC:** the primary-source re-check, with sources/URLs/row-IDs captured in card notes.
- **Design-system AC:** conformance to the target document's format spec (its tables, IDs, vocabulary) — worded in that document's own terms.
- Everything else (Decision points, Anti-patterns, NOT in scope, Before closing, sp, estimate) is unchanged.

## Verify against the RIGHT target — before writing, not after

Establish ground truth for every platform/vendor/environment claim BEFORE drafting: which
platform does the build under discussion actually use? The defining failure (2026-07-31,
NCCoE): implementation notes verified thoroughly against docs.github.com — but the
environment was Azure DevOps, making every verified claim wrong for its context. Thorough
verification against the wrong target is indistinguishable from no verification.

## Citation integrity — hard rules

- **Never invent bibliographic details.** No author, title, date, venue, or URL from memory —
  fetch and verify before writing. (Named failure: a fabricated "Meng et al." attribution for
  a real arXiv paper, caught only by a live lookup.)
- **Verbatim beats house style.** Quotations, external category names, and standard-status
  wording keep their exact published form; the style sweep must never "normalize" them.
- **The audit is bidirectional.** Every listed reference is used inline; every statistic and
  load-bearing claim carries its citation. Orphans get used or removed — never kept "for later."
- **Cite only sources the document's audience may see.** If the project has audience tiers
  (public deliverable vs internal corpus), the card carries the tier rule as an anti-pattern.

## Estimation note

Document sp:5 cards run longer than code sp:5 cards (careful cross-referencing and
source re-verification do not compress the way code generation does) — estimate 25–40 min
rather than the code table's 15–20. Agent-bound steps (review panels, verification
subagent round-trips) do not compress at all.

## AC verification on document cards

The close gate is unchanged and full mode stays mandatory for outward-facing documents.
What the independent reviewer checks against a prose diff — and the code→doc failure-mode
mapping — is in the project-ac-verify skill: `references/document-mode.md` there.
