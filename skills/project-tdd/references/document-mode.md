# Document-Mode Execution — TDD for Documentation & AI-Research-Writing Cards

How to EXECUTE a card whose deliverable is prose (practice-guide contributions, use-case
catalogs, research reports, STIG/SRG writing) under this skill. Every gate and rule applies;
this file translates the evidence types. Card-authoring instantiation: project-card
`references/document-stack.md`. Close-gate review: project-ac-verify
`references/document-mode.md`. Derived 2026-07-31 on the NCCoE agentic-AI rev-3 board.

## The base rule, translated

```
NO EDIT WITHOUT A NAMED DEFECT FIRST
```

The failing test of a documentation card is a NAMED defect: a review finding, a
change-contract item, or absent contracted content. The RED→GREEN cycle:

1. **RED** — before editing, demonstrate the defect exists NOW: run the grep gate that
   currently fails, or quote the current text beside the contract requirement it violates.
   If you cannot state what is wrong with the current text, you have no license to edit it.
2. **GREEN** — make the edit that fixes THAT defect.
3. **VERIFY** — re-run the gate / re-read the changed text against the contract item.
   Check the item off in card notes with the evidence.
4. Repeat per item. **One contract item (or one scenario) at a time** — never bulk-rewrite
   the document and audit afterward; that is the doc equivalent of bulk changes without
   running tests.

The config-file exception does not widen here: judgment prose is behavior, not config.
A "RED" for judgment prose is the quoted contract requirement + the current violating text.

## Mechanics that bite (learned failures)

- **Edit anchors from file bytes, never from memory.** Extract the exact current text
  before every Edit; transposed bold markers and reflowed lines break anchors silently.
- **Read the source before writing ABOUT it.** Claims about a platform, standard, or tool
  are written only after reading that source in this session — and against the RIGHT
  target (the E1 failure: claims verified against github.com when the build was Azure
  DevOps).
- **Archive agent research verbatim** the moment it arrives; summaries are not archives.
- **Never invent bibliographic details** — fetch and verify every citation before writing it.

## Gate translations (unchanged gates omitted — they apply as written)

| Gate | Document-mode reading |
|---|---|
| 1 Exhaustive branching | Cover EVERY item in the contracted scope list, not a sample. A change list is an enum; handle every member or state why one is n/a |
| 2 No silent parameter ignores | No contract item silently skipped — each is applied, or its non-application is stated and justified in card notes |
| 3 No type bypasses | No unfalsifiable hedge-wording in place of a fix ("may", "could be argued" wrapping a claim the contract says to correct) |
| 4 The key test question | "Would this verification pass with the defect intact?" A grep gate or read-back that cannot fail verifies nothing |
| 5 DRY at write time | One source of truth per definition — define once (format spec, glossary), reference everywhere; never restate a definition per section |
| 6 Error classification | Root-cause every finding before fixing: content defect vs contract defect vs source misread. A wrong finding is surfaced, not applied |
| 7 Schema-test parity | Format-spec parity: every scenario/section carries every field the document's format spec declares — no partially-formatted sections |
| 8 No fabricated defaults | No invented citations, capability names, numbers, or quotations — verify or omit |
| 9/13 Playwright / visual | n/a — nothing renders; STATE it. If a rendered artifact (docx/pptx) is a deliverable, opening and READING the converted output is the analogue |
| 10 Compiler verification | No compiler exists. The mechanical floor = the card's grep gates + reference-integrity checks, run at every increment, root scope |
| 12 Design system | The TARGET document's format vocabulary (table shapes, ID schemes, term vocabulary, citation style) |
| 14 Never blindly follow analysis | Review findings are SIGNALS: verify each against the primary source before applying. Applying a wrong finding is the same failure as ignoring a right one |
| 17 Callback validation | n/a — state it |
| 18 Live test before close | Primary-source re-verification of every edited claim, evidence in card notes |
| 19 7-layer atomic | n/a unless the document publishes a schema — state it |
| 20 No linter disables | Analogue: never weaken a verification gate or soften a contract requirement to make it pass — fix the text, or surface why the requirement is wrong |

Gates 0, 11, 15, 16, 21, 22 and the Frustration-Error protocol apply verbatim — no
translation needed. Gate 22's reviewer reads the prose diff against the change contract
(see project-ac-verify `references/document-mode.md`); full mode is mandatory for
outward-facing documents because prose has no compiler and self-assessment demonstrably
fails on it (~170 panel findings on a document its author believed correct).

## Verification checklist deltas (before declaring done)

- Every contract item in the card's scope checked off with evidence (grep output or
  quoted before/after) — not "section rewritten"
- Content-move items verified at the DESTINATION (merge/dissolve/cut = arrival, not
  departure)
- Verbatim quotations and external category names untouched by any style normalization
- Zero placeholder text (TODO/TBD/[n]-unresolved) introduced
- Diff confined to the card's declared sections of the document
