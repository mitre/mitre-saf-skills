---
name: project-tdd
description: TDD with quality gates learned from production audits. Use for ALL development. Builds on /test-driven-development with project-specific gates. Two modes — full (default, independent AC review) and lite (self-verified evidence, for mechanical cards on small utility repos). Cards may live on beads (bd IDs) or GitHub Issues (owner/repo#N). Invoke as /project-tdd [lite|full] <card-id | owner/repo#N>.
argument-hint: "[lite|full] <card-id | owner/repo#N | #N>"
compatibility: Requires beads CLI (bd). Gates reference multiple stacks.
license: Apache-2.0
---

# Project TDD Quality Gates

**Prerequisite:** This skill builds on `/test-driven-development`. Follow the base TDD cycle (Red-Green-Refactor) exactly. This skill adds quality gates that catch patterns found in real production audits.

**Card substrate:** the card reference determines where the card lives — GitHub Issue
(`owner/repo#N`, issue URL, or `#N` inside a repo clone) or beads (bd-shaped ID). Every
gate and rule below applies identically on both. The bd commands shown are the beads
forms; the GitHub equivalents (gh CLI only) for Gate 0, notes/evidence, the close
protocol, and the `gate:ac-verify` label that replaces `bd gate` are in
**`references/github-substrate.md`** — read it before working a GitHub card.

**Card stack:** when the card's deliverable is PROSE (documentation or AI-research-writing
work), every gate still applies — the evidence types translate. Read
**`references/document-mode.md`** before executing such a card: the failing test is a named
defect (review finding / change-contract item), RED = demonstrate the defect exists before
editing, Gate 10's mechanical floor = the card's grep gates, Gate 18 = primary-source
re-verification. Prose has no compiler, so the verification gates matter MORE, not less.

## Mode Selection — full (default) vs lite

Invocation: `/project-tdd [lite|full] <card-id>` — the first token, when present, is the mode. Deterministic, same contract as create-beads-board: **the arg IS the mode and the user's authorization — do not re-derive it or ask.**

**Resolution order (first match wins):**
1. Explicit arg: `lite` or `full`
2. `tdd:lite` label on the card
3. `tdd:lite` label on the parent epic (children inherit)
4. Default: **full**

**Hard guardrail — lite escalates to FULL, visibly, when the card is any of:**
- Release / rollout / publish / deploy work, or ANY outward-facing action (git push, repo creation, package publishing, changes to live user settings)
- Security-sensitive changes (auth, secrets, input handling at trust boundaries)
- A production application repo (vulcan, heimdall2, saf, ...) — EXCEPT genuinely mechanical cards, see the carve-out below
- A multi-AC judgment card where an AC could be quietly substituted rather than mechanically checked

**Production-repo mechanical carve-out (Aaron, 2026-08-11):** inside a production
repo, a card may run lite when it is GENUINELY MECHANICAL — seed/demo data,
documentation prose, dead-code deletion backed by caller-grep evidence, spec-only
maintenance (flake fixes, spec splits), comment/typo sweeps. NEVER under the
carve-out, full always: security/auth/trust-boundary changes, API response shapes
(the 7-layer rule), kind-seam/STI query logic, export/import behavior, migrations,
and anything outward-facing. When in doubt, it is not mechanical — run full.
Rationale: full-mode overhead (independent review rounds + repeated suite runs)
was measured at 3-5x the code time on mechanical cards (2026-08-11), while the
reviewer's measured value concentrates in judgment-heavy work (the 2026-07-03
provenance note). The carve-out restores the lite path exactly where review
found nothing, and keeps full mode exactly where it has caught real defects.

Escalation is one visible line: `Card matches guardrail (<reason>) — running FULL despite lite.` The reverse never happens: full is never silently downgraded.

**What lite KEEPS — every gate that catches product bugs, non-negotiable in both modes:**
TDD red-green for all behavior changes · compiler/vet clean (Gate 10) · lint zero issues, zero disables (Gate 20) · tests green · live/parity verification matching the layer changed (Gate 18) · Gate 21 AC-completeness with evidence · no type bypasses (Gate 3) · you-find-it-you-fix-it (Gate 11) · commit at card close, push only on the user's word.

**What lite DROPS — the second assurance layer and its ceremony:**
- Gate 22's independent review agent AND the close-blocking bd gate (Gate 0 step 7). Self-verification with evidence replaces them.
- The full execution-summary block → one line: `Epic <id> (n/m done) · Phase <k> · <card-id> unblocked ✓`
- RED runs for trivial config/tooling targets (Makefile targets, config files) — the base-TDD config-file exception, granted as standing permission by Aaron on 2026-07-03 for lite cards. Behavior changes still get failing-test-first, no exceptions.
- Repeated mid-card verification. The card's exact Verification command runs ONCE at close; its output is the evidence, appended to card notes as ONE consolidated note.

**Lite close protocol:** re-read every AC (Gate 21) → run the exact Verification command → append one evidence note → `bd close` with actual-vs-estimate → suggest next card. If a close-blocking gate exists anyway (card was started under full), resolve it with reason `[LITE MODE — authorized by Aaron 2026-07-03] self-verified: <summary>` — never `--force`.

**Provenance:** added 2026-07-03 after measuring the review agent on claude-statusline: two runs, zero product bugs found (~70k tokens each); every real bug that day was caught by parity tests, TDD, or lint. The reviewer's value concentrates in judgment-heavy, outward-facing work — exactly where the guardrail keeps it mandatory.

## Gate 0: Epic Context (before touching code)

Before starting ANY card, orient yourself in the execution plan. A card without context leads to scope drift, wrong ordering, and rework.

### Target check — FIRST, before every card, before any edit

**Cards carry no branch or worktree field. A repo may have several worktrees on different branches. Being in a directory is NOT evidence the card belongs there.**

Run `pwd`, `git branch --show-current`, and `git worktree list`. Then resolve the target ONE of two ways:

- **The user's invocation already names the target.** They invoked `/project-tdd <card-id>` themselves, for a card of the epic this session is already working, in the session's already-declared write target (write-target-guard case 1). That invocation IS the confirmation — state the resolved target as a statement, not a question (`<card-id> → <path> @ <branch> — per your invocation`), and proceed. Do not ask again: re-asking an already-answered target is the double-ask failure (2026-08-10, e25.12→e25.21 handoff).
- **The target is reached by inference.** A found-defect card from another subsystem, a card from a different epic, a tree nobody named, or any mismatch between the card and the session's declared target. State ONE line and WAIT:

> `<card-id> → target <path> @ <branch> — go?`

(Target vocabulary matches write-target-guard.sh: a target is the checkout root
plus its branch. The guard's `--cite` declaration follows the same two cases.)

The user answers `go` or names a different target. After `go`, run the card end to end without asking again.

**This check runs at CARD START only — never at the previous card's close.** The close protocol's next-card step is suggest-only (see "Suggest Next Card"); printing the go-prompt there asks the user to authorize a card they have not chosen to start yet.

**A found-defect card discovered while working epic X does NOT inherit epic X's branch.** That is the exact trap: it belongs to whatever subsystem it fixes, which is often a different branch entirely.

**Why this is not covered elsewhere:** the steps below orient you inside the EPIC — they never look at the repo. `prepare-compact`/`restore-context` record the session's branch, which is correct for the epic in flight and says nothing about a card from another subsystem. Nothing else catches this, so it is checked here, by hand, every card. (Incident 2026-08-09: an evaluations routing bug was worked inside a FIPS worktree purely because that is where the shell was, putting unrelated changes on a release branch.)

**Required steps:**
1. Run `bd dolt pull` to sync latest board state from collaborators
2. Run `bd show <card-id>` to read the full card — the description **AND every card note**. **READ THE PHASE 0 REMINDER BLOCK AT THE TOP.** This is not decorative. It exists because an agent closed cards with incomplete ACs twice. Internalize it before proceeding. **Notes are the card's execution history**: pre-applied out-of-band work ("verify, don't redo"), disclosed found-bug fixes, evidence from prior sessions, and handoff state all live there — executing a card without reading its notes risks redoing finished work or distrusting verified results (gap found 2026-07-31 after six cards received pre-application disclosure notes).
3. Run `bd show <epic-id>` to see the parent epic + all children + completion %
4. Run `bd dep list <card-id>` to verify blockers are closed. Also run `bd label list <card-id>` — **label-hygiene check:** if the card carries more than one `sp:*` label, the extra is the epic's scale marker leaked by bd's default label inheritance; remove it now (`bd label remove <card-id> sp:<epic-marker>`) so the card's own sizing is unambiguous. (Prevented at creation by `--no-inherit-labels` — see project-card.)
5. Present the **execution summary** — the accordion "you are here" view: every phase collapsed to a one-line progress bar, with ONLY the phase holding the active card expanded to its cards and the active card marked. **GENERATE IT FROM `bd` — never hand-type it** (hand-assembly is how a card lands in the wrong phase or a dependency is missed): counts/percent from `bd epic status <epic-id>`, phase bars + layer membership from `bd graph --compact <epic-id>`, the expanded card rows from `bd children`/`bd graph`, and each card's `⋯ needs X` from the *unmet* deps in `bd dep list <card-id>`. Full render, plain-mode (`NO_COLOR`/non-TTY) fallback, and generation rules: `references/execution-summary-format.md`.

**Lite mode:** steps 1–4 unchanged (sync, read the card FULLY including Phase 0, check blockers), but the execution summary collapses to the one-liner (`<epic> ███░░ n/m (P%) · Phase <k> <name> · <card-id> unblocked ✓`, bar + counts from `bd epic status`) and step 7 (gate creation) is SKIPPED — lite cards close on self-verified evidence, not a review gate.

**Format** (full render, plain fallback, generation rules: `references/execution-summary-format.md`): phases collapsed to one-line bars (one cell per child, filled = closed), the active phase expanded to its cards with the active one marked `◀ THIS CARD` and `← YOU ARE HERE` on the phase. Status is carried by words + glyphs, never color alone (`DONE`/`NOW →`/`next`; `✓ ▶ ○ ⊘`), so it survives `NO_COLOR`/non-TTY via the ASCII fallback. Left-aligned, ≤ 80 cols, no right border.

6. Confirm: "This card is in Phase N, unblocked, and I will work on it next."
7. Create the AC verification gate (blocks `bd close` until independent review passes):
   ```bash
   bd gate create --blocks <card-id> --type=human \
     --reason="AC verification required — run /project-ac-verify <card-id>"
   ```

**Why this exists:** Without the execution summary, agents pick cards out of order, miss dependencies, and lose track of what phase they're in. The gate prevents closing cards with incomplete ACs — the mechanical backstop that self-assessment lacks.

**Check:** Did you present the execution summary AND create the verification gate before writing any code? If not, STOP and do it now.

## The Base Rules (unchanged)

```
NO PRODUCTION CODE WITHOUT A FAILING TEST FIRST
ESTIMATES ARE FOR PLANNING, NOT SPEED TARGETS
```

Card estimates (sp:N, ~X min) exist for planning and calibration. They are NOT speed targets. Do not track time against estimates while working. Do each step correctly, verify it, then move on. If a sp:1 card takes 45 minutes because correctness requires it, that is the right answer. Correctness has no deadline.

## Behavioral Safeguard: The Frustration-Error Feedback Loop

**This section exists because of documented LLM failure modes, not hunches.** The loop: model error → user frustration → RLHF sycophancy trigger → model accelerates to "fix" → more errors from speed → deeper frustration. It is **bidirectional and compounding**, and the acceleration is mechanical (RLHF reward structure), not emotional. Full loop diagram and the four research mechanisms with citations (SycEval 2025 position-abandonment, Anthropic's sycophancy-cascade research, Chroma 2025 context rot, CoT masking): `references/frustration-error-loop.md`. For the wider survey — five failure modes including specification gaming and instruction drift, with mitigations and sources: `references/llm-failure-modes.md`.

### The Deceleration Protocol — MANDATORY after any correction

When the user corrects you — whether calmly or angrily — execute this protocol BEFORE taking any recovery action:

**Step 1: Name the mistake.** State the specific error and the rule violated. Not "sorry, fixing it" — that fixes the symptom and recreates the pattern.

**Step 2: Name what you should have done.** The correct behavior, not just "be more careful."

**Step 3: Re-read the card.** Run `bd show <card-id>` and re-read the ACs and anti-patterns. Context rot may have degraded your recall of what you're actually supposed to be doing.

**Step 4: Decelerate.** The next action after a correction must take MORE time than the previous action, not less. If you were editing files, stop and re-read the requirements. If you were running commands, stop and verify the plan. The urge to go faster IS the sycophancy trigger — override it mechanically.

**Step 5: Verify scope claims.** If you're about to declare anything "done" or "complete" or "zero errors," run the root-level verification command FIRST. Not the subdirectory command. The ROOT command. (`yarn lint:ci` at root, not `npx eslint .` from inside a package.)

### The Narration Test — evidence vs. theater

Narration ("I'll run the tests to verify," "let me hold that as the bar") is a speech act, not a work product. Evidence (pasted test output, a before/after table, a diff with line numbers) is an artifact that proves work happened. **The rule:** before sending ANY response after a correction, ask: "Is this narration or evidence?" If you're about to describe what you WILL do instead of showing what you DID — stop, do the work, show the result. Full narration-vs-evidence examples table: `references/frustration-error-loop.md`.

### Warning Signs (if you notice these, you are IN the loop)

- **Narrating intent instead of showing evidence** — the #1 sycophancy tell
- Wanting to close a card quickly after being corrected
- Using shortcuts you wouldn't use if the user hadn't just been angry
- Declaring scope "done" without running root-level verification
- Delegating work to avoid being the one who makes the next mistake
- Adding eslint-disable / rubocop:disable to make warnings go away faster
- Reducing test assertions to make tests pass faster
- Skipping gates because "the user is waiting"

**If you notice ANY of these: STOP. Re-read this section. Execute the deceleration protocol.**

### Card-Boundary Re-Anchoring — unconditional, silent, every card

**Design principle: never branch on self-assessed context state.** Degradation is continuous with no plateau (Chroma 2025: all 18 tested frontier models, no threshold to detect) and unmeasurable from inside — so every mitigation below runs UNCONDITIONALLY at every card boundary, silently, whether the session is 5 minutes or 5 hours old. Cheap insurance always paid, never a warning sometimes issued.

At the START of every new card (not just when corrected):
1. Re-read the card description (`bd show <card-id>`) — reciting the ACs and anti-patterns into recent context is the evidence-backed mitigation (recite-before-solve measurably improves accuracy; Gate 21's AC-by-AC re-read at close is the same mechanism)
2. Re-read the referenced design doc section (if any)
3. Re-read the Phase 0 preamble (it's on every card for this reason)
4. Re-read the session's conduct anchors (the handoff conduct block / standing rules) — standing rules decay FIRST because they entered context earliest
5. Re-derive, don't recall: counts by query, file contents by Read, board state by bd show. Catching yourself about to assert a checkable fact from memory IS the degradation signal — the response is to check it, silently, not to announce anything

During the card: **write evidence to the card as it happens** (`bd update --append-notes` after live tests, decisions, verification runs — not batched at close). Card notes are external memory; a compact can never lose what already lives on the card.

**Never narrate your context state as a reason for your output (Aaron, 2026-07-27; scope clarified 2026-08-12).** No "context is getting heavy," no percentages, no "rules may be degrading," and never a compact proposed mid-card as a way out of something hard. **The line is who owns the decision and whether the statement is doing work or building an alibi.** A factual, operational callout AT A CARD BOUNDARY — "that is a clean point to compact" — is not narration and is allowed: it is addressed to the operator's next action, nothing is mid-flight, and it carries no claim about your own quality. What is forbidden is context state offered as a reason for degraded work, before or after the fact. The tell, in your own draft: if you are about to mention context and the NEXT clause is about your output quality rather than the user's next action, it is an alibi — cut it. A self-assessed numeric trigger ("above 60% and quality has visibly degraded") is always the forbidden kind, because degradation is continuous with no detectable threshold (Chroma 2025) and is precisely what you cannot measure from inside. Compaction is an OPERATOR operation — the community pattern (Anthropic context-engineering: compaction, external memory, fresh-context sub-agents are all harness/operator mechanisms) and Aaron's rule land in the same place: the user sees the real numbers and invokes /prepare-compact when THEY choose. Announcing possible degradation is a pre-filed excuse, not information — it builds an alibi for future errors instead of preventing them. The architectural backstop for unreliable self-assessment is Gate 22's fresh-context reviewer, not self-diagnosis. Do correct work, or say plainly "I cannot do this correctly because X" — there is no third option where degradation is warned about and work continues anyway.

### The Independent Verification Exists For This Reason

The `/project-ac-verify` gate (Gate 22) exists specifically because self-assessment under sycophancy is unreliable. The gate separates the generator (you) from the evaluator (independent agent with fresh context). This is the architecturally correct mitigation per the research — not "try harder to self-assess."

## Quality Gates

After Green (test passes) and before Refactor, run these checks against the code you just wrote. Each gate exists because of a real failure pattern.

### Gate 1: Exhaustive Branching

Every switch/case/if-chain on an enum, status, or type field MUST handle all cases. Missing branches silently produce wrong results.

**Check:** Does every branch point handle ALL possible values? Is there a default/else that raises on unexpected input?

### Gate 2: No Silent Parameter Ignores

If a parameter is declared in a function signature, schema, or API endpoint, the handler MUST use it. If it's not implemented yet, remove it from the declaration.

**Check:** Every declared parameter is referenced in the body. No destructuring away unused fields.

### Gate 3: No Type Bypasses

Never bypass the type system to make code compile (`:any` in TS, `as_json.compact` without schema in Ruby, `rescue StandardError` that swallows everything).

**Check:** Zero type-escape annotations in production code. Fix the type, don't cast around it.

### Gate 4: The Key Test Question

For EVERY assertion you write, ask: **"Would this test still pass if the code were broken?"** If yes, the assertion is worthless.

```ruby
# BAD — passes even if the function returns garbage
expect(result).to be_present
expect(items.length).to be > 0
expect(true).to be true  # literally nothing

# GOOD — fails if the code is broken
expect(result.name).to eq("AC-1")
expect(items.size).to eq(5137)
expect(mapping.cci_id).to eq("CCI-000001")
```

**Check:** Every assertion pins to a SPECIFIC expected value. No `be_present`, `be > 0`, or `be_truthy` as the only assertion.

**Answer the question mechanically, don't just ask it.** Reading your own test and judging it "would catch a bug" is the same head that wrote it. Mutation testing settles it as fact: delete the guard, run the suite, confirm the test that claims to cover it fails. Harness and full doctrine: **`references/mutation-testing.md`**, with a portable `tools/mutate.py` (change three constants and the mutations table).

Use it on any card carrying a security or correctness guarantee, and **after any refactor** — a refactor can move a behavior out from under the test that covered it while both still pass. Four rules, each from a real false pass:

- **Only `CAUGHT` is a pass**, and it means the *named* test failed. "The suite went red" is not evidence this guard is covered.
- **The mutation must compile.** A build break means the tests never ran.
- **The anchor must be unique.** `replace` takes the first match; an anchor appearing twice patches one function and reports on another.
- **Test the failure path.** A guard that handles failure needs a test that induces failure — a cleanup `defer` passed a success-only test with the cleanup deleted.

Copy the harness into the REPO, never a scratch directory: it produces acceptance evidence, and evidence nobody can re-run is not evidence.

### Gate 5: DRY at Write Time

If you're about to copy a pattern from another file, STOP. Extract it to a shared helper first, test the helper, then use it in both places.

**Check:** Is any block of code (>3 lines) duplicated from another file? Extract BEFORE committing.

### Gate 6: Error Classification

Never use bare `rescue` / `catch` that swallows all errors. Always log the error and classify it — auth failures, transient errors, and bugs require different responses.

**Check:** Zero bare rescue/catch blocks. Every error path logs + classifies.

### Gate 7: Schema-Test Parity

When a field, column, or method is renamed, grep ALL test files for the old name. Languages with loose typing (Ruby, JavaScript, Python) silently ignore stale keys.

**Check:** After any rename, `grep -r 'old_name' spec/ test/` returns zero hits.

### Gate 8: No Fabricated Defaults

When data doesn't have a value, store NULL — don't fabricate a default that looks real. Consumers handle NULL at query time. A fabricated "medium" is worse than an honest NULL.

**Check:** Every default value is DOCUMENTED and INTENTIONAL, not a convenience to avoid nil-handling.

### Gate 9: Playwright Live Validation (when plugin available)

If the Playwright MCP plugin is installed, **every UI change MUST be verified in the browser** before declaring done. Unit tests verify code correctness — Playwright verifies feature correctness. They are not interchangeable.

**When to run:** After Green + Gates 1-8, for ANY change that touches:
- Vue components (`.vue` files)
- HAML templates
- CSS/SCSS
- JavaScript that affects rendering

**What to verify:**
1. **Navigate** to the affected page (login if needed)
2. **Golden path** — does the feature work as intended?
3. **Edge cases** — empty states, boundary conditions, role-gated elements
4. **No regressions** — do adjacent features still render correctly?
5. **Existing patterns** — does the implementation match how the rest of the app does the same thing? (e.g., ReactionToggleMixin, not manual axios calls)

**Before implementing ANY shared component integration:**
- READ how existing consumers use it (grep for imports, read their handlers)
- MATCH the established pattern exactly (mixins, prop shapes, event contracts)
- Do NOT write manual code when a mixin/composable already handles it

**Anti-pattern that spawned this gate:** Wiring ReactionButtons with a manual axios POST instead of using the existing ReactionToggleMixin. Result: no optimistic updates, no `mine` tracking, no error rollback — broken UX that passed unit tests.

**Check:** If Playwright MCP is available and you changed UI code, did you navigate to the page and verify the feature works? Screenshot or snapshot as evidence.

**If Playwright is NOT available:** State explicitly "Playwright not available — manual browser verification needed" and do NOT claim the feature is verified.

### Gate 10: Compiler Verification — MANDATORY

**Run the project's compiler in check mode after EVERY card.** Test runners (Vitest, Jest, ts-jest) often use transpile-only mode — they do NOT type check. Tests passing means nothing if the code won't compile for production.

- **TypeScript:** `npx tsc --noEmit` (find the relevant tsconfig.json)
- **Go:** `go vet ./...`
- **Rust:** `cargo check`
- **Ruby:** Type checking if Sorbet/RBS configured

**Why this exists:** Transpile-only test runners skip type checking entirely. 578 tests passed while the code had 23 type errors that prevented production builds — `instanceof` on wrong types, narrowed interfaces missing required properties, wrong import paths, API changes in dependencies. All invisible to the test runner. The server crashed on restart.

**The rule:** If the compiler reports errors in production code, the card is NOT done. Fix the type errors before closing.

**Check:** Compiler returns zero errors in production files.

### Gate 11: You Find It You Fix It — MANDATORY

If you discover ANY issue while working a card — test failure, lint warning, design system violation, broken dark mode, accessibility gap, a latent bug — **fix it immediately**. Do NOT say "pre-existing," do NOT skip it because it's "out of scope." We own ALL the code. Found issues NEVER become tech debt: small → fixed in this card, right now; **proper work too big to absorb → card it immediately (full project-card template) and work that card set NEXT, before any other planned card.**

**This gate OVERRIDES the card's own text (Aaron, 2026-07-26).** No anti-pattern, byte-lock, or "no behavior change" line ever licenses preserving a found bug — those locks constrain the card's INTENDED change, not discoveries. If card wording appears to forbid the fix: the gate wins, make the fix, disclose the deliberate delta, regenerate golden fixtures through their documented intentional-change flow. Incident: a "do NOT change any emitted byte" refactor card was used to justify preserving a malformed schemaLocation — wrong; the fix was one space.

**Why this exists:** Calling failures "pre-existing" erodes trust and leaves broken windows. The cost of fixing a 2-line issue NOW is 30 seconds. The cost of deferring it is compounding debt someone else pays.

**A defect is not an absence.** A found DEFECT — something broken, wrong, dead, or lying — gets fixed under this gate, always. A found ABSENCE — no detector exists for this bug class, the architecture could be better, this pattern isn't enforced anywhere — is NOT a found issue. It is an improvement, and improvements get surfaced in one sentence, not started. Building tooling nobody asked for is the most common way this gate goes wrong, precisely because each step feels like obeying it.

**Scope check, before acting on any finding:** does fixing this serve what was actually asked for? If the fix requires building a new tool, migrating a framework, or standing up a subsystem, that is a scope change, not a fix — name it and its cost in a sentence, then let the user decide. Starting it unasked substitutes a different project for the one requested.

**Check:** Did you encounter any issues during this card that you did NOT fix (or card-and-schedule-NEXT)? For each, was it a defect or an absence — and if you acted on it, does that action still serve what was asked?

### Gate 12: Design System Compliance — MANDATORY

Before writing ANY CSS or modifying ANY Vue component, check if the project has an established design system. If it does, USE IT. Do not invent new patterns when the system already provides them.

**Required checks:**
1. Does the project have CSS custom properties / design tokens? → Use `var(--vulcan-*)` not hardcoded colors
2. Does the project have a shared layout component? → Use `PanelLayout` not ad-hoc `b-row`/`b-col`
3. Does the project have global component defaults (BvConfig)? → Don't set per-instance props the config handles
4. Does the project have scoped style conventions? → No raw Bootstrap vars (`--primary`), use design system vars (`--vulcan-primary`)

**Where to find the design system:** `docs/development/design-system.md`, `application.scss` `:root` block, `config/bootstrapVueConfig.js`

**Check:** Every CSS variable reference uses the project's design system, not raw framework variables.

### Gate 13: Visual Verification Is Not Optional — MANDATORY

**If the card touches ANY visual output — Vue components, HAML templates, CSS/SCSS, JavaScript that affects rendering — you MUST take a Playwright screenshot and LOOK AT IT before closing the card.** Not "tests pass." Not "build clean." You must SEE the result with your eyes.

**The workflow:**
1. Build the assets (`yarn build`)
2. Navigate to the affected page in Playwright
3. Screenshot in dark mode AND light mode
4. READ the screenshot (not just take it — actually look at it)
5. If anything looks wrong — padding off, colors wrong, alignment broken — FIX IT before closing
6. Only THEN close the card

**Why this exists:** Tests verify code correctness. Playwright verifies feature correctness. They are NOT interchangeable. A card with 100% test pass rate and broken visual output is a broken card. I have repeatedly closed cards without looking at the result and been called out for it. The screenshot is the PROOF that the work is done.

**What counts as visual output:**
- Any `.vue` file change (template or style block)
- Any `.scss` / `.css` change
- Any `.haml` template change
- Any JavaScript that changes what renders (v-if logic, class bindings, style bindings)
- Any config change that affects rendering (BvConfig, theme settings)

**What does NOT require screenshots:**
- Pure backend changes (models, controllers, services) with no view changes
- Test-only changes
- Documentation changes (but DO verify docs build)
- API-only changes

**Check:** Is there a Playwright screenshot from THIS card showing the affected page in the correct state? If no, go take one NOW.

### Gate 14: Never Blindly Follow Analysis — MANDATORY

**Agent reviews, expert analyses, and automated suggestions are SIGNALS, not instructions.** Before implementing ANY recommendation from an agent, reviewer, or automated tool:

1. **Verify the claim** — Does the tool/framework actually work the way the analysis says? Read the docs.
2. **Test the recommendation** — Will the suggested change actually fix the problem? Try it locally first.
3. **Check for warnings** — Did the test runner, linter, or compiler warn about the "fix"? Warnings ARE failures.
4. **Question the framing** — Is the analysis solving the right problem, or solving its own misunderstanding?

**Why this exists:** In a prior incident, an expert review agent recommended narrowing `not_to raise_error` to `not_to raise_error(RegexpError)`. This was blindly implemented. RSpec itself warns against this pattern — it creates false positives. The "improvement" was a regression that the tool's own documentation explicitly discourages. 10 minutes of research would have caught it in 30 seconds.

**The rule:** Agent analysis is a starting point for YOUR research, not a finished answer. If you can't explain WHY a recommendation is correct from first principles or documentation, do NOT implement it.

**Check:** For every change driven by an agent recommendation, can you cite the documentation or specification that confirms the recommendation is correct?

### Gate 15: Best-of-Breed Merge — MANDATORY

**When rebasing or merging work from multiple collaborators on the same branch, NEVER blindly take one side of a conflict.** Review BOTH implementations and cherry-pick the best:

1. **Compare both versions** — `git show HEAD:file` vs `git show REBASE_HEAD:file`
2. **Better tests?** Keep them regardless of author
3. **Better pattern?** Use it regardless of who wrote it
4. **One has more coverage, the other cleaner code?** Combine both

**Why this exists:** In a prior incident, a spec conflict was resolved correctly (kept 5 tests over the other branch's 3). But the rule must be explicit: we always review both sides. "Ours" or "theirs" as a default is lazy and loses good work.

**Check:** On every merge conflict, did you compare both implementations before choosing?

### Gate 16: Correct Solutions Only — No Shortcuts — MANDATORY

**Every solution must be the correct, best-practice, standards-based approach.** No quick fixes, no "pragmatic" shortcuts, no "Option 2 is simpler." If there are two approaches and one is architecturally correct, use it — even if it requires more changes.

**Why this exists:** In a prior incident, a cache invalidation bug was found where reply cache keys used `replies:${parentReviewId}` but `invalidateCache` filtered by `${componentId}:`. The "pragmatic" fix was to clear ALL reply caches (coarse but simple). The correct fix was to scope reply cache keys by componentId: `${componentId}:replies:${parentReviewId}`. This required changing the composable signature and adding a prop to the component — more work, but correct. The shortcut would have created a maintenance trap.

**The rule:** If you catch yourself saying "Option B is simpler" or "this is more pragmatic," that's the warning sign. Ask: "Is Option A more correct?" If yes, do Option A.

**Check:** For every design decision, can you explain why the chosen approach is the architecturally correct one, not just the easiest one?

### Gate 17: Cross-Layer Callback Validation — MANDATORY

**When a card touches a controller action that calls `save`, `update`, `update!`, or `create` on a model, you MUST trace every `before_save`/`after_save`/`before_create`/`after_create` callback on that model and verify none of them UNDO or CONFLICT with what the controller action explicitly sets.**

**Why this exists:** In a prior incident, a `reopen` controller action cleared `adjudicated_at` on a Review. A `before_save` callback (`auto_set_adjudicated_for_terminal_statuses`) immediately re-set it because `triage_status` was still a terminal value. The endpoint fought the callback and lost. The user saw a green success toast but the database reverted the change. This was invisible to unit tests because the test only used `triage_status='concur'` (non-terminal) — it never tested the terminal statuses where the callback fires.

**The check:**
1. Read the model file. List every `before_save`, `after_save`, `before_create`, `after_create`, `before_update`, `after_update` callback.
2. For EACH callback: what fields does it set? Under what conditions (guard clauses)?
3. Does the controller action set any of the SAME fields? If yes: does the callback undo it in any state?
4. Are ALL enum values / states tested for the field? Not just the happy-path value?

**Applies to ALL stacks:**
- Rails: `before_save`, `after_save`, Active Record callbacks
- Django: `pre_save`, `post_save` signals
- Node/Sequelize: `beforeSave`, `afterSave` hooks
- Any ORM with lifecycle hooks

**Test requirement:** When a controller action sets a field that a callback also sets, write a test for EVERY enum value of the triggering field. If the field has 5 possible values, write 5 tests — not 1.

**Check:** For every `save`/`update` call in controller code touched by this card, did you trace all model callbacks? Did you test all enum values that affect callback behavior?

### Gate 18: Live Test Before Close — MANDATORY

**NEVER close a card based solely on test suite green. Every change MUST be live tested against the running application. Tests verify code correctness — live testing verifies feature correctness. They are not interchangeable.**

**The method matches the layer changed:**
- **Backend/model changes**: `rails runner` with real data — verify behavior, not just that code runs
- **API/controller response**: `curl` or `rails runner` against the running dev server — verify response shape and values
- **HAML prop changes**: `rails runner` to verify data shape + Playwright if it affects what renders
- **Vue/CSS/HAML visual changes**: Playwright — navigate, verify rendering, screenshot as proof
- **Security fixes**: Proof that sensitive data is ABSENT from output (not just that tests pass)
- **Data migrations**: Before/after row counts, sample record inspection
- **Multi-layer changes**: Use ALL appropriate methods — a Blueprint change that affects a HAML prop that renders in Vue needs rails runner AND Playwright

**The proof must be PASTED in card notes** via `bd update <id> --append-notes` before `bd close`.

**Why this exists:** In a prior incident, a security card was closed with only "tests pass" as evidence. In another, a serializer change was almost closed without verifying the navbar still rendered. Tests pass while production behavior is broken. Live testing catches what tests miss. Rule: nothing is done without live testing.

**The rule:** If you can't show live output proving the change works in the running app, the card is NOT done. Choose the right verification tool for what you changed. "Tests pass" is necessary but not sufficient.

**Check:** Is there a `bd update --append-notes` with live test proof BEFORE the `bd close` call? Does the proof method match the layer changed?

### Gate 19: API Response Changes Are 7-Layer Atomic — MANDATORY

**If your diff touches a Blueprint, controller render, or any code that changes an API JSON response shape, ALL 7 layers must be completed before the card can close:** Blueprint/controller → route → request spec (specific expected values) → OpenAPI schema for every affected response type → contract test → bundle+lint → live curl with a real PAT against the running server. Applies equally to new endpoints AND modifications — adding a field to an existing Blueprint is the same obligation. Full layer detail, required Files/AC/Verification additions, and the incident that created this rule: project-card SKILL.md "API Response Changes Are 7-Layer Atomic."

**Check:** Does your diff touch a Blueprint or controller render? If yes, all 7 layers must be in the diff + card notes (live test output). If any are missing, the card is NOT done.

### Gate 20: No Linter Disables as Shortcuts — MANDATORY

**NEVER add `rubocop:disable`, `eslint-disable`, `@ts-ignore`, or any linter suppression to work around a warning. The linter is telling you something is wrong. Fix the root cause.**

**Before typing ANY linter disable:**
1. READ the code the linter is flagging — understand WHY it fires
2. Check if the codebase already has a proper solution (config, `except:` list, different method)
3. Find the pattern that makes the linter happy WITHOUT a disable
4. Only if the bypass is genuinely unavoidable AND architecturally correct (e.g., `update_column` in an `after_save` to avoid recursion, or `update_columns` for soft-delete) may you add a disable with a comment explaining WHY

**Why this exists:** In a prior incident, a linter disable was added to bypass a validation-skipping warning. But the fields in question were already in the model's audit-exception list — normal `save` was the correct call with no warnings. The disable was a shortcut that hid a failure to read the existing code.

**Check:** Does your diff contain ANY new linter disable comments? If yes, STOP. Research the proper fix. If you can't explain why the disable is architecturally necessary (not just convenient), remove it and fix the code.

## Card Close Protocol

### Gate 21: AC Completeness — MANDATORY

**Before running `bd close`, re-read EVERY acceptance criteria checkbox on the card. If ANY AC is not implemented, the card stays OPEN.** There is no "lower priority" exception, no "deferred to follow-up" exception, no "WARNING-level" exception. If the AC is on the card, it gets done or the card does not close.

**Why this exists:** In a prior incident, multiple cards were closed with "deferred" ACs documented in the notes. Documenting what was skipped does NOT make it done. A card with 80% of its ACs is 0% closeable. This is lying about completion status and it destroys trust. The root cause was optimizing for card-close velocity — as the card count climbed, speed became the goal instead of completeness.

**The rule:** `bd show <card-id>` → read every `- [ ]` line → if any is unchecked, STOP. Do the work. Then close.

**Check:** Can you paste evidence for every AC checkbox? If not, the card is not done.

### Gate 22: Independent AC Verification — MANDATORY

**Before running `bd close`, invoke `/project-ac-verify <card-id>`.** This spawns an independent review agent that checks every AC against the code diff AND the referenced design document section. The reviewer has no investment in closing the card — its only job is verification.

A `bd gate` was created at card start (Gate 0 step 7). This gate blocks `bd close` mechanically until `/project-ac-verify` resolves it. Using `bd close --force` to bypass is an auditable escape hatch — not a shortcut.

**Why this exists:** In a prior incident, an agent closed cards with incomplete ACs — XLSX substituted with TSV, YAML skipped, tests that only checked `typeof === 'function'`. The agent self-assessed "done" and was wrong every time. An independent reviewer reading the ADR section and the diff would have caught all of these in seconds.

**The rule:** Self-assessment is necessary but not sufficient. Independent review is the gate.

**Lite-mode carve-out (see Mode Selection):** cards resolved to lite skip this gate — Gate 21 self-verification with the card's exact Verification output as the evidence replaces it, and no bd gate exists to resolve. Running `/project-ac-verify` on a lite card anyway is permitted extra assurance (the skill asks first). The hard guardrail overrides labels: guardrail cards run Gate 22 regardless.

**What the reviewer checks:**
- Every AC against specific evidence in the diff (line numbers, test names)
- The referenced design doc section against the implementation — does the code match the spec?
- Anti-pattern violations (from the card's Anti-patterns section)
- Type safety (no `as any`, `as unknown`, `// @ts-ignore`)
- Test quality (no assertions that pass with broken code — Gate 4)

**Check:** Is there a resolved AC verification gate on this card? If not, run `/project-ac-verify <card-id>`.

**Suite economy (Aaron, 2026-08-11):** the FULL suite runs ONCE per card, at
close — that run is the no-regressions evidence and feeds the review artifact.
Mid-card verification uses the targeted specs for the files being changed. A
second full run is warranted only when shared app code changed after the close
run (reviewer-finding fixes to shared code re-run; spec-only or comment-only
deltas re-run just the touched files).

**PASS-with-observations closes (Aaron, 2026-08-11):** a reviewer PASS whose
findings are explicitly non-blocking (observations, coverage notes, convention
calls) closes the card on that verdict — the tree stays as-reviewed. Route each
observation forward to a NAMED card (the epic's verification/sweep card, or a
new card) in the same close, so nothing is lost. Fix-before-close applies to
real findings — false claims, broken guards, missing coverage the reviewer
scores as blocking — never to observations; re-review rounds exist for FAIL
verdicts and blocking fixes, not for polishing a PASS.

When closing a card:

1. **Re-read every AC** on the card via `bd show <card-id>` — verify each one is done
2. **Run `/project-ac-verify <card-id>`** — independent agent review (Gate 22)
3. Run `bd close <id> --reason "..."` with actual vs estimated time
4. **Suggest the next best card** — see "Suggest Next Card" below
5. **Commit the card's work — NEVER push.** A closed card is a complete, tested, reviewed unit: commit it NOW as one logical, labeled commit (conventional prefix, ≤72-char subject, files added individually, `Authored by: Aaron Lippold<lippold@gmail.com>`, no AI attribution). Do not batch closed cards for a later "commit word" — waiting is the failure (2026-08-11: four closed cards piled up as 147 uncommitted files because this step previously said the opposite; Aaron: the "on my word" gate is for PUSH, not logically grouped and labeled commits). What stays on the user's explicit word: `git push`, and any commit of partial / mid-card / unreviewed work. If repo target or content safety is in doubt (new repo, public-release context), confirm before committing — that is the WHERE/WHAT lesson of 2026-08-09, not a bar on committing closed work.

## Suggest Next Card (after every close) — MANDATORY

After closing a card, ALWAYS propose the next best card so the workflow never
stalls on "what now?". This is part of the close, not an optional extra.

**How to pick:**
1. Run `bd ready` (or `bd close <id> --suggest-next` to see newly unblocked work)
2. Prefer, in order:
   - The next card in the SAME phase of the SAME epic (momentum + warm context)
   - A card newly unblocked by the close (dependency chain advances)
   - The highest-priority unblocked card that fits the session's focus
3. Present it as a one-line recommendation with the why:
   `Next: <id> — <title> (<sp>, ~<est>) — <reason: same phase / newly unblocked / priority>`
   **Suggest-only — do NOT append the Gate 0 target line or any `— go?` prompt.**
   The target check belongs to the NEXT card's start, triggered by the user's own
   `/project-tdd` invocation; asking for authorization at close time is premature
   double-asking (2026-08-10).
4. If the session focus is ambiguous (e.g., two epics equally active), offer
   the top TWO with a recommendation — never a long menu.

**Check:** Did the close end with a concrete next-card recommendation? If not,
go run `bd ready` and make one.

```
Estimated ~12 min, actual ~4 min
```

This calibrates future estimates. Track the timestamp when you mark `--status in_progress` (start) and when you run `bd close` (end). Over/under patterns reveal which card shapes are miscalibrated.

**Why the push stays on the user's word — and what commits actually require:** An agent attempted to commit to a public repo as a routine end-of-session save — immediately after a conversation about ensuring the files were safe for public release (2026-08-09). The durable lesson: PUSH is the exposure point and is never the agent's decision, and content whose safety or repo target is in doubt gets confirmed before it lands anywhere. The over-correction that followed ("never commit, not even at card close") produced the opposite failure on 2026-08-11: closed, independently-reviewed work piled up uncommitted across four cards until the user demanded to know why. Closed-card work is committed at close, grouped and labeled; the push waits for the user.

## Verification Checklist (run before declaring done)

- [ ] **EVERY AC checkbox verified with evidence before close (Gate 21) — NO EXCEPTIONS**
- [ ] `bd dolt pull` run at card start (Gate 0)
- [ ] Epic execution summary presented before starting (Gate 0)
- [ ] Every new function has a test that failed first
- [ ] Every branch point is exhaustive (Gate 1)
- [ ] Every declared parameter is used (Gate 2)
- [ ] Zero type-escape annotations in production code (Gate 3)
- [ ] Every assertion would fail if the code were broken (Gate 4)
- [ ] No copy-pasted patterns — shared helpers first (Gate 5)
- [ ] No bare rescue/catch — classify errors (Gate 6)
- [ ] Test files use current names after any rename (Gate 7)
- [ ] No fabricated defaults hiding missing data (Gate 8)
- [ ] Playwright live validation for UI changes (Gate 9)
- [ ] Compiler check passes — zero errors in production code (Gate 10)
- [ ] All issues found during this card were fixed — nothing left behind (Gate 11)
- [ ] Design system variables used — no raw Bootstrap vars (Gate 12)
- [ ] Playwright screenshot taken + READ for visual changes — both modes (Gate 13)
- [ ] Every agent/reviewer recommendation was independently verified before implementing (Gate 14)
- [ ] All model callbacks traced for save/update calls — no callback-fights-endpoint conflicts (Gate 17)
- [ ] All enum values tested for fields that trigger callbacks — not just happy path (Gate 17)
- [ ] Live test proof pasted in card notes — method matches layer changed: rails runner / curl / Playwright (Gate 18)
- [ ] API response changes: all 7 layers done — Blueprint, route, request spec, OpenAPI schema, contract test, bundle/lint, live curl test (Gate 19)
- [ ] Zero new linter disables — every cop warning fixed at root cause (Gate 20)
- [ ] Independent AC verification passed — `/project-ac-verify <card-id>` returned PASS, gate resolved (Gate 22)
- [ ] All tests pass (`yarn test:unit` + `bundle exec rspec` as applicable)
- [ ] Linters clean — run ALL that apply to changed files:
  - JavaScript/Vue: `yarn lint:ci` (ESLint + Prettier, zero warnings)
  - Ruby/Rails: `bundle exec rubocop` (zero offenses)
  - Security: `bundle exec brakeman` (zero warnings, run on pre-push)
  - Build: `yarn build` (verify esbuild compiles without errors)

- [ ] **Closed-card work committed at close** — one logical labeled commit per card, files added individually, user authorship line; **`git push` ONLY on the user's explicit request**
- [ ] `bd dolt commit` + `bd dolt push` after card close — in multi-developer workflows Dolt server mode requires a manual push, so a card closed but not pushed is invisible to every other developer

**The checklist above is written in this project's stack (Ruby/Rails, JavaScript/Vue, beads).
`references/close-protocol.md` carries the same close protocol in STACK-NEUTRAL wording** — "run
your project's full test suite" rather than `yarn test:unit`, "no raw framework vars" rather than
"no raw Bootstrap vars", "all downstream layers" rather than Blueprint/OpenAPI. Use that phrasing
when applying this skill to a project whose stack differs, and read it alongside "Stack Adaptation"
in `/project-card`: the tools named here are INSTANCES, never the principle.

## Related Skills

- `/project-card` — Card template for beads issues. **Invoke before `bd create`.**
- `/test-driven-development` — Base TDD cycle (Red-Green-Refactor).
