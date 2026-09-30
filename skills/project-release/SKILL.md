---
name: project-release
description: >-
  Final pre-release review and release preparation for an application or library
  repo. Run it after a batch of PRs has merged and the human operator wants to
  begin final review — well before anything is tagged. It confirms CI is green on
  the mainline, picks the version tier from the change surface, runs an
  adversarial security / DRY / code-review / cross-PR / docs-accuracy gate,
  reconciles the changelog and EVERY version reference (code AND docs), runs the
  build/test gate, and produces a release/vX.Y.Z branch carrying the version bump
  plus any last-minute fixes — stopping short of tagging. Use for "prep a
  release", "final review before release", "cut vX.Y.Z".
compatibility: >-
  Stack-agnostic. Detects the repo's version source(s), CI system, and docs
  system rather than assuming a language. Uses git and the gh CLI; uses beads
  (bd) for board reconciliation and the Workflow tool for the swarm review when
  they are available, and degrades to sequential agents / manual steps when they
  are not.
license: Apache-2.0
---

# Project Release

**Invoke this skill when a batch of merged work is ready for final review before a release.** It is the gate + prep step that runs *before* any tag exists. Its single deliverable is a **`release/vX.Y.Z` branch** — reviewed, version-bumped, changelog-current, docs-accurate — ready for the human to merge and tag. **This skill never tags and never publishes.**

## What it produces

A `release/vX.Y.Z` branch containing:
- the version bump across every version-bearing file (code **and** docs),
- a finalized `CHANGELOG.md` entry,
- any last-minute fixes the review gate surfaced,
- nothing else.

The human then reviews the branch, merges it to the mainline, and creates the tag / GitHub Release — which is what triggers the repo's release workflow (Docker image, package publish, mirror push, etc.). Keeping tagging out of this skill means a botched review never leaves a half-published release behind.

## Version-tier policy (semver)

Pick the tier from **what actually changed**, not from how much changed or how it feels:

- **Patch** (`x.y.Z`) — bug fixes, docs, dependency bumps, internal refactors, and even substantial feature work that does not change a public contract. A consumer-visible behavior change with no contract change is still a patch by default — but say so **loudly** in the changelog rather than escalating the tier.
- **Minor** (`x.Y.0`) — a backwards-compatible addition to a public contract: a new API endpoint or field, a new CLI command/flag, a new config option, a new published schema field. Additive, but consumers doing exhaustive matching can notice, so it is at least a minor.
- **Major** (`X.0.0`) — **only when the user explicitly says so.** Do not infer a major from breaking changes, removed features, or `!` in commit subjects. If you see a breaking change and the user has not said "major," surface it as a question (could this ship as a patch/minor with a prominent breaking-change call-out instead?) — don't unilaterally jump tiers.

Compute a *recommended* tier at Phase 0 from the diff, then let the user confirm.

## Lessons learned (the traps this skill exists to prevent)

Real failure modes from shipped releases — each maps to a phase below:

1. **The version never got bumped.** The release tag and image went out but the running app still reported the previous version in its UI/health/API because the version-source file was never edited. → Phase 2 sweeps the version source *and* proves consistency.
2. **The docs lagged the code.** The app shipped at the new version but the docs site still advertised the previous release as "latest," with install snippets pinning the old image tag. Version-string search over code alone misses this. → Phase 2 includes docs content; Phase 3 checks the docs "latest release" surface.
3. **The release workflow had stale secret/variable names.** The tag published, the workflow ran, and the mirror/registry push step failed on a renamed secret — discovered only after the tag existed. → Phase 5 preflights the release workflow's inputs *before* the branch is handed off.
4. **A migration was not safe for the production release phase.** CI built the DB from a schema dump, so a migration's forward path was never exercised and it aborted during the release-phase migrate on real data. → Phase 6 runs the repo's real gate; if the project has DB migrations, confirm CI exercises them from empty.
5. **Tags were created prematurely / by hand and had to be torn down.** A tag pointed at a commit whose workflow file still had the bug it was meant to fix. → This skill never tags; the human tags the merged commit.
6. **Cross-PR incoherence.** Two PRs that were fine individually left the mainline inconsistent (one re-introduced what another removed; a shared helper changed but not all callers). → Phase 1's cross-PR dimension.
7. **Docs drifted from the actual CLI/API surface** long before the release window, so a `BASE..HEAD`-scoped review never sees it. → Phase 1's docs-accuracy dimension inspects the *current* surface, not just the diff.

## Execution

Set two anchors up front and reuse them throughout:
- `BASE` — the last release tag: `git describe --tags --abbrev=0` (everything since here is "this release").
- `MAIN` — the integration branch (`main` / `master`).

### Phase 0 — Preconditions & scope

1. **CI is green on the mainline.** Do not review a red tree.
   ```bash
   gh run list --branch "$MAIN" --limit 5
   gh run view <latest-run-id>   # confirm the required checks all passed
   ```
   If the latest mainline run failed or is pending, stop and surface it — the release starts from a known-green mainline.
2. **Sync and read the current version.** `git fetch`, confirm local `MAIN` matches `origin/MAIN`. Read `OLD_VERSION` from the repo's **version source of truth** — detect it, don't assume (see "Finding every version reference" below). If two version-bearing files already disagree, that is a *pre-existing* incomplete release — surface it as a finding and fix it before bumping.
3. **Recommend a tier from the diff.** Enumerate the public-contract surface that changed since `BASE` (API spec files, CLI definitions, published schemas, config options). Non-empty additive change → minor; contract-only-unchanged → patch. Present the recommendation; **never recommend major** — that is the user's explicit call.
4. **Confirm `NEW_VERSION`** with the user, defaulting to the recommendation.
5. **Sweep parked breaking changes / deprecations** if the board tracks them (`bd list --label breaking-change` or equivalent). For each, ask whether *this* release removes it. Removed → changelog "Removed" in Phase 4; deferred → carries forward.

### Phase 1 — Pre-release review gate

Review everything merged since `BASE` **before** touching any version. This is a **gate**: confirmed critical/high findings block the release until fixed or explicitly waived by the user.

**Scope**
- Primary: `git diff BASE..HEAD` (`git diff --name-only BASE..HEAD` for the file list).
- DRY and docs-accuracy additionally inspect the **whole current surface**, not just the diff (a re-implementation of an existing helper, or a README documenting a removed flag, is a finding even if the original is untouched).
- Cross-PR: enumerate what merged since `BASE` (`git log BASE..HEAD --oneline`, PR refs in the subjects).

**The five dimensions**
1. **Security** — input validation at boundaries; authn/authz on new endpoints/actions; no secrets in code, config, or fixtures; injection / path traversal / SSRF; unsafe deserialization; dependency-audit deltas vs `BASE`. Run the repo's own security tooling if it has any (e.g. `brakeman`, `bundler-audit`, `npm/pnpm audit`, `gosec`, `govulncheck`) and diff against `BASE`.
2. **DRY / reuse** — for each new or changed unit, does an equivalent already exist in a shared module the new code should have imported? Inspect the shared surface, not just the diff. Each hit names the exact existing symbol.
3. **Correctness / code review** — the standard review: exhaustive branching, error handling, the "one enum value tested out of five" class, ORM lifecycle hooks that fight controller writes, race windows, N+1s introduced since `BASE`.
4. **Cross-PR consistency & regression** — for the PRs merged since `BASE`: did two touch the same area inconsistently? Is a shared-code change reflected in *all* consumers? Did one PR re-introduce something another removed, or silently regress a third? Do **not** flag the changelog as missing — its new-version section is authored later in Phase 4. The one changelog-adjacent thing worth noting is a *consumer-visible behavior change* Phase 4 must call out (report it low-severity so Phase 4 remembers).
5. **Docs accuracy (full-surface, not diff-scoped)** — every README / user-guide / API-reference page: do the documented commands, flags, endpoints, config keys, and example outputs still match the *current* code? Is any removed/renamed thing still shown? Because this drift predates the release window, inspect the current surface, not `BASE..HEAD`. Each mismatch names the page, the stale claim, and the correct current form.

**Orchestration.** When the Workflow tool is available, fan out one finder per dimension (shard by dimension × area for a large diff), then **adversarially verify** each finding with an independent skeptic prompted to *refute* it (drop unless it survives — this kills style nits and hallucinations), and synthesize a deduped report grouped by dimension and severity. Pass `BASE`, the changed-file list, and the PR list via `args`. Without the Workflow tool, run the dimensions as sequential review agents with the same refute step, or do it by hand for a small diff.

**Gate & output**
- Present confirmed findings (dimension × severity).
- **Block the bump on unresolved critical/high findings.** Fix them (last-minute fixes land on the release branch in Phase 7), then continue. Medium/low: the user decides — fix now, file a card, or waive with a one-line rationale recorded in the release notes.
- Deferred findings → file board cards, linked in the response. This phase produces no version edits.

### Phase 1.5 — Board / issue reconciliation *(if the repo uses an issue tracker)*

Two different clocks:
- **Board cards (beads/etc.) close when their fix is *merged*** — reconcile them now so the board reflects only work that still needs doing before the release. Walk every open/in-progress card, verify the deliverable is actually present in the code on this branch (grep/read the diff — never close on a title match), and close the delivered ones citing the delivering PR/commit. Leave genuinely-open work open; a symptom fix does not close a deeper follow-up card.
- **GitHub issues close when the release *ships*** — leave those for the human to close at publish time (Phase 8), so external watchers see "Resolved in vNEW." Prefer `Refs #N` over auto-closing `Closes #N` precisely so closing happens at release time, not merge time.

Then present a one-line-per-card view of what remains, grouped **release-blocking bug** vs **patchable / enhancement / future**. Only genuine correctness regressions in *this release's* surface should block.

### Phase 2 — Version reference sweep (code AND docs)

Bump `OLD_VERSION` → `NEW_VERSION` in **every** place it appears — this is the step that most often ships incomplete.

**Finding every version reference.** Detect the sources; do not assume a stack. Check for, at minimum:
- a dedicated version file (`VERSION`, `version.rb`, `__version__.py`, `version.go`);
- package manifests (`package.json`, `pyproject.toml`/`setup.cfg`, `Cargo.toml`, `*.gemspec`, `pom.xml`);
- an API description (`openapi.*` `info.version`, and any version examples in it — regenerate the bundle if the spec is multi-file);
- **documentation content**: install/quick-start snippets that pin an image tag or package version (`docker pull org/app:vOLD`, `pip install app==OLD`), a docs-site "latest release" line, release-notes indexes, version badges;
- the README.

Search command to catch stragglers (tune the exclude list to the repo):
```bash
git grep -nE "\bv?OLD_VERSION\b" -- . \
  ':(exclude)CHANGELOG.md' ':(exclude)*.lock' ':(exclude)node_modules'
```
For every hit decide: **current-version claim** (bump it) or **historical record** (leave it — changelog entries, migration manifests keyed by old version, "since vOLD" annotations are history).

**Prefer a single source of truth.** If the app derives its displayed version from one file (e.g. the UI/health/API all read a `VERSION` file), bumping that one file is what actually changes the running app; the manifests/spec/docs are for consistency. If the repo has a **version-consistency test** (a spec asserting `VERSION` == package manifest == the constant the app serves), it is the guard — run it after the sweep and treat a failure as "you missed one." If it has none, note that Phase-independent gap for a follow-up (a CI version-consistency check is cheap insurance against this exact recurrence).

Use a small script (Python/perl — **never `sed` for this**, it clobbers unrelated `x.y.z` substrings in fixtures) for the mechanical substitutions, then `git status` to confirm only intended files changed.

### Phase 3 — Docs-accuracy & "latest release" sweep

The release is the moment the docs advertise the new version:
- Update the docs-site **"latest release"** surface (landing page, release-notes index) to `NEW_VERSION`.
- Add a **release-notes page** for `NEW_VERSION` (mirror the changelog section — see Phase 4).
- Regenerate any **generated docs** (API reference JSON, bundled OpenAPI) so they carry the new version.
- Fold in the Phase 1 docs-accuracy findings (removed flags, renamed commands, stale example output).

If the docs are served **two ways** — a public site *and* a copy built into the app image — know which the human wants updated now. The public site typically deploys from a docs-path push and is independent of the release workflow, so it can be corrected without re-releasing; an in-app docs copy is baked into the image and only refreshes on the next image build. Say which one this pass updates and which lags.

### Phase 4 — Changelog

1. Open `CHANGELOG.md`. Insert `## [NEW_VERSION] - YYYY-MM-DD` at the top, promoting the existing `## [Unreleased]` block if the entries are already drafted there (leave a fresh empty `## [Unreleased]` above it).
2. **Actively derive breaking / behavior changes — never leave them implied by the version number.** Walk `BASE..HEAD` and enumerate, in plain English (what changed, why, how to migrate): removed/renamed API fields or CLI flags, tightened validation, changed defaults, changed output shape or semantics, and any consumer-visible behavior change (even one shipping in a patch — call it out prominently). If the walk finds none, write "No breaking changes" explicitly.
3. Fill the standard sections (skip empty ones, never silently skip Breaking Changes): **Added**, **Changed**, **Fixed**, **Security**, **Removed/Deprecated**.
4. **Do not touch earlier `## [vX]` entries** — they are factual history.

### Phase 5 — Release-infrastructure preflight

Before the branch is handed off, prove the release workflow will actually succeed when the human tags — the failure modes here are only visible *after* a tag otherwise:
- Read the release workflow (`.github/workflows/*release*`). Confirm every **secret / variable / repo-input it references actually exists** (`gh secret list`, `gh variable list`) and matches the current names — a renamed secret is the classic "tag published, publish step failed" trap.
- Confirm the workflow's **trigger** matches how the human will release (tag push vs. published GitHub Release) and that the workflow file **on the release branch** is the corrected one (a tag on an old commit runs that commit's workflow).
- If the app has **DB migrations**, confirm CI exercises `migrate` from an **empty** database (not just a schema-dump load) so a migration's forward path is proven before the release-phase migrate runs on real data.

### Phase 6 — Build / lint / test gate

Run the repo's full gate on the branch and fix anything red before proposing the commit:
- build, lint, unit + integration tests, security scan — whatever the repo's CI runs.
- the **version-consistency** check (Phase 2) specifically.
- any **docs build** (a dead-link or version check in the docs pipeline).

### Phase 7 — Create the release branch & propose the commit(s)

1. Create `release/vNEW_VERSION` from the up-to-date `MAIN`.
2. Land the version bump + changelog + docs updates + any Phase-1 last-minute fixes on it. Keep **distinct concerns as distinct commits** (e.g. a CI-config fix separate from the version bump) so review and revert stay clean.
3. `git add` every intended file explicitly (**never** `git add .` / `-A`), `git status --short` to confirm only intended files are staged.
4. Propose the commit(s) and **show the message(s); wait for explicit user approval before committing.** Suggested subjects: `chore(release): bump version to NEW`, plus separate subjects for any fix commits.
5. **Never tag, never push without being asked.** The deliverable is the branch + commits; the human decides when to push, open the PR, merge, and tag.

### Phase 8 — Handoff & post-publish reconciliation

State the remaining human steps explicitly:
1. Push the branch, open the PR, let CI go green, merge to `MAIN`.
2. Tag the merged commit and publish the release (this fires the release workflow).
3. **After publish:** deploy/verify the docs site if it deploys separately; reconcile **GitHub issues** fixed-and-now-shipped (prepare the "Resolved in vNEW" list for the human — do not close or comment as the user without explicit OK); backstop the board for any straggler card delivered but not closed in Phase 1.5.

Surface anything that lags rather than papering over it.

## Quick checklist (paste into the response after Phase 0)

- [ ] Phase 0: mainline CI green; `OLD_VERSION` read from the version source; version sources agree; tier recommended from the diff; `NEW_VERSION` confirmed; parked breaking-changes swept
- [ ] Phase 1: review gate run across all five dimensions (incl. full-surface DRY + docs-accuracy); findings adversarially verified; critical/high resolved or waived; deferrals filed as cards
- [ ] Phase 1.5: delivered board cards verified against the code and closed citing their PR; remaining-open triaged blocking-bug vs patchable; GitHub issues left for publish time
- [ ] Phase 2: EVERY version reference swept (version file, manifests, API spec + examples, docs install snippets, README) — current-version claims bumped, historical records left; version-consistency check green (or its absence noted for a follow-up)
- [ ] Phase 3: docs "latest release" + release-notes page at NEW; generated docs regenerated; which docs surface lags (in-app image) stated
- [ ] Phase 4: `CHANGELOG.md` has a new `## [NEW] - YYYY-MM-DD`; breaking/behavior changes actively derived and each explained (or "No breaking changes" stated); history untouched
- [ ] Phase 5: release workflow secrets/vars confirmed to exist under the current names; trigger + branch workflow verified; migrations exercised from empty in CI (if applicable)
- [ ] Phase 6: full build/lint/test/security gate green; docs build green
- [ ] Phase 7: `release/vNEW` branch created; concerns split into distinct commits; explicit `git add`; commit message(s) shown and approved before committing; **no tag**, **no unprompted push**
- [ ] Phase 8: handoff steps stated; post-publish docs deploy + GitHub-issue reconciliation prepared for the human
