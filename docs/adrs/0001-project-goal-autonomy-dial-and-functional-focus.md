# ADR 0001: project-goal — Per-Card Autonomy Dial and Functional Focus

**Status:** Proposed (2026-07-31)
**Decision owner:** Aaron Lippold
**Applies to:** `skills/project-goal` (dispatch layer), with prerequisites in `skills/project-tdd` / `skills/project-ac-verify` gate mechanics

## Context

`project-goal` is the dispatch layer of this skill stack: it reads an epic or plan,
classifies each work item, and binds it to its governing skill (code → project-tdd,
doc-system pages → project-docs, document deliverables → project-tdd document mode,
new cards → project-card, completion claims → verification-before-completion). Execution
today is uniformly attended: a human approves the generated goal prompt before it runs
(approach-level approval) and supervises every card at the same intensity regardless of
its risk.

Three findings motivate a change (see `docs/agentic-process-review-findings.md`):

1. **The enforcement layer is thin and one seam is open.** Of the stack's 22 quality
   gates, only two are mechanical (the bd close gate and the GitHub reopen Action);
   the rest are advisory and fail open. The TDD enforcement hooks
   (`docs/plan-tdd-enforcement-hooks.md`, card `mitre-saf-skills-4cp`, closed) mechanized
   the machine-checkable gates — but the writer of a card can still resolve its own close
   gate (finding F1). Increasing autonomy without closing that seam multiplies the
   throughput of a system that can grade its own homework.
2. **Passing mechanical checks is not correctness.** Published AIxCC analysis (Zhang et
   al., "SoK: DARPA's AI Cyber Challenge," arXiv:2602.07666, §7.4) found 38–46% of
   patches from general-purpose LLM-agent baselines that passed all automated checks
   still contained semantic defects. Auto-advance can therefore only ever key on outcome
   anchors, and judgment-heavy outputs keep an independent review layer at every
   autonomy level.
3. **Uniform attention is misallocated attention.** Mechanical, low-risk cards (config
   sweeps, research collection) consume the same human supervision as outward-facing,
   judgment-heavy cards. NIST AI RMF (AI 100-1) treats graduated autonomy (GOVERN 3.2)
   and containment/deactivation (MANAGE 2.4) as governance functions — autonomy level is
   something you route and govern, not a fixed posture.

A fourth, independent gap: classification today binds *process* (which skill) but not
*evaluative stance*. A work stream run in the wrong frame of mind reproduces the
self-review seam cognitively — a reviewer that drifts into authoring, a builder that
self-assesses risk. `package-audit` already enforces stance discipline locally ("emit
findings and stop — do not file cards until the user says to"), but stance is nowhere
declared or routed by the dispatcher.

## Decision

Extend `project-goal`'s classification to emit a **three-axis binding per card**, and
have the generated goal prompt carry the rules that make the bindings enforceable:

1. **Governing skill** (existing) — unchanged.
2. **Oversight level — the autonomy dial (new).** Classify each card by impact,
   exposure, reversibility, and data sensitivity into an oversight level: approach
   approval (2a), action approval (2b), or post-hoc review (3). The goal prompt states
   the auto-advance rule: a card may auto-advance ONLY on outcome anchors — its
   Verification command green, its close gate resolved by an identity other than the
   writer, its evidence archived — never on the executor's self-assessment. Outward-facing
   actions (push, publish, release, live settings) remain at action approval regardless
   of classification, preserving the existing hard guardrail. The dial ships with
   budgets (step/token), a circuit breaker, and asymmetric reclassification: demote to
   attended instantly on any gate FAIL; promote only after N consecutive clean cards.
3. **Functional focus (new).** The declared frame of mind for the work stream with
   respect to the end goal. Initial vocabulary, extensible by data: **feature-execution,
   code-review, risk-analysis, vuln-analysis**. Focus selects the stream's success
   orientation and its prohibitions (a code-review stream emits findings and never
   fixes; a vuln-analysis stream maximizes adversarial coverage and never "helpfully"
   mitigates in place). Focus is a control, not a hint: it is the cognitive-level
   analogue of identity-level separation of duties, and it prevents role-blur — the
   soft form of the writer-resolves-gate seam.

**Focus informs the dial.** The two new axes are coupled in one direction: functional
focus is classified first, because it changes the oversight-level calculus. Analysis
frames (risk-analysis, vuln-analysis, code-review) are propose-only by nature — they
emit findings and never mutate the target — so their blast radius is structurally low
and they can safely run at higher autonomy; feature-execution writes, and gets the full
impact/exposure/reversibility/data-sensitivity routing. Classifying focus before level
makes the level classification more accurate.

**Sequencing is part of the decision.** The autonomy dial ships only after
identity-separated gate resolution exists mechanically (F1's extension of the closed
4cp hook work). Functional focus has no enforcement dependency and can ship first —
and should, since its output is an input to the dial's classification (above).

## Alternatives Considered

1. **Do nothing (uniformly attended execution).** Safe; wastes human attention on
   mechanical cards; produces no field data on autonomy routing. Rejected as the steady
   state — but it remains the permanent fallback mode and the default for unclassified
   work.
2. **Add autonomy without enforcement hardening.** Rejected outright: the close gate is
   currently self-serviceable, so unattended throughput amplifies the open seam.
3. **Put autonomy in the executor (project-tdd) instead of the dispatcher.** Rejected:
   routing decisions belong where classification happens. Executor-side autonomy without
   per-card routing is a posture, not a control.
4. **Express focus as separate skills only (package-audit, a review skill, a vuln
   skill) without dispatcher declaration.** Partially exists today. Rejected as
   sufficient: stance must be BOUND to the stream at dispatch time, not discovered by
   the executor mid-stream.
5. **Adopt an external managed harness now (n8n or similar workflow engines).**
   Deferred, not rejected — carried as a research phase (below). The stack's policy
   layer is deliberately portable markdown; binding it to an orchestration engine is a
   larger architectural decision that should follow evidence, including study of
   **Gastown** (gastownhall — the beads authors' own multi-agent orchestration layer
   over the same beads substrate this stack already uses), per this repo's own
   adopt-before-build principle.

## Consequences

**Easier afterwards:** human attention concentrates where judgment lives; low-risk
streams stop queueing on supervision; every card emits calibration data (level, focus,
gate outcomes) that tunes the thresholds; the stack becomes a working reference
implementation of bounded task execution with graduated autonomy — directly reusable in
compliance-facing work.

**Harder / risks:** misclassification (mitigated: fail-safe default is attended/2b, and
reclassification is asymmetric); focus-vocabulary sprawl (mitigated: hold at four until
calibration data demands more); the dial is blocked behind real enforcement work, so the
visible payoff is not immediate.

**Unchanged:** the human owns all outward-facing actions; full-mode independent AC
review on judgment cards; the goal prompt remains a portable behavioral specification.

## Implementation Plan

**Quality standards (inherited by every card):** portability first — policy stays
markdown, no tool-specific delegation language (per `docs/SKILL-AUTHORING.md`);
framework-first — bd gates + the existing 4cp hooks are the enforcement substrate, no
new infrastructure; every card via project-card, executed via project-tdd (document mode
for prose deliverables); adopt-before-build for anything a researched platform already
provides.

**Phases** (each becomes a card via project-card):

1. **Identity-separated gate resolution** — the resolver of a card's close gate must be
   a different identity than the card's writer, enforced mechanically, extending the
   closed 4cp hook work. Prerequisite for phase 3.
2. **Functional-focus classification in project-goal** — the four-frame vocabulary,
   classification rules, per-focus prohibition blocks emitted into the goal prompt.
   No dependency; runs first — its output is an input to phase 3's level classification
   (focus informs the dial).
3. **The autonomy dial** — per-card oversight-level classification (consuming the
   phase-2 focus as a classification input), auto-advance rules keyed to outcome
   anchors, budgets, circuit breaker, asymmetric reclassification. Blocked by phase 1.
4. **Harness research** — evaluate managed orchestration substrates for this stack:
   Gastown (beads-native, same substrate) and workflow engines of the n8n class;
   deliverable is a findings report and a recommendation, not an integration.
5. **Calibration** — log level/focus/outcome per executed card; review after a fixed
   card count; tune thresholds and vocabulary from data.

### Status update — Phase 1 shipped, in a different shape (2026-08-11)

Phase 1 was written as *identity-separated gate resolution*: the resolver must be a
different identity than the writer. What shipped on 2026-08-09/10, and was corrected on
08-11, answers F1 by a different route — **evidence binding plus rationed self-service**
rather than identity separation:

| Phase-1 assumption | What exists |
|---|---|
| A second identity resolves the gate | The writer may resolve, but only against a reviewer verdict whose criteria and diff are SHA-256-pinned and **re-derived from the tree at resolve time** — any edit after review makes the PASS stale |
| Separation prevents self-approval | Separation is *cognitive and procedural*: `ac-review-prompt.sh` generates the reviewer's prompt and chooses its inputs, and `ac-review-agent-block.sh` denies any review the agent hand-wrote |
| (not specified) | Tiering: `human-gate` label, flap detection (≥2 FAILs), and a credit budget reserve the human key for the cases that need it |

Whether that is *sufficient* for F1 is a live question, and the honest answer is in the
gate's own header: the verdict artifact is written by a subagent, and no in-process scheme
can cryptographically distinguish its writes from the model's. The countermeasures are
detection, not impossibility. True identity separation still requires the CI topology
(reviewer as an isolated job with its own permissions), which is where the companion
harness ADR takes it.

**Correction to Phase 3's "budgets".** The budget shipped as a plain line count over a
ledger keyed on the agent session id, with no drain: it measured self-resolutions *ever
made* rather than *awaiting audit*, and the session id outlived both the audit and the
calendar day, so a spent budget wedged the following day's work on cards the owner had
already reviewed. Corrected to credit accounting — capacity returned by the human's
`ack`, keyed on `<repo>@<branch>`, with an actionable denial as the anti-wedge backstop.
Time-based alternatives (per-day key, rolling window, token bucket) were rejected: they
let the clock discharge an obligation only a human can discharge. Prior art, citations and
the rejected designs are in `hooks/ac-audit-ledger.sh`; the governance framing is in the
agentic-harness ADR under "What the budget actually counts".

**Consequence for this ADR's sequencing.** Phase 3 (the autonomy dial) was blocked behind
Phase 1. The enforcement substrate now exists and is tested (30 cases, three suites), so
the block is lifted in practice — but the dial's own budgets should adopt the same
discipline the correction establishes: **state the exhaustion behavior as part of the
control**. A budget whose behavior at zero is undefined does not fail safe; it wedges, and
this one did.

## References

- `docs/agentic-process-review-findings.md` — F1 (gate-resolution seam), three-layer
  classification, mechanical-vs-advisory gate census
- `docs/plan-tdd-enforcement-hooks.md` + card `mitre-saf-skills-4cp` (closed) — the
  shipped mechanical-enforcement layer this ADR builds on
- Zhang et al., "SoK: DARPA's AI Cyber Challenge (AIxCC)," arXiv:2602.07666, §7.4
- NIST AI 100-1 (AI RMF 1.0), GOVERN 3.2, MANAGE 2.4
- Gastown — gastownhall's multi-agent orchestration over beads (research phase input)
