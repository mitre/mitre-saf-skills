---
name: project-tdd
description: >-
  TDD with 22 quality gates learned from production audits. Covers exhaustive
  branching, test sufficiency, type safety, DRY, visual verification, API
  contract atomicity, ORM callback validation, and linter discipline. Use for
  development in projects using beads for issue tracking.
compatibility: Requires beads CLI (bd). Gates reference multiple stacks.
license: Apache-2.0
---

# Project TDD Quality Gates

**CORRECTNESS IS THE ONLY PRIORITY.** Card-close velocity is not a metric. Speed is not a goal. If you notice yourself rushing through gates, batching closes, or using `--force` to bypass verification — STOP. That thought is the warning sign. Slow down. Every gate exists because rushing caused a real failure.

**Prerequisite:** This skill builds on the test-driven-development skill. Follow the base TDD cycle (Red-Green-Refactor) exactly. This skill adds quality gates that catch patterns found in real production audits.

## Gate 0: Epic Context (before touching code)

Before starting ANY card, orient yourself in the execution plan. A card without context leads to scope drift, wrong ordering, and rework.

**Re-read the correctness rule above before every card.** It is not decorative.

**Required steps:**
1. Run `bd dolt pull` to sync latest board state from collaborators
2. Run `bd show <card-id>` to read the full card description — **READ THE PHASE 0 REMINDER BLOCK AT THE TOP.** This is not decorative. It exists because an agent closed cards with incomplete ACs twice. Internalize it before proceeding.
3. Run `bd show <epic-id>` to see the parent epic + all children + completion %
4. Run `bd dep list <card-id>` to verify blockers are closed
4. Present the **execution summary** — the full phased dependency graph for the epic, marking the active card. Every card shows: ID, title, story points, Claude-pace estimate, and blocker status.

```
Epic: <epic-id> — <epic title> (<completed>/<total> cards, N% complete)

Phase 1 — Bug fixes (all unblocked, can parallel):
  card.1  Fix doSave adjudicate logic          (sp:2, ~12 min) ← DOING THIS ONE
  card.2  Fix factory traits after(:build)      (sp:2, ~10 min)
  card.3  Fix ID type coercion                  (sp:1, ~5 min)
  card.4  Fix seed_xccdf XML type               (sp:1, ~5 min)

Phase 2 — UX feedback (after Phase 1):
  card.5  Show locked status in triage          (sp:2, ~10 min)
  card.7  Admin inline buttons                  (sp:3, ~20 min)

Phase 3 — Blocked by Phase 2:
  card.6  Move toggle closer to context         (sp:2, ~10 min) <- blocked by card.5
  card.9  RBAC changes                          (sp:3, ~20 min) <- blocked by card.5
  card.10 Staleness badge                       (sp:3, ~20 min) <- blocked by card.5
  card.8  Rename to Comments Table              (sp:1, ~5 min)  <- blocked by card.7

Phase 4 — Polish:
  card.11 CHANGELOG                             (sp:1, ~5 min)  <- last

Total: 11 cards, ~22 sp, ~130 min Claude-pace
```

**Format rules:**
- Show ALL cards in the epic, not just the active one
- Group by phase with a theme label (Bug fixes, UX, RBAC, Polish)
- Show blocker arrows (`<- blocked by X`) for dependent cards
- Mark the active card with `<- DOING THIS ONE`
- Include total card count, total sp, and total estimate at the bottom
- If a card is already done, mark it with `[DONE]`

6. Confirm: "This card is in Phase N, unblocked, and I will work on it next."
7. Create the AC verification gate (blocks `bd close` until independent review passes):
   ```bash
   bd gate create --blocks <card-id> --type=human \
     --reason="AC verification required — run the project-ac-verify skill on <card-id>"
   ```

**Why this exists:** Without the execution summary, agents pick cards out of order, miss dependencies, and lose track of what phase they're in. The gate prevents closing cards with incomplete ACs — the mechanical backstop that self-assessment lacks.

**Check:** Did you present the execution summary AND create the verification gate before writing any code? If not, STOP and do it now.

## The Base Rule (unchanged)

```
NO PRODUCTION CODE WITHOUT A FAILING TEST FIRST
```

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

### Gate 9: Live Visual Verification — MANDATORY for UI Changes

**Every UI change MUST be verified in a real browser before declaring done.** Unit tests verify code correctness — live browser verification verifies feature correctness. They are not interchangeable.

If Playwright MCP (or equivalent browser automation) is available, use it. If not, state explicitly "browser automation not available — manual browser verification needed" and do NOT claim the feature is visually verified without evidence.

**When to run:** After Green + Gates 1-8, for ANY change that touches:
- Vue components (`.vue` files)
- server-rendered templates (e.g., HAML, ERB, Jinja, Blade)
- CSS/SCSS
- JavaScript that affects rendering

**What to verify:**
1. **Navigate** to the affected page (login if needed)
2. **Golden path** — does the feature work as intended?
3. **Edge cases** — empty states, boundary conditions, role-gated elements
4. **No regressions** — do adjacent features still render correctly?
5. **Existing patterns** — does the implementation match how the rest of the app does the same thing? (e.g., the project's existing mixin/composable, not manual HTTP calls)

**Before implementing ANY shared component integration:**
- READ how existing consumers use it (grep for imports, read their handlers)
- MATCH the established pattern exactly (mixins, prop shapes, event contracts)
- Do NOT write manual code when a mixin/composable already handles it

**Anti-pattern that spawned this gate:** Wiring a shared component with manual HTTP calls instead of using the existing mixin/composable. Result: no optimistic updates, no state tracking, no error rollback — broken UX that passed unit tests.

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

If you discover ANY issue while working a card — test failure, lint warning, design system violation, broken dark mode, accessibility gap — **fix it immediately**. Do NOT say "pre-existing," do NOT card it for later, do NOT skip it because it's "out of scope." We own ALL the code. Every issue found is an issue fixed, in this card, right now.

**Why this exists:** Calling failures "pre-existing" erodes trust and leaves broken windows. The cost of fixing a 2-line issue NOW is 30 seconds. The cost of carding it, context-switching, and coming back later is 10 minutes minimum.

**Check:** Did you encounter any issues during this card that you did NOT fix? If yes, go back and fix them.

### Gate 12: Design System Compliance — MANDATORY

Before writing ANY CSS or modifying ANY Vue component, check if the project has an established design system. If it does, USE IT. Do not invent new patterns when the system already provides them.

**Required checks:**
1. Does the project have CSS custom properties / design tokens? → Use project design tokens (e.g., `var(--project-primary)`) not hardcoded colors
2. Does the project have a shared layout component? → Use the project's shared layout component instead of ad-hoc grid markup
3. Does the project have global component defaults? → Don't set per-instance props that global config already handles
4. Does the project have scoped style conventions? → No raw framework vars — use project design tokens

**Where to find the design system:** Your project's design system docs, root stylesheet, and global component config

**Check:** Every CSS variable reference uses the project's design system, not raw framework variables.

### Gate 13: Visual Verification Is Not Optional — MANDATORY

**If the card touches ANY visual output — Vue components, server-rendered templates (e.g., HAML, ERB, Jinja, Blade), CSS/SCSS, JavaScript that affects rendering — you MUST take a Playwright screenshot and LOOK AT IT before closing the card.** Not "tests pass." Not "build clean." You must SEE the result with your eyes.

**The workflow:**
1. Build the assets (e.g., `yarn build`, `npm run build`, `vite build`)
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
- Any config change that affects rendering (global component config, theme settings)

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

**Why this exists:** In a prior incident, a controller action cleared a timestamp field. A `before_save` callback immediately re-set it because a status field was in a terminal state. The endpoint fought the callback and lost. The user saw success but the database reverted. Tests missed it because they only tested one enum value out of five — the non-terminal one where the callback doesn't fire.

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
- **Backend/model changes**: Run with real data (e.g., `rails runner`, `python manage.py shell`, `go run`) — verify behavior, not just that code runs
- **API/controller response**: `curl` or equivalent against the running dev server — verify response shape and values
- **Template prop changes**: Verify data shape from the backend + browser verification if it affects rendering
- **UI/CSS/template visual changes**: Playwright MCP (preferred) or manual browser — navigate, verify rendering, screenshot as proof. "Tests pass" is NOT sufficient for visual changes.
- **Security fixes**: Proof that sensitive data is ABSENT from output (not just that tests pass)
- **Data migrations**: Before/after row counts, sample record inspection
- **Multi-layer changes**: Use ALL appropriate methods — a serializer change that affects a template prop that renders in the frontend needs both backend and UI verification

**The proof must be PASTED in card notes** via `bd update <id> --append-notes` before `bd close`.

**Why this exists:** In a prior incident, a security card was closed with only "tests pass" as evidence. In another, a serializer change was almost closed without verifying the navbar still rendered. Tests pass while production behavior is broken. Live testing catches what tests miss. Rule: nothing is done without live testing.

**The rule:** If you can't show live output proving the change works in the running app, the card is NOT done. Choose the right verification tool for what you changed. "Tests pass" is necessary but not sufficient.

**Check:** Is there a `bd update --append-notes` with live test proof BEFORE the `bd close` call? Does the proof method match the layer changed?

### Gate 19: API Response Changes Are 7-Layer Atomic — MANDATORY

**If your diff touches a serializer/presenter, controller render, or any code that changes an API response shape, all downstream layers must be updated atomically.** The number of layers varies by project, but the principle is absolute: partial updates leave the contract inconsistent.

**Example layers (adapt to your project):**
1. **Serializer/presenter** — add/modify the field
2. **Route** — add/modify if new endpoint
3. **Request/integration spec** — test with specific expected values
4. **API schema** — update the schema for affected response types (e.g., OpenAPI YAML, protobuf, GraphQL)
5. **Contract test** — validate real response matches the updated schema
6. **Schema validation** — run your schema linter (e.g., `openapi:bundle`, `buf lint`, `graphql-inspector`)
7. **Live test** — curl/httpie against the running dev server with real data

**This applies to BOTH new endpoints AND modifications to existing endpoints.** Adding a field to an existing serializer is the same obligation as creating a new endpoint.

**Why this exists:** In a prior incident, a new field was added to two serializers (layers 1-3) but the API schema, contract tests, and live test (layers 4-7) were not done. The card was closed as "done." Rule: if you change one layer, you must update all downstream layers. It is actually 7 layers — LIVE TEST WITH REAL TOKEN AND DATA.

**Check:** Does your diff touch a serializer or controller render? If yes, all downstream layers must be in the diff + card notes (live test output). If any are missing, the card is NOT done.

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

**Before running `bd close`, invoke the project-ac-verify skill on `<card-id>`.** This conducts an independent review that checks every AC against the code diff AND the referenced design document section. The reviewer has no investment in closing the card — its only job is verification.

A `bd gate` was created at card start (Gate 0 step 7). This gate blocks `bd close` mechanically until the project-ac-verify skill resolves it. Using `bd close --force` to bypass is an auditable escape hatch — not a shortcut.

**Why this exists:** In a prior incident, an agent closed cards with incomplete ACs — XLSX substituted with TSV, YAML skipped, tests that only checked `typeof === 'function'`. The agent self-assessed "done" and was wrong every time. An independent reviewer reading the ADR section and the diff would have caught all of these in seconds.

**The rule:** Self-assessment is necessary but not sufficient. Independent review is the gate.

**What the reviewer checks:**
- Every AC against specific evidence in the diff (line numbers, test names)
- The referenced design doc section against the implementation — does the code match the spec?
- Anti-pattern violations (from the card's Anti-patterns section)
- Type safety (no `as any`, `as unknown`, `// @ts-ignore`)
- Test quality (no assertions that pass with broken code — Gate 4)

**Check:** Is there a resolved AC verification gate on this card? If not, run the project-ac-verify skill.

When closing a card:

**Before ANY close action, check yourself:**
- Did you run `bd show <card-id>` and read the full card THIS session? If not, STOP and read it.
- Did you create an AC verification gate at card start (Gate 0 step 7)? If not, create one now.
- Are you about to use `--force`? That bypasses the gate. Ask: WHY is the gate not resolved? Fix the reason, don't bypass the mechanism.
- Are you batching closes (closing 2+ cards in quick succession without full gate protocol on each)? That's velocity optimization. Slow down. One card, fully verified, then the next.

1. **Re-read every AC** on the card via `bd show <card-id>` — verify each one is done
2. **Resolve the AC verification gate** with specific evidence for each AC
3. Run `bd close <id> --reason "..."` with actual vs estimated time (never `--force`)
4. Run `bd dolt commit -m "<card summary>"` to checkpoint
5. Run `bd dolt push` to share with collaborators
6. **Suggest the next best card** — see "Suggest Next Card" below

## After Close: Next Card + Verification Checklist

After closing a card, read [references/close-protocol.md](references/close-protocol.md) for the suggest-next-card workflow, time tracking, and the full verification checklist (all gates summarized as checkboxes).

## Related Skills

- project-card skill — Card template for beads issues. Invoke before `bd create`.
- test-driven-development skill — Base TDD cycle (Red-Green-Refactor).
