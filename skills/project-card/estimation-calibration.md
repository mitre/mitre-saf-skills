# Estimation Calibration Log

Track estimated vs actual time per card to calibrate future estimates.
Updated after each work session. Data feeds into the estimation table.

## Statistical Target

Need ~50 total timed cards (~15 per SP bucket) for estimates to predict
actual time within +/-30%. Current: 14 timed data points (halfway to n=30 overall).

Key finding at n=14: systematic 2.6x overestimate is clear signal, not noise.
Low within-bucket variance (sp:2 cards consistently 3-4m, not 2-15m) means
fewer samples needed to converge than high-variance distributions would require.

Re-evaluate calibration table after sessions 3, 4, and 5. If the ratio holds
at 2.5-3x across 50+ cards, permanently adjust the estimation table ranges.

## Current Calibration

### Summary by Story Points

| SP | Cards | Avg Est | Avg Actual | Avg Ratio | Recommended Est |
|----|-------|---------|------------|-----------|-----------------|
| 1  | 4     | 5m      | 2.8m       | 1.8x      | 3-5m (accurate) |
| 2  | 6     | 10.3m   | 3.7m       | 2.8x      | 4-6m            |
| 3  | 4     | 20m     | 7m         | 2.9x      | 8-12m           |
| 5  | 0     | —       | —          | —         | 20-30m (est)    |
| 8  | 0     | —       | —          | —         | 40-60m (est)    |

### Observations

- sp:1 estimates are close — leave as-is
- sp:2 overestimated ~3x — most are single-file changes with clear patterns
- sp:3 overestimated ~3x — except when genuinely new (e.g., a new component was 1.7x)
- Cards where the fix was "remove/change 1-3 lines" consistently finish in 2-4m regardless of sp
- Cards requiring new components take closer to estimated time
- RBAC/permission cards overestimated most — often the permission already exists and just needs a flag flip

### Patterns That Predict Fast Completion

- Fix is a one-line change in an obvious location
- Pattern already exists elsewhere in codebase (copy approach)
- Backend already supports the feature, frontend just needs wiring
- Test update is rename/assertion-tightening only

### Patterns That Predict Closer-to-Estimate Completion

- New component from scratch
- Keyboard navigation / accessibility work
- CSS positioning (popovers, panels, dropdowns)
- Changes that touch 4+ files across layers (model + controller + view + spec)

## Raw Data

### Session 1 — PR review feedback (11 cards from one epic + follow-ups)

| Card | SP | Est | Actual | Ratio | Category | Notes |
|------|-----|-----|--------|-------|----------|-------|
| Card-1 | 2 | 12m | 4m | 3.0x | bug fix | One-line gate logic fix |
| Card-2 | 2 | 10m | 3m | 3.3x | bug fix | 3x callback timing fix |
| Card-3 | 1 | 5m | 3m | 1.7x | bug fix | Type coercion normalization |
| Card-4 | 1 | 5m | 2m | 2.5x | bug fix | One-line parser swap |
| Card-5 | 2 | 10m | 4m | 2.5x | feature | Lock icon + badge + backend field |
| Card-6 | 2 | 10m | 4m | 2.5x | refactor | Move toggle, event chain |
| Card-7 | 3 | 20m | 7m | 2.9x | feature | Sidebar to inline + dropdown |
| Card-8 | 1 | 5m | 3m | 1.7x | rename | Text changes only |
| Card-9 | 3 | 20m | 5m | 4.0x | RBAC | Backend already supported the feature |
| Card-10 | 3 | 20m | 4m | 5.0x | feature | Timestamp comparison, zero new columns |
| Card-11 | 1 | 5m | 3m | 1.7x | seed data | 3 seed-or-find calls |
| Card-12 | 2 | 10m | 4m | 2.5x | Vue fix | Collection type + keyboard + validator |
| Card-13 | 2 | 10m | 4m | 2.5x | test quality | Assertions + CSS var + spec desc |
| Card-14 | 3 | 20m | 12m | 1.7x | new component | Popover panel + keyboard nav + CSS |

**Session totals: 14 cards, 28 sp, 162m estimated, 62m actual, 2.6x avg ratio**

### Session 2 — Seed modernization + DRY + domain features

| Card | SP | Est | Actual | Ratio | Category | Notes |
|------|-----|-----|--------|-------|----------|-------|
| Card-A | 2 | 12m | — | — | bug fix | Pre-calibration (no timing) |
| Card-B | 2 | 12m | — | — | bug fix | Pre-calibration |
| Card-C | 2 | 12m | — | — | bug fix | Pre-calibration |
| Card-D | 2 | 12m | — | — | bug fix | Pre-calibration |
| Card-E | 2 | 12m | — | — | bug fix | Pre-calibration |
| Card-F | 2 | 12m | ~15m | 0.8x | DRY extract | 3 extractions + 2 bonus components |
| Card-G | 1 | 5m | ~3m | 1.7x | redirect | Response format + test |
| Card-H | 5 | 35m | ~15m | 2.3x | new component | Domain list + toggle + localStorage |
| Card-I | 2 | 12m | ~5m | 2.4x | feature | Badge on existing button, data already there |

**Note:** Card-F was the only card that took LONGER than estimated — scope expanded to cover 2 extra components discovered during Gate 5 DRY check.
