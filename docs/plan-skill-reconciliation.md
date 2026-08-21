# Plan — bringing local skill improvements upstream, without losing generality

Written 2026-08-12 after a failed attempt. Read the first section before anything else; the
attempt failed because this was never stated, and everything downstream inherited the error.

## The goal, stated correctly

**This repository is the GENERAL, public, stack-neutral version of the skill collection. It is
the product.** Its generality is the thing being protected.

`~/.claude/skills/*` are the working copies where improvements actually get developed. They are
written in the vocabulary of whatever project was in hand at the time — `yarn test:unit`,
`bundle exec rspec`, `raw Bootstrap vars`, `Blueprint`, `OpenAPI`, HAML.

**The job is to port improvements UP — from local into this repo — and to GENERALIZE them in
transit.** The direction is one-way and the transformation is mandatory:

```
~/.claude/skills/<skill>     -->  generalize  -->  skills/<skill>   -->  origin/main
(specific, where you develop)                      (general, public)     (released)
```

Never the reverse. A local phrasing must never travel upward unchanged if it names a specific
tool, framework, language, or project.

### The translation, concretely

| Local (specific) | Upstream (general) |
|---|---|
| `yarn test:unit` / `bundle exec rspec` | run your project's full test suite |
| `no raw Bootstrap vars` | no raw framework vars — use project design tokens |
| Blueprint / OpenAPI YAML | serializer/presenter; API schema (OpenAPI, protobuf, GraphQL) |
| `rails runner` | run with real data (`rails runner`, `python manage.py shell`, `go run`) |
| `yarn build` | build the assets (`yarn build`, `npm run build`, `vite build`) |
| HAML | server-rendered templates (HAML, ERB, Jinja, Blade) |
| Playwright | browser automation (Playwright MCP preferred); state plainly when unavailable |

The upstream file already contains the right-hand column. That is not drift to be reconciled —
it is finished work. Preserve it.

## Why the first attempt failed — do not repeat this

The epic (`mitre-saf-skills-97y`) was written describing the situation as three copies that
"have diverged", with "divergence" measured in diff-line counts. The word *general* appears
nowhere in it. That framing was the whole error:

1. **It modelled the problem as symmetric drift between equals.** With no direction in the model,
   "best-of-breed" degenerates into "take the newer, fuller text" — and local is always newer and
   fuller, because local is where development happens.
2. **It grouped installed and repo together as "our content"** to be settled internally before
   dealing with upstream. That phrase erases the only distinction that matters.
3. **The comparison harness reports magnitude, not kind.** `387` is a count. It cannot express
   "one of these is the generalized artifact", so running it reinforced the symmetric model.
4. **Nobody asked why the copies differ.** `run your project's full test suite` vs `yarn test:unit`
   was logged as drift. It was deliberate generalization work. One question would have inverted the
   model before a single card was written.

The execution then did `cp ~/.claude/skills/project-tdd/SKILL.md skills/project-tdd/SKILL.md`,
which is the card's own primary anti-pattern, and destroyed the generalized wording plus the
`license:` and `compatibility:` frontmatter. Reverted in `5f2c6fa`.

## The method, per skill

For each skill, working one at a time:

1. **Base = the repo copy.** Open it and leave it open. Nothing is replaced wholesale, ever.
2. **List what the local copy has that the repo lacks** — by section heading, then by paragraph.
   `bash scripts/compare-skill-copies.sh` gives the magnitude; the section-level `comm` of
   `grep -E '^#{2,3} '` on both files gives the inventory.
3. **For each candidate addition, ask two questions in order:**
   - *Is it a genuine improvement?* (new gate, new rule, a real correction) — if not, stop.
   - *Does its wording name a specific tool, framework, language, or project?* — if yes, rewrite
     it in the general form before it goes in. Use the translation table above.
4. **Never remove a line the repo has** unless it is genuinely superseded, and then say so
   explicitly in the card notes with what replaced it.
5. **Check the frontmatter separately.** Section and gate audits do not see it. `license:` and
   `compatibility:` live there and were lost last time precisely because every check looked at
   headings.
6. **Verify by diffing against `origin/main`, reading the removed lines** — all of them, not a
   sample, not a category summary. Anything removed must be explainable one line at a time.
7. Install the merged result to `~/.claude/skills/<skill>/` only after the repo copy is right.

## Known improvements waiting to come up (project-tdd)

Present locally, absent upstream, judged genuine — each needs generalizing on the way in:

- `## Mode Selection — full (default) vs lite` — the lite/full contract, hard guardrail, and the
  mechanical-card carve-out. Contains project names in the guardrail list; generalize to
  "production application repositories".
- `### Target check — FIRST, before every card, before any edit` — worktree/branch confirmation.
  Written against a specific multi-worktree layout; generalize.
- `### Card-Boundary Re-Anchoring — unconditional, silent, every card` — supersedes the repo's
  `### Context Rot Mitigation`, which currently instructs the agent to announce a context
  percentage. Aaron's ruling 2026-08-12: the agent gets no self-assessed numeric trigger.
- Gate 9 — the repo's version is stack-neutral and mandatory; the local version is
  Playwright-specific but adds an honest "state plainly when unavailable" path.
  **Best-of-breed here means the repo's framing plus the local honesty clause, not either file.**
- `bd dolt commit` / `bd dolt push` after card close, and the note that a card closed but not
  pushed is invisible to collaborators.
- A pointer from `SKILL.md` to `references/close-protocol.md` explaining it holds the
  stack-neutral form — otherwise that file is orphaned and its ten unique lines are invisible.

### Rulings already made by Aaron on 2026-08-12 — apply, do not re-litigate

1. `### When to Start a Fresh Session` does not go into `SKILL.md`. It gave the agent a
   self-judged threshold ("context above 60% AND quality has visibly degraded"), which asks the
   agent to measure the one thing it cannot observe from inside.
2. The research behind it stays in `references/llm-failure-modes.md`, reframed from prescription
   to description, with the procedure labelled as the operator's.
3. The context rule is narrowed rather than left flat: a factual operational callout at a card
   boundary is allowed; context offered as a reason for degraded work is not.

## Corrections the existing cards need before they are worked

- `97y.2` through `97y.5` are written with the local copy as the merge base. **Invert them.**
- Their acceptance criterion "shows additions only, zero removals against `origin/main`" is
  unsatisfiable as written wherever the local copy is a rewrite rather than a pure addition
  (measured: all five). Replace with: *no upstream content is lost; every removal is traced,
  one line at a time, to a rewrite or a named supersession, and anything untraceable is restored.*
- Add a frontmatter check to every merge card.
- `package-audit` and `project-docs`: the local copies would delete their ask-the-user fallback
  paths ("Which domains should this audit cover?", "Which documentation system does this project
  use?"). Those must survive.
- Four skills — `project-card`, `project-docs`, `profile-development-rubric`, `spec-split-review`
  — have `license:` upstream and in the repo but not locally. Merging local-over-repo drops it.
- `create-beads-board` is already missing `license:` in the repo, from before this work.

## State at handoff

- `97y.1` complete and committed (`bd7aa3c`): `scripts/compare-skill-copies.sh`, a seven-case
  suite, and `docs/skill-copy-baseline.md`. The harness works and is mutation-confirmed.
- `97y.2` reopened. Its merge was reverted; the repo copy is byte-identical to pre-merge.
- `~/.claude/skills/project-tdd/SKILL.md` restored to its exact pre-session state, proven by the
  installed↔repo delta returning to the baseline 387.
- `docs/skill-copy-baseline.md` carries a drift note that is now itself stale — the installed copy
  went back to 387, so that note should simply be removed.
- Two extra files sit in `~/.claude/skills/project-tdd/references/` (`close-protocol.md`,
  `llm-failure-modes.md`) that were not there before. Harmless; they are needed after a correct
  merge anyway.
- Nothing pushed. `.beads/config.yaml` and the `interactions.jsonl` deletion remain staged and
  untouched — they are the owner's, from before this work.
