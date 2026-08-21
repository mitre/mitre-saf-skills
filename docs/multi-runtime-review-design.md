# Multi-Runtime Review Architecture — Design Sketch

**Epistemic status: derived design reasoning.** This is synthesis — validated by
re-derivation and adversarial review, not by citation. Verified external facts it
borrows (Gastown mechanisms, the Five Eyes non-delegation rule) are cited inline;
everything else is design argument and should be challenged as such.

**Provenance:** split out of `docs/harness-research.md` on 2026-08-01 after a scope
review — that card (mitre-saf-skills-x6r.2) is findings-and-recommendation only,
and this design outgrew it. Motivated by a single, self-referential field event
(the harness-research correction loop, documented in that report as an n=1
illustration): two sessions on different models — the writer on Claude Fable 5,
the reviewer on Claude Opus 5 — corrected each other's errors with a human
relaying every message by hand. The design stands or falls on its reasoning, not
on that anecdote.

**Feeds:** ADR 0001 phases 1 (identity-separated gate resolution) and 3 (autonomy
dial), and proposes one candidate addition (the orchestrator role) for the ADR
owner's decision.

## The middleman, decomposed

"Middleman" bundles three roles the human played simultaneously in the field
event, and they resolve differently:

- **Transport** (moving messages) — needs no agent at all; shared board state
  replaces it.
- **Orchestration** (noticing work is ready, dispatching the review, routing
  iterations, judging convergence, triggering turns) — **a third agent.** This
  role already has names: project-goal's dispatcher operating at runtime, the
  "Orchestrator" of standard separation-of-duties vocabulary (SP 800-53 AC-5), and — as
  verified prior art — Gastown's Mayor (coordinator with workspace-wide context)
  plus Deacon (continuous patrol cycles). The discipline this design adds over
  Gastown's Mayor: the orchestrator routes, watches, and escalates but NEVER
  approves — it cannot resolve gates, cannot modify deliverables, cannot approve
  work it dispatched, and acts under its own registered identity with those
  denials enforced and logged. An orchestrator is also a new high-value
  manipulation target (it can flood or starve the review loop — the
  approval-fatigue attack with an agent-shaped delivery mechanism), which is
  precisely why it gets the denial battery rather than trust.
- **Authority** (approving outcomes, accepting risk) — stays human, per the joint
  Five Eyes rule: approval decisions are determined by designers/operators, "not
  delegated to the agentic AI system."

## The four-role square, with model-family diversity

Writer · reviewer (different runtime) · orchestrator · human authority — with the
substrate carrying state. **Assign the three agent roles across model FAMILIES,
not merely different models, where available**: same-lineage models can share
training-shaped blind spots, and the quiet failure mode is writer and reviewer
confidently agreeing on the same wrong thing while a same-family orchestrator
blesses the convergence. Family diversity matters most for the orchestrator for
exactly that reason — convergence-judging is where shared bias does its damage
undetected. Gastown's per-leg runtime selection makes this assignment first-class
(`gt formula run code-review --agent=gemini`; per-leg `agent` fields).

Caveat, carried honestly: diversity mitigates correlated failure, it does not
eliminate it — the N-version-programming literature found independently built
systems still fail together on hard inputs, and cross-vendor models share training
corpora. The human authority boundary exists partly because no diversity scheme
closes that gap.

## The protocol, on the board substrate

- **Dispatch:** the writer session claims the card, produces the deliverable,
  appends evidence notes, and marks it review-ready. It cannot resolve its own
  close gate — the sessions run as distinct bd actors (phase 1's identity
  separation, mechanical).
- **Review:** the reviewer session — pinned to a different runtime, and recording
  that runtime in its verdict — picks the card up from board state, reads the
  deliverable, the card contract, and ALL card notes, and appends a structured
  verdict note. Gate-resolution authority belongs to the reviewer identity or the
  human, never the writer.
- **Iteration:** refutation/correction rounds run as note exchanges on the card —
  what the human relayed by hand in the field event, now durable, ordered, and
  auditable by construction.
- **The human moves to the authority boundary, out of the message path:** 2b
  approval at close/merge plus escalations. Turn-triggering for interactive
  sessions remains human until phase 3's outcome-anchored auto-advance exists.

Pull-based coordination through board state also sidesteps the observed delivery
failure of push-based background agents (idle-without-report): no session depends
on a message arriving — each reads the card. This is Gastown's `ReviewOnly` +
`require_review` shape implemented on bd, with runtime independence enforced
rather than merely available.

## Context economy

Cross-family checking sounds like it requires copying large contexts between
vendors; the architecture requires the opposite. Contract-anchored review takes
three inputs: the card (contract), the deliverable, and the referenced design
source — O(deliverable + contract), never O(session). The field event illustrates
this (n=1): the reviewer worked from the report plus primary sources cold, with
none of the writer's session context, and caught what the writer missed —
plausibly *because* it did not inherit the writer's framing; copying full context
into a diverse reviewer re-correlates the two and buys the bias back. Context also
scales inversely with distance from the work: the orchestrator, the seat that most
wants family diversity, needs the least context of anyone — card states, verdict
summaries, round counts. Bounded packages double as the cross-vendor exposure
control: only the deliverable and contract cross a vendor boundary; the corpus
never does.

## Open questions

1. Orchestrator as ADR 0001 phase: candidate addition — owner's call.
2. Turn-triggering: what replaces the human's "go" for interactive sessions before
   phase 3's auto-advance lands, if anything.
3. Verdict schema for cross-runtime reviewers: ac-verify's structured output plus
   Gastown's severity rubric (harness-research pattern 5) is the natural merge.
4. Empirical test beyond n=1: run the writer/reviewer/orchestrator square on real
   cards and measure catch rates by role and family — feeds ADR phase 5
   calibration.
