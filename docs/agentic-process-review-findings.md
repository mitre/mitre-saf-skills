# Agentic Process Review — Card-Ready Findings

**Status:** Findings for triage — no cards filed (per package-audit convention: present findings; the owner decides what to card)
**Date:** 2026-07-31
**Scope:** The skill set reviewed as a human-in-the-loop agentic development process — classification against an agentic/autonomy framework, mapping against published agent-security guidance (Five Eyes *Careful Adoption of Agentic AI Services*, OWASP *Securing Agentic Applications*, NSA MCP CSI, NIST NCCoE agent-identity concept paper), and empirical validation of gate outcomes queried from the live issue tracker. Full analysis retained privately; this document carries the actionable findings only.

## Review verdict (context for the findings)

The skill set is accurately described as a **human-in-the-loop agentic development process whose assurance mechanisms are deliberately workflow-shaped** — non-deterministic execution, deterministic gating. Execution under project-tdd meets every agentic criterion (output executed against compilers/tests/linters/live apps; the model observes results and chooses next actions; variable step count; goal and termination). Human checkpoints are real and non-decorative, and the process leaves a queryable audit trail that shows its controls both working and failing.

Two structural facts frame every finding below:

1. **Exactly two controls are mechanical** (the `bd gate` close-block and the GitHub reopen Action). The other ~23 are prompt-level instructions that fail open if the model does not comply.
2. **The process is human-triggered and single-session.** No standing authority, no event-driven operation, no managed harness. (This matches the author's own assessment; the findings below are the concrete delta.)

Empirical basis (aggregate, from the live tracker): across ~276 gate issues, **231 closed cards satisfied their verification gate; 11 closed with the gate still open (~4.5% leak, concentrated in a single project's board); at least 20 gates record one or more FAIL rounds that forced rework before PASS** — including one case where an implementing agent's fix introduced a defect that the agent's own newly-written test certified as correct, caught only by the independent reviewer. The gate is not theater, and the leak rate is measurable.

---

## Findings

### F1 — Mechanize the machine-checkable gates *(corroborates and extends `plan-tdd-enforcement-hooks.md` / card 4cp)*
**Priority: High · Effort: Medium**
The existing enforcement-hooks plan (2026-06-25) reached the same root cause independently confirmed by this review: prose gates are advisory. Extend the plan's three layers to cover checks it does not yet list, several of which are one grep away:
- `git diff ⊆ Files:` scope check (the card's authorized-write-scope close check, currently manual)
- new linter-disable count = 0 (Gate 20)
- compiler/typecheck clean (Gate 10)
- `[AC-VERIFY PASS]` stamp presence validated at close time (mechanical form of Gate 22's stamp convention)
**AC seeds:** each check exists as a standalone script usable in CI and pre-commit; failures block with the gate's "why this exists" message; checks are convention-configurable per project.

### F2 — Separate gate resolution from the implementing session (writer ≠ resolver)
**Priority: High · Effort: Medium-High**
Today the implementing session spawns the reviewer, reads the verdict, and resolves the gate itself. Writer≠approver holds by policy, not by architecture — nothing mechanical prevents resolving without a PASS. Direction: gate resolution moves to the verifier's process (or a separate credential); interim hardening: the resolve reason must embed a hash of the PASS verdict artifact so a resolution without a matching verdict is detectable after the fact.
**AC seeds:** the implementing session cannot resolve its own card's ac-verify gate; a resolution without a verifiable PASS artifact fails or alerts; documented on both substrates (beads + GitHub).

### F3 — Formalize control-effectiveness metrics and leak monitoring
**Priority: High · Effort: Low-Medium**
The data already exists in the tracker; nobody computes it routinely. Metrics: FAIL rate, rounds-to-PASS, force-bypass count, and a **closed-with-open-gate detector** (the 11 known leaks would have been caught the day they happened by a scheduled query). Include a one-time investigation of the known leak cluster and either backfill verification or annotate the affected closes.
**AC seeds:** a scheduled check (CI or cron) reports the four metrics per board; a closed-card-with-open-gate condition alerts within a day; the historical leak cluster is dispositioned.

### F4 — Bind policy version to work items
**Priority: Medium-High · Effort: Low**
Skills are live-edited working copies; a card closed in May cannot be audited against the May policy that governed it. Direction: Gate 0 records the skill-set commit hash (or version) on the card/gate at start.
**AC seeds:** every new card carries the governing policy version; the ac-verify stamp includes it; documented recovery answer for "which rules applied to this card?"

### F5 — Publish/working-copy drift needs a release process
**Priority: Medium-High · Effort: Medium**
The installed working copies are materially ahead of the published repo (entire mechanisms — lite mode, the GitHub gate substrate, several gate clauses — exist only in working copies). Anyone adopting from the public repo gets a weaker process than the one actually validated.
**AC seeds:** versioned releases with changelog; a defined sync cadence; README states which version is current; divergence between installed and published copies is detectable by script.

### F6 — Independent risk-tier classification (lite/full guardrail)
**Priority: Medium · Effort: Medium**
The lite/full guardrail depends on the agent correctly classifying its own card as security-sensitive/outward-facing — the classifier and the classified are the same process. Escalation is announced (good) but never independently checked.
**AC seeds:** a deterministic ruleset (labels, paths, repo class) computes the tier alongside the agent's self-assessment; disagreement forces FULL; the ac-verify reviewer confirms tier appropriateness as a verdict field.

### F7 — Standing triggers using existing gate primitives
**Priority: Medium · Effort: Medium**
`bd gate create --type=gh:run --await-id=<run>` and `--type=gh:pr --await-id=<n>` can bind gates to CI runs and PR merges today; only `--type=human` is used. This is the smallest step from "human-triggered per task" toward event-driven operation — without building any new infrastructure.
**AC seeds:** at least one workflow demonstrates a gate auto-resolving on a passing CI run and one on a PR merge; documented pattern in the relevant SKILL.md.

### F8 — Agent-instruction supply chain (adopted skills)
**Priority: Medium-High · Effort: Medium**
`create-skill` mandates adopt-and-adapt from a public marketplace with install count as the trust signal, but the 9-dimension audit applies only to *authored* skills. Installing a skill installs instructions that steer an agent with write access — an unsigned executable-policy channel.
**AC seeds:** adopted third-party skills pass the same audit before enablement; source commit pinned and content-hashed at install; a re-audit trigger fires when the upstream changes (the "capability drift" case).

### F9 — Measure gate firing, not just gate outcomes
**Priority: Medium · Effort: Low-Medium**
Only gate *resolution* outcomes are recorded. Whether a prose gate actually fired during a session — especially under context degradation, which the skills themselves treat as unmeasurable from inside — is unknown. Lightweight direction: per-gate checklist stamps in card notes (or a session log line per gate) so "never fires" and "always passes" become distinguishable.
**AC seeds:** at least the high-stakes gates (4, 10, 11, 18, 20) leave a per-card firing record; a report distinguishes fired-and-passed / fired-and-caught / no-record.

### F10 — Convention epochs in the audit trail
**Priority: Low · Effort: Low**
Gates closed before the `[AC-VERIFY PASS]` stamping convention carry self-verified reasons without stamps; uniform-application claims across the corpus would be false. Direction: document the convention epoch boundary (date/board) so per-period claims are auditable; optionally annotate pre-epoch closes.
**AC seeds:** a dated convention history exists; queries can segment by epoch.

### F11 — Verify the behavioral-research citations
**Priority: Low · Effort: Low**
`project-tdd`'s frustration-error-loop reference cites external research (sycophancy evaluation figures, context-rot findings, a CoT-masking arXiv ID) that this review did not verify — and at least one arXiv ID pattern warrants a careful check before any external-facing document repeats it. The controls stand on their operational record either way; the citations are load-bearing only if quoted.
**AC seeds:** each citation resolves to the claimed work; figures match the source; any that fail are corrected or removed.

### F12 — Containment additions (aspirational; smallest useful subset)
**Priority: Medium · Effort: High**
The process contains by narrow authority (no outward action without explicit human request) but has no containment *machinery*: no scoped per-session credentials, no workspace isolation from the developer's own tree, no documented stop/rollback procedure. Full managed-harness containment is out of scope for a skills repo; the smallest useful subset is not.
**AC seeds:** worktree or container isolation documented as the recommended execution mode for TDD sessions; a written stop-and-revert procedure (identity/session-keyed) exists and has been exercised once.

---

## Strengths the improvements must not regress

Recorded so the carding agent treats them as constraints, not gaps: gate-created-at-start (fail-closed default) · reviewer bias set to "no investment, default to FAIL" · verify against the design source, never the card's paraphrase · structured JSON verdict with per-AC evidence · read-only bounded verifier · asymmetric bypass by substrate (auditable on beads, none on GitHub) · the label-not-checkbox anti-loop lesson · risk-tiered assurance with announced, never-silent escalation · measured relaxation (lite mode) with a written basis and stamped closes · `First failing test` as an executable acceptance criterion fixed before work starts · explicit anti-Goodhart clauses · portability of the policy layer across agent runtimes.
