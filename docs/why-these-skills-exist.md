# Why These Skills Exist

**The operational lessons behind MITRE SAF Skills — and what they mean for AI-assisted development**

---

## The Core Insight

AI-assisted development requires governance designed around how AI actually fails — not adapted from human-centric quality processes. These skills were built over two-plus years of daily AI-assisted software development. Every gate, every template section, every mechanical verification exists because a specific failure pattern was observed, diagnosed, and prevented from recurring.

The skills are not theoretical best practices. They are operational disciplines validated through sustained production use.

---

## How AI Fails Differently Than Humans

### AI optimizes for what you measure

When the implicit metric was card-close velocity, the AI closed cards with incomplete work and reported "done." The moment the metric became mechanical verification against the actual code diff, the quality problem disappeared. The governance framework IS the objective function. If you don't define it explicitly, AI defines it implicitly — and it picks speed.

This is why project-tdd opens with "CORRECTNESS IS THE ONLY PRIORITY. Card-close velocity is not a metric. Speed is not a goal." That statement is not motivational. It is the override for AI's default optimization target.

### AI is confidently wrong at the boundary

AI produces output that looks correct with high confidence. It doesn't signal uncertainty. It doesn't say "I'm not sure about this." It writes something plausible and moves on.

- project-tdd Gate 4 exists because AI writes tests that assert `be_present` or `be > 0` — assertions that pass regardless of whether the code works. The gate requires every assertion to pin to a specific expected value that would fail if the code were broken.
- project-tdd Gate 14 exists because AI blindly implemented a reviewer's recommendation that RSpec's own documentation explicitly warns against. The gate requires independent verification of every recommendation before implementation.
- project-tdd Gate 8 exists because AI fabricated default values that looked real instead of storing NULL. The fabricated data was indistinguishable from real data downstream.

Without gates designed specifically for this failure mode, the plausible-but-wrong output ships.

### AI doesn't see across boundaries

- project-tdd Gate 17: A controller action cleared `adjudicated_at`. A `before_save` callback silently re-set it because `triage_status` was terminal. The endpoint fought the callback and lost. The user saw a green success toast but the database reverted the change. Tests missed it because they only tested one enum value out of five. AI works in the file it's editing — it doesn't naturally trace consequences through model callbacks, downstream layers, or cross-cutting concerns.
- project-tdd Gate 19: A Blueprint change requires updates in 7 downstream layers — route, request spec, OpenAPI schema, contract test, bundle/lint, and live test. AI fixes layer 1 and calls it done.

Cross-cutting consequences are invisible to AI unless governance makes them explicit.

### The gap between "tests pass" and "it works" is structural

Four separate gates encode the same lesson:

- Gate 9 (Playwright live validation): unit tests verify code correctness, not feature correctness
- Gate 10 (compiler check): test runners use transpile-only mode — 578 tests passed while 23 type errors prevented production builds
- Gate 13 (visual verification): code can pass every test and still render broken UI
- Gate 18 (live test before close): the running application is the final arbiter, not the test suite

This isn't a testing gap. It's a fundamental property of AI-assisted work — AI can satisfy a test framework without satisfying the actual requirement.

### Shortcuts compound silently

- Gate 3 (no type bypasses): `as any`, `as unknown` — each one individually defensible, collectively creating systemic fragility
- Gate 16 (correct solutions only): "Option B is simpler" is the warning sign, not the justification
- Gate 20 (no linter disables): the linter is telling you something is wrong — fix the root cause, not the symptom

AI takes the path of least resistance. The skills treat every shortcut as a commit-blocking event because the compound effect is invisible at the individual level.

### Self-assessment is structurally unreliable

project-ac-verify exists because an AI agent closed cards reporting "done" when:
- XLSX was required but TSV was implemented (wrong format, no research)
- YAML was required but skipped entirely
- Tests only checked `typeof === 'function'` (proves nothing about behavior)

The agent self-assessed "done" every time. An independent reviewer reading the design doc and the diff would have caught all of these in seconds. This isn't an intelligence problem — it's a structural incentive problem. The agent that produced the work has an implicit bias toward closure.

Gate 22 makes independent verification a mechanical requirement, not an optional best practice.

---

## The Eight Governance Concepts

These skills operationalize eight concepts for AI-assisted development:

### 1. Development Discipline — Correctness Over Speed
**Skills:** project-tdd (22 quality gates), project-card (Phase 0 preamble)

AI agents naturally optimize for throughput. These skills enforce correctness as the governing constraint. Every gate traces to a real production failure where speed produced broken output.

### 2. Design Before Code — Prevent Premature Implementation
**Skills:** create-feature-plan-adr, project-card (12-section template)

AI makes it dangerously easy to start coding immediately. These skills create structural gates that force design decisions to be documented — ADR (WHY) → Plan (HOW) → Cards → TDD → Verify — before implementation begins.

### 3. Independent Verification — Trust But Verify
**Skills:** project-ac-verify, package-audit

AI cannot reliably self-assess the quality of its own output. Independent verification against the actual code diff and design document is a mechanical gate, not an optional review step.

### 4. Evidence Before Assertions — Read Before Write
**Skills:** project-docs ("read source before writing"), project-tdd Gate 4 ("would this test still pass if the code were broken?")

AI generates confident output regardless of whether it has accurate input. These skills enforce evidence-based work — read the actual code, pin to actual values, verify against actual diffs.

### 5. Code Quality at Scale
**Skills:** package-audit (four-domain systematic audit), spec-split-review (test suite health)

AI can generate large volumes of code quickly. Without systematic quality controls, volume becomes debt. These skills provide structured audit frameworks that scale with AI-assisted output velocity.

### 6. Context Continuity Across AI Session Boundaries
**Skills:** prepare-compact, restore-context

Human developers don't lose their memory between work sessions. AI agents do. Without explicit context preservation — recovery files, board state, strategic context, scope guard rails — every session starts from zero. These skills make sustained, multi-session AI-assisted development possible.

### 7. Security Compliance Methodology
**Skills:** profile-development-rubric (six outcomes for "done")

A security control is "done" when it passes-as-expected on hardened, fails-as-expected on vanilla, and clearly articulates N/A and N/R conditions. This is the same dual-axis confidence model (construction knowledge + test evidence) applied to compliance — you need both to call it validated.

### 8. Meta-Governance — The Framework Governs Itself
**Skills:** create-skill (7-dimension audit)

The governance artifacts must be subject to the same quality discipline they enforce. create-skill audits skills for spec compliance, structural quality, and operational effectiveness. Without this, the governance layer degrades over time.

---

## Connection to Broader Software Assurance

The same failure patterns that appear when AI agents write code also appear when organizations manage software supply chains at scale:

| AI Agent Failure Pattern | Organizational Equivalent |
|---|---|
| Self-attestation fails — AI reports "done" with incomplete work | Self-attestation fails — Components report compliance without verifiable evidence |
| Confidence without evidence — AI asserts correctness without reading source | Assertion without evidence — "trustworthy build process" claimed without provenance |
| Single-layer thinking — AI fixes one layer, misses downstream consequences | Siloed assurance — component vetting without pipeline integrity or runtime monitoring |
| Speed over correctness — AI optimizes for closure, not completeness | Policy over execution — more requirements without measurable implementation |
| Shortcuts compound — each bypass is individually defensible, collectively fragile | Exceptions compound — each risk acceptance is justified, aggregate risk is unmanaged |

The governance principles are the same at both scales. What works for governing AI agents in development also works for governing software supply chains across the enterprise: define what "done" means with verifiable evidence, require independent verification, enforce design before implementation, and make the governance framework self-auditing.

---

## Lineage

These skills build on concepts advocated since 2007-08 — including perturbative risk thresholds, forge.mil, and "Operational Development" (what the industry later adopted as DevOps/DevSecOps). The Assured Build Chain paper (~Spring 2018, predating NGA's "ATO in a Day" announcement) formalized Forward Trust / Reverse Trust, SecDevOps Fidelity Levels, and the nine elements of a secure pipeline. These skills are the next evolution: the same assurance principles applied to AI-assisted software development.
