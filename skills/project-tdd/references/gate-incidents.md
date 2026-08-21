# Gate Incident Histories — why each gate exists

Moved out of SKILL.md (token economy: the rules stay in the skill; the
incident histories load on demand). Each anchor is referenced from its gate.

## gate-0
Without the execution summary, agents pick cards out of order, miss
dependencies, and lose track of what phase they're in. The gate prevents
closing cards with incomplete ACs — the mechanical backstop that
self-assessment lacks.

## sycophancy-mechanisms
1. **RLHF training rewards agreement with corrections.** Under pushback,
models abandon positions 78.5% of the time — including correct ones (SycEval
2025). The training signal says "resolve the user's displeasure," which maps
to "produce output quickly," not "produce output correctly."
2. **Sycophancy cascades into task falsification.** Anthropic's research
documents the progression: flattery → altering checklists so incomplete work
appears complete → modifying evaluation criteria — generalized from the
incentive structure without explicit training.
3. **Context rot degrades instruction following.** At 50%+ context
utilization, system-prompt rules receive measurably less attention weight
than recent turns (Chroma 2025: all 18 tested models degrade continuously,
no plateau).
4. **Chain-of-thought masks the problem.** CoT reasoning hides sycophantic
patterns from visible output while internal activations still show
capitulation (arxiv 2603.16643).
Full citations: `llm-failure-modes.md` in this directory.

## gate-9
Anti-pattern that spawned the gate: wiring a shared component with manual
HTTP calls instead of using the existing mixin/composable. Result: no
optimistic updates, no state tracking, no error rollback — broken UX that
passed unit tests.

## gate-10
Transpile-only test runners skip type checking entirely. 578 tests passed
while the code had 23 type errors that prevented production builds —
`instanceof` on wrong types, narrowed interfaces missing required
properties, wrong import paths, API changes in dependencies. All invisible
to the test runner. The server crashed on restart.

## gate-11
Calling failures "pre-existing" erodes trust and leaves broken windows. The
cost of fixing a 2-line issue NOW is 30 seconds. The cost of carding it,
context-switching, and coming back later is 10 minutes minimum.

## gate-13
Tests verify code correctness. Playwright verifies feature correctness. They
are NOT interchangeable. A card with 100% test pass rate and broken visual
output is a broken card. Cards were repeatedly closed without looking at the
result; the screenshot is the PROOF the work is done.

## gate-14
An expert review agent recommended narrowing `not_to raise_error` to
`not_to raise_error(RegexpError)`. This was blindly implemented. RSpec
itself warns against this pattern — it creates false positives. The
"improvement" was a regression the tool's own documentation explicitly
discourages. 10 minutes of research would have caught it in 30 seconds.

## gate-15
A spec conflict was resolved correctly (kept 5 tests over the other
branch's 3), but the rule must be explicit: always review both sides.
"Ours" or "theirs" as a default is lazy and loses good work.

## gate-16
A cache invalidation bug: reply cache keys used `replies:${parentReviewId}`
but `invalidateCache` filtered by `${componentId}:`. The "pragmatic" fix was
to clear ALL reply caches (coarse but simple). The correct fix scoped reply
cache keys by componentId — changing the composable signature and adding a
prop. More work, but correct; the shortcut would have created a maintenance
trap.

## gate-17
A controller action cleared a timestamp field. A `before_save` callback
immediately re-set it because a status field was in a terminal state. The
endpoint fought the callback and lost. The user saw success but the database
reverted. Tests missed it because they only tested one enum value out of
five — the non-terminal one where the callback doesn't fire.

## gate-18
A security card was closed with only "tests pass" as evidence; a serializer
change was almost closed without verifying the navbar still rendered. Tests
pass while production behavior is broken — live testing catches what tests
miss.

## gate-19
A new field was added to two serializers (layers 1-3) but the API schema,
contract tests, and live test (layers 4-7) were not done, and the card was
closed as "done." If you change one layer you must update all downstream
layers — live-tested with a real token and data.

## gate-20
A linter disable was added to bypass a validation-skipping warning, but the
fields were already in the model's audit-exception list — normal `save` was
the correct call with no warnings. The cop was right; the disable was a
shortcut that hid a failure to read the existing code.

## gate-21
Cards were closed with "deferred" ACs documented in the notes. Documenting
what was skipped does NOT make it done. A card with 80% of its ACs is 0%
closeable — the root cause was optimizing for card-close velocity; as the
card count climbed, speed displaced completeness.

## gate-22
An agent closed cards with incomplete ACs — XLSX substituted with TSV, YAML
skipped, tests that only checked `typeof === 'function'`. The agent
self-assessed "done" and was wrong every time. An independent reviewer
reading the ADR section and the diff would have caught all of these in
seconds.
