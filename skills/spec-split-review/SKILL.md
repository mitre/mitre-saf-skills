---
name: spec-split-review
description: >-
  Split large RSpec files into domain-focused files, review grouping quality,
  find test gaps, and verify parallel safety. Use when any RSpec spec file
  exceeds 500 lines, after a spec split to audit quality, or for periodic
  test suite health checks.
compatibility: Requires Ruby, RSpec, and Rails (or similar test framework)
license: Apache-2.0
---

# Spec File Split + Expert Review

Split large spec files into domain-focused files with expert agent review for grouping quality, test gap analysis, and parallel safety. Captures all best practices learned from production incidents.

## Two Modes

This skill supports two entry points:

### Split Mode (default)
Invoke with a monolith spec file path:
```
/spec-split-review spec/requests/orders_spec.rb
```
Runs Phases 1 → 7: audit → split → verify → expert review → card → harden.

### Audit Mode
Invoke with `audit` + a glob or directory:
```
/spec-split-review audit spec/requests/orders_*_spec.rb
/spec-split-review audit spec/models/products_*_spec.rb
```
Skips Phases 1-3 (the files are already split). Runs Phase 1b (coverage baseline) → Phase 4 (expert review) → Phase 5 (parallel safety) → Phase 6 (card findings) → Phase 7 (advanced verification). Use this to:
- Audit tests that were split before this skill existed
- Re-audit after production code changes to catch test drift
- Periodic health checks on high-churn test suites
- Verify a collaborator's split meets quality standards

### Audit Mode Pre-Analysis

Before launching expert agents in audit mode, run the test-prof profiling suite to identify bottlenecks:

```bash
# Step 1: Profile by test type — find the slowest categories
TAG_PROF=type TAG_PROF_FORMAT=html TAG_PROF_EVENT=sql.active_record,factory.create \
  bundle exec rspec spec/path/to/files_*_spec.rb

# Step 2: Factory cascade detection — find factories that trigger excessive creates
FPROF=flamegraph bundle exec rspec spec/path/to/files_*_spec.rb
# Generates tmp/test_prof/factory-flame.html — look for tall stacks

# Step 3: Event profiling — find tests with excessive SQL or factory usage
EVENT_PROF=sql.active_record bundle exec rspec spec/path/to/files_*_spec.rb
EVENT_PROF=factory.create bundle exec rspec spec/path/to/files_*_spec.rb
```

Feed these profiling results to the expert agents as context — they can identify WHY tests are slow, not just which ones.

### Audit Mode Expert Agents

In audit mode, add these extra expert dimensions beyond the standard 6-10:

| Expert | What it checks |
|--------|---------------|
| **Test drift detector** | Read git log for the production file since the tests were last modified. Are there new methods/callbacks/validations added to production code that have zero test coverage? |
| **Factory efficiency** | Do tests create more records than needed? Could `build_stubbed` replace `create` for tests that don't hit the DB? Are there factory cascades (creating a Parent record creates 250+ Child records)? |
| **Performance profiler** | Given TagProf/EventProf output, which tests are disproportionately slow? Why? (Usually: unnecessary expensive fixture parse, factory cascade, or missing eager_load) |

## When to Use (either mode)

- **Split mode:** Any spec file exceeding **500 lines** (hard cap)
- **Audit mode:** Any set of split spec files that haven't been reviewed, or after significant production code changes
- Target: **~300 lines per file**
- Proactively: audit with `find spec/ -name '*.rb' -exec wc -l {} + | sort -rn | head -20`

## Phase 1: Audit the File

Before splitting, understand the file structure:

```bash
# Map describe/context blocks
grep -n "^\s*describe\|^\s*context " spec/path/to/file_spec.rb

# Count total tests
bundle exec rspec spec/path/to/file_spec.rb --format progress --dry-run 2>&1 | grep examples

# Check shared setup (let_it_be, before_all, before)
grep -n 'let_it_be\|before_all\|before do' spec/path/to/file_spec.rb | head -20
```

Map each `describe` block to a domain. Group related describes into files. Each file should have a **single cohesive theme** that a developer can find by filename.

## Phase 1b: Capture Coverage Baseline

Before splitting, capture the coverage baseline so you can prove zero coverage lost after:

```bash
# Run the original file with coverage tracking
COVERAGE=true bundle exec rspec spec/path/to/original_spec.rb

# Record which production file(s) this spec exercises
grep -n 'describe\|subject' spec/path/to/original_spec.rb | head -5
# → identifies app/controllers/foo_controller.rb, app/models/foo.rb, etc.

# Capture the baseline metrics:
# 1. Total example count (e.g., 41 examples)
# 2. Lines covered in the production file (from coverage/index.html or SimpleCov output)
# 3. Line coverage % for that production file
```

Save these three numbers. After the split, you must match or exceed all three.

### Coverage Goals

| Metric | Before split | After split | Pass? |
|--------|-------------|-------------|-------|
| Example count | Must record | Must equal before | Exact match required |
| Lines covered | Must record | Must equal or exceed before | No line goes from green→red |
| Coverage % | Must record | Must equal or exceed before | Split cannot reduce coverage |

### Why This Matters

The split is supposed to be a pure structural refactor. If coverage drops, the split broke a test's implicit dependency on shared state (e.g., a `let_it_be` record created by one describe block and accidentally used by another). The coverage diff catches this even when example counts match.

### After Expert Review — Coverage Gap Report

The expert agents identify lines that are red (untested) in the production file. These become test gap cards. The coverage baseline lets you distinguish:
- **Pre-existing gaps** — red before AND after the split (card them, but they're not regressions)
- **Regressions** — green before, red after (fix immediately — the split broke something)
- **New coverage** — red before, green after (only if you added tests during the split — should not happen in a pure split)

## Phase 2: Extract Shared Context

Read the file-level setup (everything before the first `describe` block). Extract into a shared context:

```ruby
# spec/support/shared_contexts/{model}_model_base.rb
RSpec.shared_context '{model} model base setup' do
  # ONLY records used by MULTIPLE domain files
  let_it_be(:shared_org) { create(:organization) }
  let_it_be(:shared_project) { create(:project) }
  # ...
end
```

### Shared Context Rules

1. **Minimal** — only include records that 2+ domain files actually use. If only one file uses it, keep it local to that file.
2. **No @ivar aliases** — use `let_it_be` names directly. The `@ivar = shared_x` dual-naming pattern creates ambiguity and cognitive overhead. (Evil Martians test-prof docs recommend let_it_be directly.)
3. **Use `create!` not `create`** — silent failures in test setup waste hours debugging.
4. **Use FactoryBot `create(:model)` not `Model.create!`** — factories validate, are DRY, and catch regressions.
5. **Global `refind: true`** — must be set in rails_helper.rb (see Parallel Safety below). Per-declaration `refind: true` is then redundant — remove it.
6. **No name collisions** — if multiple shared contexts exist, prefix let_it_be names: `orders_org`, `products_org`.

## Phase 3: Create Domain Files

Each new file follows this pattern:

```ruby
# frozen_string_literal: true

require 'rails_helper'

RSpec.describe ModelName do
  include_context '{model} model base setup'

  # ... describe blocks from original file, EXACTLY as-is ...
end
```

### Split Rules

1. **Copy test code EXACTLY** — zero modifications to logic, assertions, variable names, comments.
2. **let_it_be/let/before INSIDE a describe/context stays with that block** — don't hoist to shared context.
3. **Flat naming** — `orders_fulfillment_spec.rb`, not `orders/fulfillment_spec.rb`. Matches existing convention.
4. **File name = domain theme** — a developer searching for "fulfillment tests" finds `orders_fulfillment_spec.rb`.
5. **rubocop:disable comments** — only carry forward to files that actually need them. Check `.rubocop.yml` for global excludes first (e.g., `Rails/SkipsModelValidations` is already excluded for all spec/).

### Verification After Each File

```bash
# Run the new file independently
bundle exec rspec spec/path/to/new_file_spec.rb --format progress

# Verify test count matches
bundle exec rspec spec/path/to/all_new_files_spec.rb --format progress | grep examples
# Must equal original count EXACTLY
```

### After All Files Created

```bash
# Delete original
rm spec/path/to/original_spec.rb

# Run all new files together
bundle exec rspec spec/path/to/model_*_spec.rb --format progress
# Total must equal original count

# Lint
bundle exec rubocop spec/path/to/model_*_spec.rb
# Zero offenses
```

### Phase 3b: Verify Coverage Not Reduced

```bash
# Run the split files with coverage
COVERAGE=true bundle exec rspec spec/path/to/model_*_spec.rb

# Compare against Phase 1b baseline:
# 1. Example count — must match exactly
# 2. Lines covered — must equal or exceed baseline
# 3. Coverage % — must equal or exceed baseline
```

If any production line was covered before the split but NOT after:
- **This is a regression.** The split broke an implicit dependency.
- **Do NOT proceed to Phase 4.** Fix the regression first.
- Common cause: a `let_it_be` record created in describe block A was accidentally used by describe block B. After the split, block B is in a different file and lost access.

If coverage increased (unlikely in a pure split):
- Verify no new tests were accidentally added.
- If they were, that's scope creep — move them to a separate card.

**Only proceed to Phase 4 (expert review) after coverage is verified equal or better.**

## Phase 4: Expert Review (MANDATORY)

After the mechanical split, launch an expert agent swarm to review the results. **Never skip this.** The split agent is good at moving code; it cannot judge domain boundaries, find test gaps, or spot parallel safety issues.

### Pre-Analysis: Choose the Right Experts

Before launching agents, analyze WHAT was split to select the right expert dimensions:

```bash
# What domain is this? (model, controller, service, integration)
head -5 spec/path/to/new_files_spec.rb

# What production code does it test?
grep -n 'describe\|subject' spec/path/to/new_files_spec.rb | head -5

# What does that production code DO?
grep -n 'def \|scope \|validates\|before_\|after_\|has_many\|belongs_to' app/path/to/model.rb | wc -l
```

**Match experts to the domain:**

| File tests... | Include these expert agents |
|--------------|---------------------------|
| A model with callbacks | Callback safety expert (trace all enum values × callbacks) |
| A model with validations | Validation coverage expert (every validates + rejection path) |
| A model with scopes | Scope coverage expert (matching + non-matching records) |
| A service with transactions | Transaction safety expert (rollback paths, error handling) |
| A controller with auth | Authorization expert (every role × every action) |
| A controller with JSON responses | API contract expert (response shape, Blueprint alignment) |
| An importer/exporter | Data integrity expert (round-trip, error paths, edge cases) |
| Anything with ActiveRecord | Association expert (dependent destroy/nullify, N+1, eager load) |
| Anything with Pinia/Vue | Frontend integration expert (store normalization, reactivity) |
| Any file using let_it_be | test-prof expert (refind, shared context quality) |
| Any file in parallel suite | Parallel safety expert (global state, ENV, Record.last) |

**Always include:** Split grouping quality, shared context quality, code quality/lint. These apply to every split regardless of domain.

**Minimum 6 agents, maximum 10.** More agents = more findings but diminishing returns past 10. Choose the 6-10 most relevant dimensions for THIS specific codebase and file.

### Review Dimensions (minimum 6 agents)

1. **Split Grouping Quality** — Are tests in the right domain file? Any that should move? Is the shared context minimal?
2. **Test Gap Analysis (Model A)** — Read the production model. For every public method, callback, validation, and scope, verify test coverage exists. List gaps with severity.
3. **Test Gap Analysis (Model B)** — Same for the second model if splitting two files.
4. **Shared Context Quality** — test-prof best practices, let_it_be modifiers, naming consistency, dead declarations.
5. **Parallel Test Safety** — ENV leaks, global state mutation, `Record.last` fragility, ensure-based state restore, factory sequence collisions.
6. **Code Quality** — redundant rubocop:disable, stale comments, dead let_it_be, orphaned instance variables.

### What Test Gap Agents Must Do

**BEFORE writing any finding, the agent MUST:**
1. **Read the production source file** — every public method, callback, validation, scope, association.
2. **Read ALL split spec files** — map which production code paths have tests.
3. **For each untested path** — classify as CRITICAL (could hide a bug), WARNING (should have), INFO (nice to have).
4. **Check real-world examples** — how do GitLab, Discourse, Shopify test similar patterns? Use Context7 MCP for test-prof, RSpec, Rails testing docs.
5. **Never dismiss a finding** — every gap gets reported. The human decides priority, not the agent.

### What Gap Agents Must Check

For EACH of these on the model under review:

| Category | What to check |
|----------|--------------|
| Public methods | Every method callable from outside the class. Does a test exist that calls it and asserts the return value? |
| Callbacks | Every before_save, after_save, before_create, after_create, before_validation, before_destroy. Is each branch tested? ALL enum values? |
| Validations | Every validates and validate. Is the happy path tested? Is the rejection path tested with the specific error message? |
| Scopes | Every scope. Is it tested with matching records AND non-matching records? |
| Associations | Every has_many, belongs_to, has_one. Are dependent: :destroy / :nullify behaviors tested? |
| Error paths | Every raise, errors.add, return early guard. Is each reachable by a test? |
| Edge cases | nil inputs, empty arrays, boundary values, SQL injection via user input |
| Callbacks × Enum values | If a callback branches on a status/type field, are ALL possible values tested? (A real bug existed because only 1 of 5 statuses was tested.) |

### Expert Review Output Format

Each agent returns structured findings:
```json
{
  "dimension": "test-gap-analysis",
  "findings": [
    {
      "severity": "CRITICAL",
      "title": "Method #foo has zero test coverage",
      "description": "...",
      "file": "app/models/bar.rb",
      "recommendation": "Add test in spec/models/bar_spec.rb: ..."
    }
  ]
}
```

### After Expert Review

**Card EVERY finding** using `/project-card`. Nothing dismissed. Group related findings into logical cards. Wire dependencies in implementation order.

## Phase 5: Parallel Safety Standards

These rules apply to ALL spec files, enforced during review:

### Global Configuration (rails_helper.rb)

```ruby
# Every let_it_be gets a fresh AR instance per example
TestProf::LetItBe.configure do |config|
  config.default_modifiers[:refind] = true
end
```

**Why:** `let_it_be` shares a single Ruby object across examples. The DB row is rolled back by the transactional fixture SAVEPOINT, but the in-memory AR object retains mutated attributes and cached associations. `refind: true` calls `Model.unscoped.find(id)` per example — fresh instance, no cached associations. The test-prof docs explicitly warn: "`reload` may not be enough, 'cause it doesn't reset associations."

### Enforcement (custom RuboCop cop)

`YourApp/LetItBeRefind` — warns on `let_it_be(:x, refind: false)` which overrides the safe global default.

### Parallel Safety Checklist

| Pattern | Risk | Fix |
|---------|------|-----|
| `ENV['X'] = value` in before/after | ENV leaks to other tests in same worker | Use `climate_control` gem |
| `Record.last` for identity | Fragile if setup creates extra records | Use scoped query or response ID |
| `Audited.auditing_enabled = false` | Global class state mutation | Use `Model.without_auditing { }` |
| `ensure { record.update_columns(...) }` on let_it_be | Fragile — exception in ensure leaks state | Use local record or before/after pair |
| `update_all` in `before_all` | Permanent for the example group | Only use in `before` (per-example, rolled back) |
| `let_it_be(:x, refind: false)` | Overrides safe global default | Remove — let global handle it |

## File Size Standards

| Lines | Action |
|-------|--------|
| ≤ 300 | Ideal — no action |
| 301–500 | Acceptable — monitor |
| 501–800 | Split when touching the file |
| 800+ | Split immediately |

## Periodic Audit Cadence

When planning recurring audits or setting up test drift detection, read [references/audit-cadence.md](references/audit-cadence.md) for the trigger table and detection methodology.

## Decision: When NOT to Split

- **Single integration test** with expensive setup (e.g., integration_round_trip_spec.rb — one test scenario, splitting would duplicate the setup cost)
- **Parametric test files** where a loop generates many examples from one describe block (the file is large but cohesive)
- **Contract test files** that mirror an OpenAPI spec structure (splitting would break the 1:1 path↔test mapping)

In these cases, document WHY the file is large with a comment at the top.

## Research Requirements

Before implementing ANY recommendation from the expert review:

1. **Read the actual docs** — test-prof, RSpec, Rails testing guides, parallel_tests
2. **Check real-world examples** — how do GitLab (5000+ spec files), Discourse, Shopify structure their tests?
3. **Use Context7 MCP** — fetch current documentation for test-prof, RSpec shared contexts, parallel_tests
4. **Verify claims** — if an agent says "use X pattern," find the documentation that confirms it works as described
5. **Test locally** — run the specific files you changed, not the full suite repeatedly

## Phase 6: Card + Wire All Findings

If using beads for issue tracking, read [references/carding-findings.md](references/carding-findings.md) for the full card grouping template, dependency wiring order, and centralized helper extraction patterns.

If not using beads, file findings as issues in your project's tracker with the same grouping: Foundation → Structure → Coverage → Helpers.

## Phase 7: Advanced Verification

After carding findings and before closing the epic, read [references/advanced-verification.md](references/advanced-verification.md) for:
- Test isolation verification (individual vs combined runs)
- Race condition testing (concurrent access patterns)
- Mutation testing with `mutant` (optional deep verification)
- Flaky test prevention checklist (8 common sources)
- N+1 query detection (exposed by the split)

## Anti-Patterns (from real incidents)

| Anti-pattern | What happened | Correct approach |
|-------------|--------------|-----------------|
| `@ivar = let_it_be_var` dual naming | Two names for same object, mixed usage across files, cognitive load | Use let_it_be names directly |
| `Association.create` (no bang) in setup | Silent failure → tests run with missing permissions → false failures | Always `create!` or FactoryBot `create` |
| `reload` instead of `refind` | `record.reload` refreshes columns but preserves cached associations | Global `refind: true` — fresh AR instance |
| Heavyweight shared context included but unused | expensive fixture parse per example for zero benefit | Only include what the file actually uses |
| Tests in wrong domain file | A real bug hid in a 2000-line monolith for months | Each file = one domain, findable by filename |
| `Record.last` for identity | Breaks when setup or action creates extra records | Scoped query or response body ID |
| Dismissing agent findings | Synthesizer dismissed 12 findings as "false positives" — all were real | Card EVERYTHING. Human decides priority. |
