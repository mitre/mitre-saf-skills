# Skill copy baseline — 2026-08-12

The skill collection exists in three places. This file records what they looked like at the
start of epic `mitre-saf-skills-97y`, so that later drift is attributable to a decision
rather than discovered as a surprise.

Regenerate the live matrix at any time:

```sh
bash scripts/compare-skill-copies.sh
```

## The three copies

- **installed** — `${CLAUDE_SKILLS_DIR:-$HOME/.claude/skills}`. What an agent actually
  loads. Editing here changes behavior immediately and is invisible to git.
- **repo** — `skills/` in this repository. What is under version control.
- **origin** — `${SKILL_ORIGIN_REF:-origin/main}`. What the public repository publishes.

## Measured baseline

`INST<->REPO` is the count of `diff` output lines between the installed and repo copies of
`SKILL.md`; `0` means byte-identical, `-` means the file is absent from one side.

| Skill | installed | repo | origin | INST<->REPO |
|---|---|---|---|---|
| beads-task-management | yes | - | - | - |
| context7-mcp | yes | - | - | - |
| create-beads-board | yes | yes | yes | 0 |
| create-beads-orchestration | yes | - | - | - |
| create-feature-plan-adr | yes | yes | yes | 0 |
| create-skill | yes | yes | yes | 0 |
| dark-mode-verify | yes | - | - | - |
| derive-cci-mappings | yes | - | - | - |
| find-docs | yes | - | - | - |
| find-skills | yes | - | - | - |
| nuxt-ui | yes | - | - | - |
| package-audit | yes | yes | yes | 8 |
| prepare-compact | - | yes | yes | - |
| profile-development-rubric | yes | yes | yes | 34 |
| project-ac-verify | yes | yes | yes | 94 |
| project-card | yes | yes | yes | 357 |
| project-docs | yes | yes | yes | 14 |
| project-goal | yes | - | - | - |
| project-tdd | yes | yes | yes | 387 |
| research-driven-writing | yes | yes | - | 0 |
| restore-context | - | yes | yes | - |
| spec-split-review | yes | yes | yes | 40 |
| visual-consistency-audit | yes | - | - | - |

## What the rows mean

**Seven skills genuinely diverge** between installed and repo: `project-tdd` (387),
`project-card` (357), `project-ac-verify` (94), `spec-split-review` (40),
`profile-development-rubric` (34), `project-docs` (14), `package-audit` (8). Four more are
duplicated but byte-identical, so they need no merge.

**`prepare-compact` and `restore-context` show `-` for installed** because locally they are
commands (`~/.claude/commands/*.md`), not skills — a different shape, not a missing file.
They diverge from their repo counterparts by 750 and 417 diff lines respectively.

**`find-docs` and `project-goal`** are installed-only and were judged team-shareable.
`project-goal` in particular was unversioned while an epic existed to modify it.

**`research-driven-writing`** is in the repo but not upstream, and was missing from
`skills.sh.json`.

**Installed-only rows that are not candidates for this repo:**

- `context7-mcp`, `create-beads-orchestration`, `dark-mode-verify` and
  `visual-consistency-audit` — personal tooling, versioned separately.
- `find-skills` and `nuxt-ui` — third-party skills recorded in
  `~/.agents/.skill-lock.json` (sourced from `vercel-labs/skills` and `nuxt/ui`). The
  lockfile is what reproduces them, so it is the thing worth keeping, not the directories.
- `beads-task-management` — the beads project's own bundled skill (Steve Yegge, MIT,
  v0.34.0). It ships with the beads tooling and is **not** in the skills.sh lockfile, so it
  is reproduced by reinstalling beads rather than by either mechanism above.
- `derive-cci-mappings` — a separate project that this repository does not ship.

## Divergence against upstream

Measured the same day, as `added+/removed-` against `origin/main`. Removals are where
upstream content is at risk during a merge.

- `skills/create-beads-board/SKILL.md` — 98+/37-
- `skills/restore-context/SKILL.md` — 23+/1-
- `skills/prepare-compact/SKILL.md` — 17+/7-
- `.claude/settings.json` — 13+/1-
- `skills/project-card/SKILL.md` — 12+/7-
- `skills/create-feature-plan-adr/SKILL.md` — 2+/4-
- `skills/project-tdd/SKILL.md` — 93+/0- (pure addition; nothing at risk)

Every other shared file was identical, and no file present on `origin/main` was absent
locally — so the only risk was in-file, never a deletion.
