# Orchestration Harness Research — Gastown and the n8n Class

**ADR 0001 phase 4 deliverable (card mitre-saf-skills-x6r.2). Findings and recommendation
only — no integration. Researched in-session 2026-08-01 from primary sources; retrieval
notes at bottom.**

*Terminology: "harness" in this document means an **orchestration engine** — the
Gastown/n8n class evaluated here. It is distinct from the development-loop scaffold
(the skills, cards, and gates this repository defines), which some notes also call a
harness. Where both appear, name them explicitly.*

## Question

Should this skill stack adopt a managed orchestration harness — Gastown (the beads
authors' multi-agent layer over the same beads substrate our gates use) or a workflow
engine of the n8n class — and if so, as platform or as pattern source? The recorded
hypothesis under test: *"n8n-class for triggers/routing/escalation at the edges; beads
for state; markdown skills for policy; agents for execution."*

## Findings: Gastown

Source: github.com/steveyegge/gastown README (gastownhall org), retrieved 2026-08-01.
Scale signals: ~17.4k stars, ~7,770 commits, Docker Compose + OpenTelemetry, v1.0
April 2026.

**Architecture.** A role-structured agent workforce over beads: the **Mayor** (primary
AI coordinator, a Claude Code instance with workspace-wide context), **Polecats**
(worker agents, "persistent identity but ephemeral sessions"), **Crew** (the human's
own workspace), **Witness** (per-rig lifecycle manager: monitors polecats, detects
stuck agents, triggers recovery), **Deacon** (background supervisor on continuous
patrol), and the **Refinery** (per-rig merge queue). Work travels as **convoys**
(bundles of beads) assigned via `gt sling <bead-id> <rig>`; all work state lives in
the beads ledger.

**Answers to our open design questions:**

1. *Writer/verifier separation:* **both structural AND judgment-level** *(corrected
   2026-08-01 after source reading — see Correction below)*. Structurally, "polecats
   never push directly to main": the Refinery batches merge requests, runs
   verification gates, and merges via a Bors-style bisecting queue (green: batch
   merges; red: bisect to isolate the failing MR). On top of that, Gastown ships a
   judgment-review layer the README does not surface: a `review` command ("Review
   code changes with structured grading (A-F)") whose instruction set defines a
   CRITICAL/MAJOR/MINOR severity rubric with "Grade is determined by the highest
   severity issue found" (A/B pass, C/D fail, F unreviewable), tool-bounded to diff
   reading (`git diff`, `git rev-parse`, `gh pr diff`); a `ReviewOnly` dispatch mode
   ("assignee must evaluate and report back — no merge/commit/push"); and the
   verdict wired into the merge queue — "Refinery enforces require_review=true —
   blocks merge until PR approved." That is ac-verify's shape, with mechanically
   STRONGER verdict enforcement than our bd gate. What remains genuinely distinct is
   the review's SUBJECT: Gastown's rubric grades code quality from the diff
   (correctness, security, error handling, API compliance, test coverage); ac-verify
   verifies acceptance-criteria completeness against the originating card and its
   referenced design source. Same control class, different anchor — the honest
   complement is contract-anchored verification, not the existence of judgment
   review.
2. *Identity and attribution:* persistent polecat identity across ephemeral sessions,
   plus **Seance** — agents discover predecessor sessions via `.events.jsonl` logs and
   can query prior context and decisions. Attribution at the work-tracking level
   exists; cryptographically anchored identity — an agent's actions bound to a
   verifiable principal rather than to a tracker handle — is beyond what the README
   documents.
3. *Work claiming:* convoy assignment (`gt sling`) is push-assignment onto rigs,
   compatible in spirit with `bd claim`; same substrate, so semantics translate.
4. *Containment/lifecycle:* the **Witness/Deacon watchdog chain** (stuck detection,
   recovery, session cleanup, patrol cycles) is exactly the operational containment
   machinery our stack lacks — and the strongest single pattern candidate below.
5. *Oversight routing / functional focus:* no equivalent to ADR 0001's oversight dial
   as a **routing function** over risk dimensions, nor to focus classification. But
   partial overlap exists and the first draft of this row overstated its absence:
   `ReviewOnly`, `NoMerge`, and `require_review` are per-work-item oversight
   settings. The honest claim is that Gastown carries per-item oversight *flags*
   where the ADR proposes a *derived* routing decision — cruder, not absent.
   **Flagged deliberately:** this is the same shape of negative existence claim as
   the one refuted below, drawn from the same README-level reading. Treat it as
   provisional until the scheduler and dispatch paths are source-read.

## Findings: n8n class

Sources: docs.n8n.io Wait-node and AI-Agent-node pages, retrieved 2026-08-01 (the
Advanced AI overview page was not retrievable — see method note).

- **Human-in-the-loop:** the **Wait** node pauses execution with four resume modes —
  *After Time Interval*, *At Specified Time*, *On Webhook Call* (authenticated:
  Basic/Header/JWT), *On Form Submitted* — with *Limit Wait Time* fallbacks. This is
  a real, durable approval-gate primitive: pause-until-authorized-resume with
  timeout behavior, usable for 2b-style action approval at workflow boundaries.
- **Agent execution:** the **AI Agent** node (Tools Agent) connects a chat model plus
  one or more tool sub-nodes; the agent chooses tool calls. The judgment work still
  happens in the model + prompt — the engine contributes durability, retries, and
  wiring, not quality machinery.
- What the class provides overall: durable triggers, credential vaulting, retries,
  connector ecosystem, and inspectable flow definitions. What it cannot absorb
  without duplicating policy: the skills' gates, TDD process, independent review —
  those live in prompts and the enforcement substrate regardless of engine.

## Hypothesis verdict

**CONFIRMED for the n8n class, with a refinement for Gastown.** An n8n-class engine
earns its place only at the edges (triggers, notifications, durable approval waits,
credential handling); moving control flow into flow JSON would create a second source
of process truth that drifts against the markdown skills — the policy layer must stay
where it is. Gastown, however, partially escapes the "second source of truth"
objection because it is beads-native: its control plane IS our state substrate. The
objection that remains for Gastown is scale and coupling, not architecture: it is
built for 20–30-agent fleets, our working mode is one attended agent plus
explicitly-ordered panels, and its velocity is high.

## The "harden the harness, not the LLM" question (open — this evidence informs it)

Both platforms place **all** of their security and reliability value in the harness
layer — merge queues, verification gates, watchdogs, approval nodes, credential
vaulting — and none in the model. That supports the harness-side of the supposition:
the *enforceable* controls live in the harness.

Gastown pushes the line further than this report first assumed. Judgment review is
not inherently outside the harness class: Gastown seats a grading reviewer *inside*
the harness and wires its verdict to the merge gate (Findings §1). "The harness
cannot do judgment" is therefore not the boundary — though the n8n class does stop
at execution machinery, so this is one member of the class, not the class.

The AIxCC SoK data cuts at a different joint than first read. It measures patches
that passed **automated** checks; Gastown's reviewer sits above automated checks.
So that data is the argument *for* a judgment layer over automation, not evidence
that the harness cannot host one.

What the harness class does not supply is the **anchor**. Gastown's reviewer grades
a diff on its own merits, with no access to the acceptance criteria or design intent
the change was meant to satisfy. Balanced reading this research supports: **the
harness is where controls are enforced, and judgment review can be seated there too;
what stays outside is the contract that judgment is anchored to. Hardening must cover
the harness mechanism and the anchoring both.** The question stays open for the
overlay work, now with evidence on one flank.

## Recommendation: ADOPT-PATTERNS. Defer platform adoption.

Adopt as patterns (in ADR 0001's existing phases, no new machinery):

1. **Never-direct-push + review-gated merge boundary** (Gastown Refinery) — the shape
   phase 1's identity-separated gate resolution should take: `require_review=true`
   blocking merge until an approving review exists, with the `ReviewOnly` dispatch
   mode (evaluate and report back; no merge/commit/push) as the reviewer's authority
   boundary. Separation enforced mechanically, not by instruction.
2. **Witness/Deacon-style watchdog** (Gastown) — the containment prerequisite for
   phase 3's autonomy dial: budgets, breaker, stuck-detection, and demotion need an
   observer process, not just rules text.
3. **Seance-style session archaeology** (Gastown) — phase 5 calibration: outcome
   history discoverable by successor sessions; our bd notes + archives already
   approximate this, worth formalizing.
4. **Durable authenticated approval-wait** (n8n Wait node) — the pattern for any
   future externally-triggered 2b gate; edges only.
5. **Severity-rubric grading + per-leg runtime independence** (Gastown `review` +
   formulas) — the CRITICAL/MAJOR/MINOR → A–F scheme with "grade is determined by
   the highest severity issue found" maps cleanly onto ac-verify's structured
   verdict. And the model-independence property is real, via formulas rather than
   the review command: `gt formula run code-review --agent=gemini`, with a
   documented precedence chain (per-leg `agent` field in formula TOML → `--agent`
   CLI flag → formula-level `agent` → rig/town default agent;
   `internal/cmd/formula.go`, `internal/formula/types.go`, both tagged GH#2118). A
   formula can run its writing leg on one model and its review leg on another.
   Precision matters: this is architecturally AVAILABLE, not enforced — nothing
   compels the review leg to differ. That is still more than ac-verify has, where
   the reviewer is same-model, same-session, and spawned by the writer. If
   this pattern is adopted, enforce what Gastown makes available: require the
   reviewer's runtime to differ from the writer's.

Defer adopting either platform. Rationale: Gastown solves fleet-scale coordination we
do not have today, at high development velocity, and coupling the portable-markdown
policy layer to a fast-moving runtime contradicts the stack's portability contract;
n8n-class adds a second process-definition layer for benefits we do not yet need.

**What would change the call:** (a) a real need for >3 concurrent worker agents on
one repository — re-evaluate Gastown first, since the substrate already matches;
(b) phase 1 discovering that bd-gate mechanics cannot enforce identity-separated
resolution without a merge-queue-style boundary — adopt pattern 1 with Gastown's
implementation as the reference; (c) a requirement for scheduled/external triggers
with human approval waits — adopt pattern 4 at the edge, engine choice then open.

## Correction (2026-08-01, same day)

The first issue of this report claimed Gastown has "no independent judgment-reviewer
role." An independent review of this report refuted that from source, and
verification against the repository confirmed the refutation: `internal/templates/
commands/bodies/review.md` (severity rubric, A–F, highest-severity rule),
`internal/templates/commands/provision.go` (the `review` command, diff-bounded
tools), `internal/beads/fields.go` (`ReviewOnly`), and `internal/cmd/info.go`
(`require_review=true` merge blocking) — quotes now incorporated in Findings §1.
One sub-claim of the refutation — reviews dispatchable to a different model —
initially failed to verify at the first-cited paths (the `/review` command has no
agent selector) and was then CONFIRMED at the correct mechanism on a second pass:
formula legs carry per-leg agent overrides (`internal/cmd/formula.go`,
`internal/formula/types.go`; pattern 5), architecturally available though not
enforced. Method failure recorded plainly: the original
negative existence claim was drawn from the README alone while this report's own
method note disclosed that internals were unread — a disclosed limitation does not
license a load-bearing negative. The corrected finding is more useful, not less: a
production system has solved judgment review onto a mechanical merge boundary with
enforcement stronger than ours; the gap it leaves is contract-anchored (acceptance
criteria + design source) verification, which remains this stack's distinct
contribution.

**Second-pass correction, same day.** The first correction fixed Findings §1 but left
the "harden the harness" section asserting the refuted premise — "neither platform
ships the independent judgment-review layer" and "judgment review is a control the
harness class does not provide" — three sections below the correction that
invalidated it. Caught by the same independent reviewer. That section is now
rewritten to the corrected reading, and the conclusion changed with it: the boundary
is not whether the harness can host judgment, but what that judgment is anchored to.
Lesson recorded alongside the first: **a correction is not complete until every
downstream claim resting on the refuted premise has been re-derived.** Fixing the
finding and leaving its consequences standing is the same defect one level up.

## Field example: the two-runtime review loop that produced the correction above

This report's own correction cycle, as it actually ran (2026-08-01). Recorded as
an **n=1, self-referential illustration** — the report participated in the event
it describes — not as evidence for any recommendation it makes:

1. **Writer** (this session — Claude Fable 5, the primary author) published the
   report with a confident negative: "no independent judgment-reviewer role" in
   Gastown, derived from README-only reading against the report's own disclosed
   limitation.
2. **Reviewer** (an independent session — Claude Opus 5, a different model with no
   shared context) refuted the headline from source, citing five specific
   repository locations.
3. **Writer verification** confirmed four citations verbatim and found the fifth
   (`review --agent=...`) absent at the cited paths — right in substance,
   mis-located in citation.
4. **Reviewer second pass** supplied the correct mechanism (formula per-leg agent
   overrides), which the writer verified verbatim before incorporating.
5. The correction was recorded in place with the full audit trail; the card's close
   gate stayed open throughout, so the wrong finding never became a closed record.

Properties illustrated — once, in the event above: **runtime-independent review**
(pattern 5's property — writer and reviewer on different models caught different errors;
honest limit: both models are the same family, so shared-lineage blind spots were
not controlled for — see the family-diversity note below);
**bidirectional verification** (the reviewer caught the writer's false negative;
the writer caught the reviewer's mis-located citation); **fail-closed gating** (open
gate = no wrong finding closed). The one weak link: **the human was the transport
layer** — every message between the two sessions was relayed by hand.

### Design follow-on (split to its own deliverable)

The question this example raises — how two sessions coordinate without the human
as transport — outgrew this card's findings-and-recommendation scope. The design
work lives in **`docs/multi-runtime-review-design.md`** (its own card): the
middleman decomposed into transport/orchestration/authority, the four-role square
(writer / reviewer / orchestrator / human authority), model-family diversity
across roles, the board-substrate protocol, and the context-economy argument.
That document is derived design reasoning and is labeled as such; this report
remains findings and a recommendation.

## Method note

Researched in the main session (no subagents, per standing directive). Primary
sources: the Gastown README via github.com/steveyegge/gastown (gastownhall org) and
docs.n8n.io node documentation, all retrieved 2026-08-01. Orientation-level facts
(release timeline, star counts) corroborated by search results but load-bearing
claims are cited to the README/docs only. Limitation: docs.n8n.io's Advanced AI
overview pages returned 404 to the fetcher; the Wait-node and AI-Agent-node pages
retrieved cleanly and carry the claims used here. Gastown internals were partially
source-read on 2026-08-01 during the correction (the four files cited there, via
raw.githubusercontent.com); the Refinery's implementation beyond those files remains
unread — if pattern 1, 2, or 5 is adopted, read the implementation first.
