---
name: package-audit
description: >-
  Audit a package's source code across four domains: DRY/maintainability,
  architecture, test quality, and security. Produces prioritized, card-ready
  findings. Use when reviewing a package before planning improvements, when
  onboarding to an unfamiliar codebase, or when asked to assess code quality.
license: Apache-2.0
metadata:
  argument-hint: "<package-path> [scope]"
  arguments: "package, scope"
---

# Package Audit

## Overview

Run a systematic audit of a package's source code and produce findings as card-ready descriptions that can be filed directly as an epic with ordered cards. The audit covers four domains: DRY/maintainability, architecture, test quality, and security.

**Announce at start:** "Running package-audit on `$package`."

## Arguments

- `$package` — path to the package directory (e.g., `packages/my-api`)
- `$scope` — optional focus: `dry`, `architecture`, `test-quality`, `security`, or `all` (default: `all`)

If no scope is provided, ask the user:

**Which domains should this audit cover?**
- "All four domains" — DRY, architecture, test quality, and security (default)
- "DRY + architecture only" — code structure and maintainability focus
- "Test quality only" — coverage gaps, assertion quality, flaky test sources
- "Security only" — dependency vulnerabilities, input validation, credential handling

## Pre-Audit: Gather Project Standards

Before analyzing code, read the project's coverage policy and existing audit state:

1. **Coverage thresholds** — read from `codecov.yml` or root `CLAUDE.md` (Coverage Policy section). Default: 95%+ statements / 90%+ branches for all packages. Use the project's thresholds, never hardcode.
2. **Existing cards** — run `bd search "<package-name>"` to find cards already filed for this package. Do NOT create duplicate findings for work already on the board.
3. **Prior audit** — check `docs/audits/` for a previous audit of this package. If one exists, the report must include a **Delta** section showing what improved, what regressed, and what's new since last audit.
4. **Package CLAUDE.md** — read `<package>/CLAUDE.md` for stated conventions, current state, and gotchas.

## Audit Domains

### 1. DRY / Maintainability

Look for:
- Duplicated code patterns across files (same logic in 2+ places)
- Duplicated type definitions (identical or near-identical interfaces)
- Hardcoded values that should be constants or parameters
- Copy-paste patterns where a shared helper would serve
- Inconsistent approaches to the same problem across files

**How to find them:**
- Read every source file in `src/`
- Compare function signatures and bodies across files
- Look for repeated import patterns
- Count how many files define their own version of a common pattern

### 2. Architecture

Look for:
- Circular or wrong-direction dependencies
- Files that violate the package's layering (e.g., HTTP in a data-only package)
- Missing barrel exports for public API
- Functions doing too many things (>50 lines of mixed concerns)
- Inconsistent naming conventions
- Dead code (exported but never imported)

**How to find them:**
- Read the package's CLAUDE.md for stated conventions
- Check imports for dependency direction violations
- Compare exports vs actual consumers across sibling packages

### 3. Test Quality

Look for:
- Weak assertions: `.toBeGreaterThan(0)` on deterministic data, `>= 0` tautologies
- Missing assertions: `expect(true).toBe(true)`, tests that execute code but assert nothing meaningful
- Missing edge case coverage: null inputs, empty arrays, conflict/upsert paths, error branches
- Missing isolation: tests that pass because of shared state, not because the code works
- Mocks hiding real behavior: mock returns what the test expects, proving nothing
- Coverage gaps: files with 0% or very low branch coverage

**The key question for every assertion:** "Would this test still pass if the code were broken?" If yes, the assertion is worthless — flag it.

**How to find them:**
- Read every test file
- For each assertion, ask the key question above
- Run coverage and identify files below the package's branch threshold
- Check that error paths are tested, not just happy paths

### 4. Security

Look for:
- Unvalidated JSON.parse with type assertions (`as any`, `as SomeType`)
- SQL injection vectors (string interpolation in queries vs parameterized)
- Path traversal in user-provided file paths
- Missing input validation at trust boundaries
- Unsafe type casts that bypass runtime validation
- XXE/injection in XML parsing
- Secrets or credentials in source

**How to find them:**
- grep for `as any`, `as unknown`, `JSON.parse`, `readFileSync` with user input
- Check every `sql` template tag for parameterized values
- Check CLI flag handling for path sanitization

## Cross-Package Impact

For every DRY or architecture finding, check whether sibling packages are affected:

- If a type is duplicated, is it also duplicated in consuming packages?
- If a helper should be extracted, would other packages benefit from importing it?
- If a convention is violated, is the same violation present elsewhere?

Flag cross-package findings explicitly with the affected packages listed. These become higher priority because they multiply the benefit.

## DRY-Coverage Linking

When a DRY extraction would reduce code surface in multiple files, explicitly connect it to the coverage impact:

> **Finding 7:** `buildLookupMap` duplicated in 3 files (e.g., `seed-a:45`, `seed-b:62`, `seed-c:31`).
> **Coverage impact:** Extracting to a shared helper and testing once would raise branch coverage on all 3 files from ~65% to ~80% without writing per-file tests.

This connection is critical — DRY work IS coverage work. Don't list them as separate findings when one extraction solves both problems.

## Execution

### Step 1: Gather Context

```
1. Read <package>/CLAUDE.md
2. Read codecov.yml or root CLAUDE.md for coverage thresholds
3. bd search "<package-name>" — existing cards (avoid duplicates)
4. ls docs/audits/*<package-name>* — prior audit reports
5. find <package>/src -type f -name '*.{ts,py,rb,go}' | sort — all source files
6. find <package>/test -type f -name '*.{ts,py,rb,go}' | sort — all test files
7. Run your test suite with coverage (e.g., `vitest run --coverage`, `pytest --cov`, `bundle exec rspec`, `go test -cover ./...`)
8. wc -l <package>/src/**/* | sort -n — lines per file for prioritization
```

### Step 2: Parallel Analysis

Analyze in 3 parallel passes (or sequentially if scope is narrowed):

**Agent 1: DRY + Architecture**
- Read every source file
- Identify duplicated patterns with exact file:line references
- Identify architecture violations
- Check cross-package impact for each finding
- Classify each finding: bug (fix now) vs DRY violation vs inconsistency

**Agent 2: Test Quality**
- Read every test file
- For each assertion, apply the key question: "Would this pass if the code were broken?"
- Cross-reference coverage report — which files are below the package's threshold?
- Identify where DRY extraction would mechanically improve coverage (link to Agent 1 findings)
- Identify missing test categories (no error path tests, no edge cases)

**Agent 3: Security**
- Read every source file
- Check all JSON.parse, type assertion, SQL, file path, and input validation patterns
- Classify: HIGH (exploitable), MEDIUM (defense-in-depth gap), LOW (code hygiene)

### Step 3: Compile Findings

Merge findings from all agents. For each finding:

1. **Classify** — bug | dry-violation | inconsistency | weak-test | security
2. **Severity** — P0 (bug, fix now) | P1 (high-value improvement) | P2 (cleanup)
3. **Estimate** — sp:N and Claude-pace minutes
4. **Dependencies** — which findings must be done before others
5. **Cross-package** — which sibling packages are affected
6. **Coverage impact** — does fixing this mechanically improve coverage? On which files?
7. **Dedup** — does a beads card already exist for this? If yes, note the card ID and skip.

### Step 4: Write Report

Save to: `docs/audits/YYYY-MM-DD-<package-name>-audit.md`

## Report Format

```markdown
# <Package Name> Audit Report — YYYY-MM-DD

## Summary
- **Files analyzed:** N source, N test
- **Coverage:** N% statements / N% branches (target: from project config)
- **Findings:** N total (N bugs, N DRY, N test quality, N security)
- **Cross-package findings:** N (affecting packages X, Y)
- **Existing cards found:** N (skipped as duplicates)

## Delta (if prior audit exists)
- **Improved since YYYY-MM-DD:** [list findings that were fixed]
- **Regressed:** [list new issues not in prior audit]
- **Unchanged:** [list findings still open]

## Coverage Matrix

| File | Stmts | Branches | Target | Gap | Notes |
|------|-------|----------|--------|-----|-------|
| ... | ... | ... | from config | ... | DRY extraction would help |

## Findings

### Finding 1: [Title]
- **Type:** bug | dry-violation | inconsistency | weak-test | security
- **Severity:** P0 | P1 | P2
- **Files:** exact paths with line numbers
- **Description:** What's wrong and why it matters
- **Evidence:** Code snippets showing the issue
- **Cross-package impact:** [affected packages, or "none"]
- **Coverage impact:** [which files improve if fixed, or "none"]
- **Existing card:** [card ID if already filed, or "none"]

## Epic: <Package Name> Quality Improvements

### Dependency Order
finding-3 → finding-1 → finding-2 → finding-5 → finding-4

### Cards

[Each card follows the template below]
```

## Card Template

Every finding becomes a card following this exact format:

```markdown
### Card N: [Verb] [what] — [context]

**Type:** bug | task | feature
**Priority:** P0 | P1 | P2
**Story points:** sp:N
**Estimate:** N min (Claude-pace)

**Description:**
[What this card delivers and why it matters. 2-3 sentences.]

**Files:**
- Create: [exact paths of new files]
- Modify: [exact paths of files to change]
- Test: [exact paths of test files]

**First failing test:**
[The exact test to write first — TDD starting point]

**Acceptance criteria:**
- [ ] [Specific testable condition 1]
- [ ] [Specific testable condition 2]
- [ ] [Specific testable condition 3]
- [ ] All work via TDD (failing test first)
- [ ] No regressions on existing tests

**Verification:**
[exact test/lint command that proves this card is done — e.g., `pytest --cov`, `vitest run`, `bundle exec rspec`]

**Decision points:**
- [Situations where the implementer MUST stop and ask before proceeding]

**Anti-patterns:**
- [Specific things NOT to do]

**Depends on:** [card N, or "none"]
**Cross-package:** [affected sibling packages, or "none"]
**Coverage impact:** [files that improve, or "none"]
```

## Filing Cards (after user approval)

Once the user approves the report and card ordering:

```bash
# Create the epic
bd create --title="[EPIC] <Package> quality improvements" \
  --description="<from report summary>" \
  --type=epic --priority=1

# Create each card (in dependency order)
bd create --title="<card title>" \
  --description="<full card body from template>" \
  --type=<bug|task> --priority=<0-2>

# Wire dependencies
bd dep add <child-id> <parent-id>
```

Do NOT file cards until the user explicitly says to. Present the report first, wait for approval, then file.

## Estimation Guide

| sp | Task shape | Claude-pace |
|---|---|---|
| 1 | One-line edit, rename, config tweak | 3-8 min |
| 2 | Single-file refactor + test | 8-15 min |
| 3 | Multi-file change + new test fixture | 15-25 min |
| 5 | Cross-package refactor, new route end-to-end | 25-45 min |
| 8 | New service with external integration | 45-90 min |

## Rules

- **NEVER** exclude files from coverage to make numbers look better
- **NEVER** weaken assertions to make tests pass
- **NEVER** test over bugs — find root cause always
- **NEVER** classify something as "pre-existing" to avoid fixing it
- **NEVER** file cards or start fixing without user permission
- **NEVER** make decisions about priority ordering — present options, user decides
- Report ALL production source files honestly — no denominator tricks
- Every finding must have exact file:line references
- Every card must follow the template exactly — no shortcuts
- DRY findings that reduce code surface come before coverage work in dependency order
- Bug findings are always P0 regardless of domain
- Cross-package findings are higher priority than single-package findings
- Link DRY extractions to their coverage impact — don't treat them as separate problems

## After the Audit

Present the report to the user. Do NOT:
- File cards without permission
- Start fixing things
- Close or update existing cards
- Make decisions about priority ordering
- Decide what to defer vs what to do now

The user decides what to do with the findings.
