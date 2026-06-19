# Suggest Next Card (after every close)

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
4. If the session focus is ambiguous (e.g., two epics equally active), offer
   the top TWO with a recommendation — never a long menu.

**Check:** Did the close end with a concrete next-card recommendation? If not,
go run `bd ready` and make one.

## Time Tracking

```
Estimated ~12 min, actual ~4 min
```

This calibrates future estimates. Track the timestamp when you mark `--status in_progress` (start) and when you run `bd close` (end). Over/under patterns reveal which card shapes are miscalibrated.

## Why Push on Close

In multi-developer workflows, Dolt server mode requires manual push/pull. Pushing after each card close ensures collaborators see your progress without drift. Auto-commit is OFF for server mode to prevent "database is read only" errors under concurrent load.

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
- [ ] Live visual verification for UI changes — Playwright MCP or manual browser, with screenshot evidence (Gate 9)
- [ ] Compiler check passes — zero errors in production code (Gate 10)
- [ ] All issues found during this card were fixed — nothing left behind (Gate 11)
- [ ] Design system variables used — no raw framework vars (Gate 12)
- [ ] Screenshot taken + READ for visual changes — both light and dark mode if applicable (Gate 13)
- [ ] Every agent/reviewer recommendation was independently verified before implementing (Gate 14)
- [ ] All model callbacks traced for save/update calls — no callback-fights-endpoint conflicts (Gate 17)
- [ ] All enum values tested for fields that trigger callbacks — not just happy path (Gate 17)
- [ ] Live test proof pasted in card notes — method matches layer changed (Gate 18)
- [ ] API response changes: all downstream layers done — serializer, route, spec, schema, contract test, validation, live test (Gate 19)
- [ ] Zero new linter disables — every warning fixed at root cause (Gate 20)
- [ ] Independent AC verification passed — project-ac-verify skill returned PASS, gate resolved (Gate 22)
- [ ] All tests pass (run your project's full test suite)
- [ ] Linters clean — run ALL that apply to changed files (zero warnings)
- [ ] `bd dolt commit` + `bd dolt push` after card close
