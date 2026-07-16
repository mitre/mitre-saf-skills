# Plan: TDD Enforcement Hooks for project-tdd Skill

**Status:** Draft
**Date:** 2026-06-25
**Author:** Aaron Lippold
**Skill:** skills/project-tdd/
**Card:** mitre-saf-skills-4cp (to be split)

---

## 1. Problem

The project-tdd skill says "NO PRODUCTION CODE WITHOUT A FAILING TEST FIRST" but has no mechanical enforcement. An agent followed all other gates (Gate 0 epic context, Gate 22 AC verification) while skipping the BASE RULE on 6 consecutive cards. The text-only rule was treated as advisory, not mandatory.

**Root cause:** Skills are passive text loaded into context. An agent can read the rule and choose not to follow it. There is no enforcement layer between "the skill says X" and "the agent does X."

**Impact:** 6 cards of production code written without tests. 8 test gaps discovered after the fact. ~45 minutes of retroactive test writing needed. Trust eroded.

## 2. Design Principles

1. **Skills should bundle their enforcement** — if a skill depends on a behavior, it should have a mechanism to enforce it, not just describe it
2. **Platform-agnostic where possible** — CI gates work for any agent on any platform
3. **Platform-specific where needed** — Claude Code hooks for real-time enforcement
4. **Defense in depth** — multiple layers, not one point of failure
5. **Not project-specific** — detection of src/ vs test/ must work across projects with different conventions

## 3. Three Enforcement Layers

### Layer 1: CI Gate Script (universal)

A shell script that runs in CI and blocks PRs where production files changed without corresponding test files.

```bash
# Detects production vs test files by convention:
# Production: /src/, /lib/, /app/ (excluding test patterns)
# Test: /test/, /spec/, /__tests__/, *.spec.*, *.test.*
```

- Works for ANY agent, ANY platform, ANY language
- Catches violations at PR time regardless of how they were made
- NOT real-time — violations are caught after commit, not before

### Layer 2: Claude Code PreToolUse Hook (real-time)

A shell script that fires before every Edit/Write tool call in Claude Code.

- Checks if target file is production code (src/, lib/, app/)
- Checks if a test file was edited in the current session (tracked via temp file)
- If production file AND no test edited → blocks with error message
- If test file → records and allows

**Session tracking:** Uses a temp file keyed by working directory hash. Resets on new session.

**Test directory detection:** Configurable via a `.tdd-gate.config` file in the project root, or defaults to common conventions (test/, spec/, __tests__, *.spec.*, *.test.*).

### Layer 3: Skill Setup Check (invocation-time)

When `/project-tdd` is invoked, the skill checks whether the enforcement hook is installed:

- Checks `~/.claude/settings.json` for the PreToolUse hook entry
- If missing: warns and provides setup instructions
- If present: confirms enforcement is active

## 4. File Structure

```
skills/project-tdd/
  SKILL.md                          ← existing skill (add Required Hook section)
  hooks/
    ci/
      tdd-check.sh                  ← CI gate script
      tdd-check.spec.sh             ← tests for the CI gate
    claude/
      tdd-gate.sh                   ← Claude Code PreToolUse hook
    config/
      tdd-gate.defaults.conf        ← default test directory patterns
  setup/
    claude-code.md                  ← Claude Code setup instructions
    ci-integration.md               ← CI integration guide (GitHub Actions, etc.)
  references/                       ← existing
```

## 5. Test Directory Detection

Different projects use different conventions:

| Convention | Languages/Frameworks |
|-----------|---------------------|
| `test/` | Node.js, Ruby, Python |
| `spec/` | Ruby (RSpec), Jasmine |
| `__tests__/` | Jest |
| `*.spec.ts` | Vitest, Jest |
| `*.test.ts` | Jest, Vitest |
| `tests/` | Python (pytest), PHP |
| `*_test.go` | Go |
| `*_spec.rb` | RSpec |

The CI gate and Claude hook should detect test files using a configurable pattern list. Default: `test/ spec/ __tests__/ *.spec.* *.test.* *_test.* *_spec.*`

Projects can override via `.tdd-gate.conf` in repo root:
```
TEST_PATTERNS="test/ spec/ cypress/ e2e/"
SRC_PATTERNS="src/ lib/ app/ packages/"
```

## 6. Work Order

| Card | Scope | sp | Depends on |
|------|-------|----|-----------|
| 1 | CI gate script + tests — universal PR-level enforcement | 2 | — |
| 2 | Claude Code PreToolUse hook + session tracking | 3 | — |
| 3 | Test directory detection config — project-level overrides | 1 | 1, 2 |
| 4 | SKILL.md update — Required Hook section + setup check | 2 | 2, 3 |
| 5 | Setup documentation — Claude Code + CI integration guides | 1 | 1, 2, 3, 4 |

**Total: sp:9, ~40 min Claude-pace**

## 7. Future Work (not in scope)

- Gemini CLI hook equivalent (when platform supports hooks)
- Codex hook equivalent (when platform supports hooks)
- Auto-registration of hooks on skill first-use (Claude Code feature request)
- Verification that the test is actually RED (not just that a test file was edited)
- Integration with the superpowers test-driven-development skill (base skill)
