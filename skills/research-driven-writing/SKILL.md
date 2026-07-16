---
name: research-driven-writing
description: >-
  Research-driven writing (RDW) — the test-driven development equivalent for
  documents. Claims are pinned to verified primary sources BEFORE prose is
  written, and every paper moves through a standard lifecycle: frame, research
  and sourcing, section drafting, multi-lens review, independent review, author
  sign-off. Use when writing or modernizing a paper, policy document, white
  paper, analysis, or brief that makes factual claims; when asked to "fill in"
  a document skeleton; when a document needs citation verification; or when a
  document is bound for external or public readers.
compatibility: >-
  Works in any agent tool. Pairs with the project-card and project-ac-verify
  skills and the beads (bd) tracker when present; degrades to any issue
  tracker.
license: Apache-2.0
metadata:
  author: mitre-saf
---

# Research-Driven Writing

**NO LOAD-BEARING PROSE WITHOUT A PINNED CLAIM FIRST.**

That is the base rule, and it is the exact analogue of TDD's "no production code without a failing test first." Everything else in this skill exists to make that rule executable.

**Why the economics are stronger than code TDD:** code fails loudly at runtime, with a stack trace, usually in front of the developer. Documents fail silently at read time, in front of exactly the audience you cannot afford to fail in front of, with no stack trace. One caught fabrication discounts the entire document — the blast radius of a single unverified claim is total, and reputation does not patch. A reviewer WILL check your citations.

## The Analogy

| TDD | RDW |
|---|---|
| Write the failing test first | State the claim check before finding the source |
| Red — prove the test can fail | Attempt to refute the claim before trusting it |
| Green — minimal code passes | Claim pinned: verbatim quote + pinpoint location + cached source |
| Refactor under green | Edit prose freely for voice and altitude — pins hold the facts fixed |
| Regression suite accumulates | Mechanical check battery accumulates; re-run after every edit |
| Tests verify requirements, not implementations | Checks verify claims and constraints, not phrasing |

The deep property both share: **verification is externalized and defined before the work exists.** The author's confidence is replaced by a check. This matters most for AI-assisted writing, whose dominant failure modes are confident fabrication, drift from sources, overclaim, and voice erosion — none of which the author's own review reliably catches.

**Where the analogy honestly breaks** (and the skill must not pretend otherwise):

1. **There is no compiler for quality.** Checks come in two tiers and must never be conflated:
   - **Mechanical checks** — greps, link checks, date checks, term-consistency scans. True red/green.
   - **Judgment checks** — review lenses with stated criteria ("a senior non-specialist reader can follow every section"). These are code review, not unit tests. A green mechanical battery plus passing lenses is strong evidence, not proof.
2. **The ultimate test — does the document persuade its intended reader — only the reader can run.** Persona lenses approximate it. The author gate is never delegated.

## Claim Classes (route each claim to the right check)

Not everything in a document is externally verifiable, and demanding citations for the author's own theory is as wrong as skipping them for facts.

| Class | What it is | The check |
|---|---|---|
| **External fact** | Version numbers, dates, quotes, capabilities, statistics, what a standard says | Full pin required: verbatim text, pinpoint location, cached source, retrieval date |
| **Author position** | The author's own concepts, models, arguments, terminology | Fidelity check against the author's own source text — does the new wording preserve the original meaning? Attributed decisions recorded, never invented |
| **Synthesis** | Conclusions drawn from pinned claims | Validity check — does the conclusion actually follow from the pinned premises? A lens reviewer re-derives it |

## The Claim-Strength Ladder (mandatory vocabulary)

Status claims about software, standards, or programs use a fixed ladder — because "it exists" hides four different truths, and conflating rungs is a recurring, reputation-costly bug:

**shipped/released → implemented/merged → in progress → planned → proposed**

State the rung explicitly and verify it against the authoritative source at writing time, not from memory. Classic failure: describing merged-but-unreleased work as "released," or still calling something "planned" after it shipped. Both get caught by readers who check.

## The Document Lifecycle (the epic every paper goes through)

Every substantial document runs the same series. With a tracker, each stage is a card and the document is an epic — pair with the project-card skill for card structure and the project-ac-verify skill for independent close verification. Without one, keep the same stages in a checklist. Read [references/document-epic.md](references/document-epic.md) when setting up the epic — it has the card templates.

```
Frame → Research & Sourcing → Section Drafting (loop) → Multi-Lens Review → Independent Review → Author Sign-off
```

### Stage 1 — Frame (before any research)

Produce three artifacts. No research, no prose, until they exist:

1. **The question and the reader.** What is this document answering, for whom, at what altitude? Altitude is a testable constraint ("no tool names in the body"; "format specifics live in appendices only").
2. **The constraints block** — invariants that hold for every sentence, each with its check, mechanical wherever possible. Typical entries: no individual names; no vendor or product advocacy; terminology expansions consistent (one expansion per acronym, greppable); politically loaded terms identified and avoided; voice preservation rules when modernizing existing text.
3. **The claims-register skeleton** — what must this document establish? List the claims as check descriptions before researching any of them, the way you list test cases before coding. Read [references/claims-register.md](references/claims-register.md) for the format.

If sibling documents exist (a companion paper, a parent document), write the **division-of-labor map**: what each document uniquely owns, what this one must NOT restate. Boundary violations are review findings.

### Stage 2 — Research & Sourcing (RED for facts)

- Each research question is stated with **what would answer it AND what would refute the working assumption**. Research without falsification criteria is reading until you feel informed — the writing equivalent of tests that cannot fail.
- **Primary sources only for load-bearing claims.** Secondary sources are flagged as secondary and upgraded before the claim is used.
- **Cache sources at retrieval time** in a `sources/` directory (or equivalent) — the exact PDF, page snapshot, or file version the pin refers to. Sources move and change; your pin must not.
- Findings land in the register as **VERIFIED** (with pin), **REFUTED** (with pin — moved to the do-not-resurrect list so zombie claims cannot return through a later draft), or **OPEN**.
- **No claim enters the register from memory.** If you have not read the source in this working session, you have not verified it. "I remember" is never sufficient — sources change between sessions.

### Stage 3 — Section Drafting (the RED-GREEN-REFACTOR loop)

- **The section scope note is the failing test.** Before drafting a section, its skeleton entry states what the section must establish and from which register entries. If the scope note doesn't exist, write it first and get author agreement — that IS the red state.
- **Draft only from the register.** Every load-bearing sentence traces to a register entry. A new claim needed mid-draft is a hard stop: research it into the register first, then continue. (New behavior requires a new failing test first.)
- **Run the mechanical battery after every section**, not at the end. Incremental verification; never bulk-then-check.
- **REFACTOR under green:** once a section's claims are pinned and its battery passes, edit prose freely for voice, altitude, and flow. The pins hold the facts fixed while the words move. Re-run the battery after editing.

### Stage 4 — Multi-Lens Review

Independent review lenses over the complete draft, then deduplicate findings, then **adversarially verify every finding before applying it** — reviewer findings are signals, not instructions. The standard five lenses (citation re-derivation, consistency, constraints, source fidelity, reader experience) and the verify protocol are in [references/review-lenses.md](references/review-lenses.md) — read it when you reach this stage.

### Stage 5 — Independent Review

A fresh-context review with no investment in the draft — the document analogue of independent acceptance-criteria verification (see the project-ac-verify skill). If your environment supports subagent delegation, run it as a separate session; otherwise conduct it in the current session with the independence prompt from [references/review-lenses.md](references/review-lenses.md). The key requirement is independence of judgment, not a separate process.

### Stage 6 — Author Sign-off

Always last, never delegated, never skipped. The author decides terminology, positions, tone on sensitive points, and anything with legal, attribution, or distribution consequence. Present options with evidence; do not decide.

## Hard Rules (each one exists because the failure is real)

1. **Refute-first on convenient facts.** If a fact makes your argument stronger, it gets the adversarial check FIRST, before it enters the register. Convenient chronology claims ("we described X before X existed") are the highest-risk class — the flattering version is the one nobody double-checks, and a hostile reviewer will. The refutation attempt is cheap; retracting a published claim is not.
2. **Quote fidelity is the credibility strategy.** Quotes are verbatim, from the exact version cited, with the version stated. Never splice two sentences into one quote. Never quote a superseded edition's wording and attribute it to the current one. When paraphrasing, say so.
3. **Never weaken a check to make prose pass.** If a constraint blocks a sentence you want, the constraint wins or the author explicitly decides — same rule as "never weaken a test to make it pass."
4. **Preserve-as-authored.** Companion and quoted documents are never edited to agree with yours. If your document conflicts with a source you cite, fix your document or surface the conflict — never the source.
5. **Spike mode is legal; promotion is gated.** Drafting-to-think in scratch space is fine and often necessary. Nothing promotes from scratch into the document without register backing — spike, then stabilize, same as code.
6. **Author-owned decisions are presented, not made.** Terminology choices, softening of politically sensitive lines, how programs or organizations are characterized, distribution and attribution wording — collect the evidence, state a recommendation, wait for the call.
7. **Calibrate, don't hedge or inflate.** The register knows exactly how strong each claim is; the prose must say precisely that — no stronger (overclaim gets caught) and no weaker (needless hedging wastes verified strength).
8. **Internal notes are findings.** Editorial notes, positioning strategy, "how we'll frame this" commentary — anything that would embarrass if the document travels — must live outside the document. The constraints battery greps for known marker phrases.

## The Mechanical Battery

Accumulates like a regression suite; runs after every section, after every refactor, and before every handoff. Typical entries:

```bash
# Names and internal markers (list per document in the constraints block)
grep -icE "<name1>|<name2>|<internal-marker>" <doc>          # expect 0
# Term consistency — one expansion per acronym
grep -n "<Acronym> ?\(" <doc> | sort -u                       # expect one expansion
# Claim-strength drift
grep -n "released|shipped|implemented|planned" <doc>          # each hit matches its register rung
# Dead or local links
grep -nE "file://|localhost|/Users/|/home/" <doc>             # expect 0
# Every citation URL resolves; every pinned version still matches
```

Battery checks are per-document — the constraints block defines them at Frame time, and every new failure class found in review adds a check, permanently.

## Gotchas

- **Confirmation-bias drafting** is the test-after anti-pattern: prose first, then a search for supporting sources. It feels faster and finds only agreement. If you catch prose written ahead of its pins, stop and pin before continuing.
- **Fact-check-after tools are not this skill.** Post-hoc fact checking catches some fabrications after the fact; claims-first prevents them and also catches overclaim, drift, and boundary violations that fact-checkers do not look for.
- **A green battery is not a done document.** Mechanical checks bound the judgment problem; they do not solve it. Stages 4-6 exist because tier-two failures (altitude, persuasion, fidelity) are invisible to grep.
- **Version-pinned quotes go stale.** A document that cites "the current guide" inherits a freshness obligation — re-verify pins when a document is revived after months, exactly like re-running a test suite on an old branch.
- **Small edits still run the battery.** A one-word change can break term consistency or claim calibration. There is no edit too small to verify — the check takes seconds.

## Mode Split

**Full mode** (everything above): new documents, public-bound or externally-shared documents, anything making external factual claims, modernizations of existing papers.

**Lite mode:** mechanical edits to existing documents (typo, one-term consistency fix, link repair) need only the mechanical battery plus the claim-class check on any changed sentence. If a "mechanical" edit turns out to change a claim's meaning or strength, it is not mechanical — escalate to full.

Outward-facing documents are never lite. When unsure, full.
