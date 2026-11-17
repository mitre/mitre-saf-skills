# JavaScript and TypeScript setup

Read this after the verifier reports FAIL lines tagged `[javascript]`, or when setting up a repo whose detection marker is `package.json` or `pnpm-workspace.yaml`. Each section maps one checklist ID onto the toolchain and says why.

## Package manager

Use pnpm for new repos. It refuses to run dependency lifecycle scripts unless a package is listed in `onlyBuiltDependencies`, it has a native release-age cooldown, its lockfile has one entry per `name@version` which makes the gate's diff trivial, and it manages its own version from the `packageManager` field. npm is documented where it differs because existing repos have it. Yarn and Bun are not covered yet; the install hook denies their dependency-changing commands, and a reference for them is a follow-up.

Settings live in `pnpm-workspace.yaml` for pnpm 10 and later, not in `.npmrc`. pnpm 11 ignored `save-exact` in `.npmrc` during testing and honoured `saveExact` in `pnpm-workspace.yaml`. Copy `assets/javascript/pnpm-workspace.yaml` to the repo root and add the `packages:` list if the repo is a workspace. Copy `assets/javascript/.npmrc` too; it covers npm and older tooling.

## Units

The root `package.json` is a unit, and every package matched by `pnpm-workspace.yaml` is a unit. The root counts because pnpm installs and locks the root's own dependencies even though recursive commands skip it. Run `bash scripts/verify-setup.sh --list-units .` to see what the verifier found. The lockfile, the settings, the gate, and the hook are repo-level; a check tagged `[javascript]` is about the workspace, and one tagged `[javascript:path]` is about one package.

## G-01 Lifecycle scripts disabled by default

- **Config:** `packageManager` pins pnpm 10 or later in the root `package.json`, and the build allowlist in `pnpm-workspace.yaml` is bounded: `allowBuilds: {}` (newer map form) or `onlyBuiltDependencies: []` (older list form), with `dangerouslyAllowAllBuilds` absent. For npm, `ignore-scripts=true` in `.npmrc`.
- **Why:** pnpm 10 and later run no dependency lifecycle scripts unless the package is allowlisted, so the allowlist is the lever. Do not add `ignoreScripts: true` to harden further: it also silences this project's own `prepare` and similar scripts, such as a git-hooks installer, and adds nothing the allowlist does not already give. npm has no allowlist, so `ignore-scripts` is the only control there and carries that same cost.
- **Verify:** `verify-setup.sh` G-01 reports the pnpm version and every allowlisted package so they get reviewed. By hand: `grep packageManager package.json`; `pnpm config get allowBuilds` or `onlyBuiltDependencies`.
- **Adding to the allowlist:** only after reading the package's install script. Add the name under `allowBuilds` (`name: true`) or `onlyBuiltDependencies`, and say why in the commit. The gate's SCRIPTS check passes a package that declares install scripts only when it is listed; everything else that declares one fails the gate.

## G-02 Lockfile committed and exact-pinned

- **Config:** `pnpm-lock.yaml` tracked in git; `saveExact: true` in `pnpm-workspace.yaml` (`save-exact=true` in `.npmrc` for npm).
- **Why:** the gate finds new packages by diffing the lockfile against the base branch. No committed lockfile means nothing to diff. A range specifier lets a later resolve pull a version the gate never saw.
- **Verify:** `git ls-files --error-unmatch pnpm-lock.yaml` and the `saveExact` line.
- **Installing from the lockfile:** `pnpm install --frozen-lockfile`. It refuses to run when `package.json` and the lockfile disagree, which is what makes it safe to allow through the hook. A plain `pnpm install` would silently resolve a hand-edited manifest.

## G-03 Minimum release age enforced

- **Config:** `minimumReleaseAge: 4320` (minutes; three days) or more in `pnpm-workspace.yaml`. Needs pnpm 10.16 or later, so `packageManager` must pin at least that. `minimumReleaseAgeExclude` exempts named packages, typically the repo's own workspace packages; the verifier reports its members for review. A repo that already sets a longer cooldown passes as is.
- **Why:** most malicious publishes are taken down within hours of appearing. A cooldown skips the window where they are live without any analysis. Tested on pnpm 11.18: with a 30-day age, `pnpm add chalk` resolved to the version before a 13-day-old release.
- **Verify:** `pnpm config get minimumReleaseAge` from the repo root prints the value; it prints `undefined` on a pnpm too old to honour it. The verifier fails a value below 4320.
- **The gate checks age too** (AGE), against the registry's publish time, so npm repos and older pnpm get the same rule.

## G-04 Dependency gate installed and wired to CI

- **Files:** `scripts/dep-gate-javascript.sh` copied from `assets/javascript/dep-gate-javascript.sh`; `scripts/dep-gate.sh` copied from `assets/common/dep-gate.sh`, the dispatcher that routes `scripts/dep-gate.sh add <pkg>` to the right language gate so one command works in a polyglot repo; `.dep-gate/exceptions` copied from `assets/common/dep-gate/exceptions` (one file for every gate in the repo); a workflow that runs `scripts/dep-gate-javascript.sh check` (or `scripts/dep-gate.sh check`) on pull requests. `assets/javascript/dep-gate.yml` is a ready-made one, but a step in an existing workflow counts; the verifier looks through every file under `.github/workflows/` and names the one it found.
- **Why:** the gate is the resolve, evaluate, fetch sequence. Locally, `scripts/dep-gate.sh add <pkg>` (the dispatcher hands a bare npm name to the JavaScript gate) resolves with `pnpm add --lockfile-only`, which contacts the registry for metadata only and downloads no tarball, evaluates every package that is new in the lockfile, and only on PASS runs `pnpm install --frozen-lockfile`. In CI, `scripts/dep-gate.sh check origin/<base>` evaluates whatever is new relative to the base branch, so a dependency added by any route is caught before merge.
- **What the gate checks per new package:** AGE (publish time against the cooldown), SCRIPTS (install scripts unless in `allowBuilds`, `onlyBuiltDependencies`, or `.npmrc` `only-built-dependencies[]`), SIGNATURE (the registry's ECDSA signature over `name@version:integrity`, verified with openssl against the registry's published key), PROVENANCE (SLSA attestation present; INFO unless `DEP_GATE_REQUIRE_PROVENANCE=1`), VULNS (OSV batch query), HIPCHECK (verdict Pass with no errored analyses).
- **Exceptions:** a reviewed Investigate verdict is recorded as a line in `.dep-gate/exceptions`: `name@version CHECK justification`. The gate reports that check ACCEPTED with the justification. Exceptions are exact-version and per-check, live in the repo, and are reviewed in the PR that adds them. Loosening `.hipcheck/Hipcheck.kdl` instead is the wrong tool.
- **Requirements:** bash 3.2 or later, git, curl, jq, openssl, pnpm, hc. `HC_GITHUB_TOKEN` is read from the environment or from `gh auth token`. Read `references/hipcheck.md` for the token scopes and known failure causes.
- **Fail closed:** the gate aborts, restoring the manifest and lockfile, when the resolve step fails, when the lockfile changed but no new package could be identified, or when the lockfile's packages section contains entries its parser could not read, in both `add` and `check` mode. `DEP_GATE_LIST_ONLY=1` prints the packages that would be evaluated and stops, for debugging a CI diff without network access.
- **Verify:** `bash scripts/dep-gate.sh --help` prints usage; `verify-setup.sh` G-04 names the workflow that runs the gate.

## G-05 Hipcheck policy

Repo-level and language-independent. Read `references/hipcheck.md`. The gate passes `--policy .hipcheck/Hipcheck.kdl` and uses `-t npm`; when a package's repository URL is ssh-only it retries with `-t repo` and the https form.

## G-06 Known-vulnerability scan in CI

- **Config:** some workflow runs `osv-scanner` over the lockfile on every pull request, in addition to the gate's per-package VULNS check. `assets/javascript/dep-gate.yml` has the step; an existing CI workflow that already runs osv-scanner counts, and the verifier names the file it found.
- **Why:** the gate's query covers new packages. The full scan covers packages already present when an advisory is published later.
- **Note:** osv-scanner's detail fetch failed intermittently on one network during testing with an HTTP/2 stream error, exit code 129. The gate uses the OSV batch endpoint, which returns identifiers only and was reliable. In CI, a 129 is a tooling failure and fails the job, which is the fail-closed outcome.

## G-07 Agent install commands routed through the gate

Repo-level. Read `references/agent-hook.md`. For JavaScript the hook denies `pnpm add|install|update|...`, `npm install|i|...`, `npx`, `yarn add|install`, `bun add|install`, and allows `pnpm install --frozen-lockfile`, `npm ci`, `yarn install --immutable`, `bun install --frozen-lockfile`.

## G-08 Artifact provenance verified

- **What the gate does:** SIGNATURE verifies the registry signature cryptographically, which proves the tarball metadata the lockfile pins is what the registry published. PROVENANCE checks for a SLSA attestation, which additionally ties the artifact to a source commit and a build. Most packages carry a signature; few carry provenance yet, so provenance is INFO by default and becomes a FAIL with `DEP_GATE_REQUIRE_PROVENANCE=1`.
- **Why:** Hipcheck judges the repository. The signature and attestation judge the artifact. A malicious tarball published from a healthy repository is caught only by this check or by behavior analysis of the artifact, which this skill does not yet include.
- **Verify:** the gate's SIGNATURE and PROVENANCE lines. By hand: `npm audit signatures` does the same verification for an npm lockfile, but it needs a writable npm cache, which a sandbox may not grant; the gate's openssl path does not.

## G-09 Toolchain version pinned in the repo

- **Config:** Node pinned by `.nvmrc` or `.node-version`, or by `engines.node` in the root `package.json`. pnpm pinned by `packageManager` in the root `package.json`, for example `"packageManager": "pnpm@11.18.0"`. `engine-strict=true` in `.npmrc` makes npm refuse a wrong Node.
- **Which files count and why:** `.nvmrc` is read by nvm, fnm, and mise, so a version file does not tie the team to one version manager. Monorepos often pin through `engines.node` plus a CI setup action instead of a version file, and the verifier accepts that. The `packageManager` field is honoured by pnpm 10 and later directly, and by Corepack where it is still installed. Do not mandate a specific version manager; do install one from Homebrew or a verified release rather than a piped shell script, because the manager is itself a supply-chain item.
- **Verify:** `verify-setup.sh` G-09, or by hand: a version file or `engines.node`, and `grep packageManager package.json`.

## G-10 Repo hygiene files

Repo-level. For JavaScript the gitignore must also cover `node_modules/`. The verifier checks `.env`, `.hipcheck-cache/`, and `node_modules/`.

## G-11 Agent instructions file

Repo-level. Paste `assets/common/agent-instructions.md` into `AGENTS.md` or `CLAUDE.md` at the repo root.

## npm instead of pnpm

For an existing npm repo: `.npmrc` carries `ignore-scripts`, `save-exact`, and `engine-strict`; the lockfile is `package-lock.json`; the lockfile-faithful install is `npm ci`; `npm install --package-lock-only` is the resolve-only step. The shipped gate script targets pnpm; an npm variant of `dep-gate.sh` is a follow-up and is not yet provided. Until then, run `scripts/dep-gate.sh evaluate name@version` by hand before `npm install name@version`, and rely on the CI check.
