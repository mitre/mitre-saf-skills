# Phase 6: Card + Wire All Findings

After the expert review returns findings, invoke the project-card skill and create cards for EVERY finding. Nothing dismissed. Nothing deferred without a card.

## Epic Structure

Create one epic per split operation:

```bash
bd create \
  --title="[EPIC] Spec split + test hardening — {filename}" \
  --type=epic --priority=1
```

## Card Grouping (group related findings into logical cards)

| Group | Card theme | Example |
|-------|-----------|---------|
| Foundation | Shared context fixes — naming, dead vars, create!, collisions | Must do first — everything depends on clean contexts |
| Regrouping | Move misplaced tests to correct domain files | Depends on Foundation (shared contexts must be clean first) |
| Parallel safety | Fix global state mutations, scoped queries, ensure-based restore | Independent — can parallel with Regrouping |
| CRITICAL test gaps | Untested methods, callbacks, failure paths | Depends on Regrouping (tests go in the right files) |
| WARNING test gaps | Edge cases, boundary conditions, nil guards | Depends on Regrouping |
| INFO test gaps | Nice-to-have coverage, documentation, boundary assertions | Depends on Regrouping |
| Cleanup | Redundant linter disables, dead declarations, stale comments | Independent — can parallel with anything |
| DRY extraction | Common shared context for multiple model specs | Depends on Foundation |
| Helpers | Reusable test helpers (shared examples, custom matchers) | Depends on Foundation |

## Dependency Wiring Order

```
Phase 1 — Foundation (do first, everything else depends on this):
  .1  Shared context fixes
  .2  Remove unused heavyweight contexts
  .3  Extract common DRY base contexts
  .4  Parallel safety infrastructure

Phase 2 — Structure (depends on Phase 1):
  .5  Regroup misplaced tests
  .6  Rename misnamed files
  .7  Cleanup dead code + stale references

Phase 3 — Coverage (depends on Phase 2 — tests go in correct files):
  .8  CRITICAL test gaps — untested methods, callbacks, failure paths
  .9  WARNING test gaps — edge cases, boundary conditions
  .10 INFO test gaps — documentation, nice-to-have assertions

Phase 4 — Helpers (can parallel with Phase 3):
  .11 Shared examples for recurring patterns
  .12 Custom matchers if patterns repeat 3+ times
```

## Card Template Checklist

Every card MUST follow the project-card skill's template. Additionally for spec cards:

- **Files section** must list the production source file being tested (read it first!)
- **First failing test** must name a specific test, not "tests pass"
- **Anti-patterns** must include:
  - `Do NOT write assertions that pass when code is broken`
  - `Do NOT add linter disables to work around warnings`
  - `Do NOT dismiss findings as pre-existing`
- **Verification** must run ONLY the files being changed, not the full suite

## Wiring Commands

```bash
# After creating all cards:
bd dep add <child> <blocker>     # Phase 2 blocked by Phase 1
bd dep add <test-gap> <regroup>  # Phase 3 blocked by Phase 2

# Verify structure:
bd children <epic-id>
bd blocked                        # Should show Phase 2-3 blocked until Phase 1 done
```

## Centralized Helpers to Consider

When carding, look for opportunities to extract reusable test infrastructure:

| Pattern seen 3+ times | Extract to |
|-----------------------|-----------|
| Same let_it_be setup across model specs | `spec/support/shared_contexts/{domain}_base.rb` |
| Same assertion pattern (e.g., "response has correct shape") | `spec/support/shared_examples/canonical_response.rb` |
| Same callback safety checks per enum | `spec/support/shared_examples/callback_safe.rb` |
| Same factory + membership setup | Factory traits (`create(:user, :with_project_membership)`) |
| Same DB constraint assertions | Custom matcher (`expect(record).to violate_check_constraint('name')`) |
| Same scoped query replacement for Record.last | Helper method in `spec/support/helpers/record_finder.rb` |

**DRY rule:** If you write the same 3+ lines in 2+ spec files during this epic, STOP and extract a helper/shared example/matcher FIRST, then use it everywhere.
