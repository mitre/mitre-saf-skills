# Session handoff — mitre-saf-skills — 2026-08-12

Do not commit this file.

## Read first

`docs/plan-skill-reconciliation.md`. It states the goal correctly and explains why this session
got it backwards. Everything else here assumes it.

**The one-line version:** this repo is the GENERAL, public, stack-neutral skill collection.
`~/.claude/skills/*` is where improvements get developed, in project-specific vocabulary. Work
flows UP — local improvements are ported into this repo and **generalized in transit**. Never
copy a local file over a repo file.

## What happened

`97y.1` shipped and is good. `97y.2` was executed as `cp ~/.claude/skills/project-tdd/SKILL.md
skills/project-tdd/SKILL.md` — the card's own primary anti-pattern — which destroyed the
generalized multi-stack wording this repo carries for public release, along with the `license:`
and `compatibility:` frontmatter. It was reverted. The card is reopened.

The root cause was in the planning, not the execution: the epic describes three copies that
"have diverged" and never once uses the word *general*. With a symmetric model, "best-of-breed"
degenerates into "take the newer, fuller text", and local is always newer and fuller.

## Verified state

| Thing | State |
|---|---|
| `skills/project-tdd/` | reverted, byte-identical to pre-merge, committed `5f2c6fa` |
| `~/.claude/skills/project-tdd/SKILL.md` | restored to exact pre-session state — proven by the installed↔repo delta returning to the baseline 387 |
| `docs/skill-copy-baseline.md` | has a drift note that is now stale; installed went back to 387, so delete the note |
| `mitre-saf-skills-97y.1` | closed, committed `bd7aa3c` |
| `mitre-saf-skills-97y.2` | reopened, with the failure and corrected approach in its notes |
| `97y.3`–`97y.12` | open, but written with the wrong merge direction — see the plan |
| Push | nothing pushed |
| `.beads/config.yaml`, `interactions.jsonl` | still staged, untouched — the owner's, from before this session |

## Commits this session

```
f782d90 fix: record that project-tdd drifted after the baseline was measured   (note now stale, remove)
5f2c6fa revert: undo the project-tdd wholesale overwrite
340bbfa feat: reconcile the two generations of project-tdd                     (the bad merge, reverted)
bd7aa3c feat: add a three-way comparison harness for the skill copies          (good, keep)
```

## Branch

Renamed to `development` this session, at the owner's instruction, so the working branch is
unambiguous. Note for whoever picks this up: `development` currently carries the local history,
which shares **no common ancestor** with `origin/main` — the public repo was initialized
separately by Will Dower on 2026-06-25 and has three commits. Card `97y.11` describes cutting a
branch from `origin/main` so the unrelated-histories merge happens exactly once; that card's
premise now needs revisiting against the renamed branch.

## Other cards filed this session, still valid

- `mitre-saf-skills-7sg` — `validate-bd-create.sh` reads only the first `cat` path, so batching
  several `bd create` calls in one command validates the first card and lets the rest pass
  vacuously.
- `mitre-saf-skills-lj4` — every case in `test_compare_skill_copies.py` forces an unresolvable
  origin ref, so the five-column branch of `report()` has zero automated coverage.
- `x6r.1` was wired to depend on `97y.7`, since it edits a `project-goal` that is not yet
  versioned here.

## Standing constraints observed

Push only on the owner's word (nothing pushed). Never `git add -A`. `rm` and `git checkout --`
are blocked. Commits use `Authored by: Aaron Lippold<lippold@gmail.com>`, no AI attribution.
`derive-cci-mappings` is not shared and is not to be added to this repo.

## Update — 2026-08-21

`97y.12` "Push development to origin — the epic's only outward-facing action": ITS WORK IS
DONE and the card is ready to close, pending the owner's verification. `development` was
pushed to origin on 2026-08-21 with his explicit authorization, as a new remote branch with
tracking set. The card was deliberately NOT closed — closing a card is the owner's, and this
session did not work it.

Also landed and pushed on `development` this session:

- Six commits: beads bookkeeping, the unaudited-budget raise to 10 with its boundary test,
  the incident-log extraction to `references/`, the schema-migration reference (which fixed a
  dangling link in shipped guidance), the process-research docs, and this file.
- `hooks/ac-review-prompt.sh` had been diverged for NINE DAYS: the installed copy carried a
  brace fix from 08-12 that never reached this repo, which `.chezmoiignore` names as its
  owner. Synced, committed, pushed; both copies now identical; hook tests 11/11.
- `97y.13` filed — extend `compare-skill-copies.sh` to cover hooks, then symlink them. The
  existing guard covers skills ONLY, which is why the nine days passed unnoticed.

The "nothing pushed" note under Standing constraints describes 2026-08-12 and no longer holds.

## What to do next

1. Read `docs/plan-skill-reconciliation.md`.
2. Remove the now-stale drift note from `docs/skill-copy-baseline.md`.
3. Rewrite `97y.2`–`97y.5` with the repo copy as the merge base, add a frontmatter check, and
   replace the unsatisfiable "zero removals" acceptance criterion.
4. Then work `97y.2` — the improvements waiting to come up are listed in the plan, along with the
   three rulings already made that should be applied rather than re-litigated.
