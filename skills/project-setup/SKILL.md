---
name: project-setup
description: >-
  Set up or harden a repository for its language with an ID-keyed checklist:
  lifecycle scripts off, exact-pinned lockfile, release-age cooldown, a
  resolve-then-evaluate-then-fetch dependency gate wired to CI, a Hipcheck
  policy, toolchain pinning, and repo hygiene. Detects the language, loads the
  matching reference, applies copied templates, and verifies every item with a
  script. Use when asked to "set up this repo", "harden this repo", "bootstrap
  a project", "new repo", "project setup", or before adding the first
  dependency to a fresh codebase. Works on new and existing repos alike.
compatibility: >-
  Requires bash, git, and grep for the verifier. Language references need the
  language toolchain (pnpm and Node for JavaScript, Go for Go). The dependency
  gate needs hc (MITRE Hipcheck) and osv-scanner on PATH, and network access to
  the package registry. CI templates target GitHub Actions.
license: Apache-2.0
---

# Project Setup

**Invoke this skill when creating a repo, before the first dependency is added to one, or when asked to harden an existing one.**

Repos set up ad hoc end up with whatever defaults the package manager ships. For most ecosystems those defaults download a tarball and execute its install scripts before anyone has looked at it. An agent that runs a plain install command is trusting every maintainer of every transitive dependency with the machine it runs on.

This skill turns setup into a checklist keyed by ID. Each ID has a requirement, a reason, a verify command, and a fix. A script checks every ID so the result can be audited without an agent, in CI, on any machine.

## Principles

**Resolve, then evaluate, then fetch.** Package managers conflate three steps: resolving which versions you would get, downloading the artifacts, and executing them. The dependency gate splits them apart. Resolution touches registry metadata only. Evaluation runs against the resolved list and the artifacts as bytes on disk. Fetch and install happen only after evaluation passes, with scripts disabled.

**Nothing executes by default.** Lifecycle scripts stay off for every install. Packages that genuinely need a build step go on an explicit, reviewed allowlist. This protects install time only. The package's code still runs when tests import it, so the sandbox the agent runs in bounds the damage that evaluation did not prevent. Both layers are needed.

**Templates are copied, not regenerated.** The gate script, the policy file, and the CI workflow live under `assets/` and are copied verbatim into the target repo. An agent that rewrites a security gate from memory produces a different gate each time, and none of them has been reviewed.

**Verification is a script, not a memory.** The skill ends by running `scripts/verify-setup.sh`. The same script runs in CI as a drift check and can be run by a human on any repo.

**New and existing repos take the same path.** A new repo is an existing repo where every check fails. There is no separate greenfield mode.

## Step 1: Detect Languages

Run this from the target repo's root. A repo can match more than one marker.

| Marker | Language | Reference to load |
|---|---|---|
| `package.json` | JavaScript / TypeScript | Read `references/javascript.md` |
| `go.mod` | Go | Read `references/go.md` |
| `pyproject.toml` or `requirements.txt` | Python | No reference yet. See "No reference for a detected language" below |
| `Gemfile` | Ruby | No reference yet. See "No reference for a detected language" below |
| `Cargo.toml` | Rust | No reference yet. See "No reference for a detected language" below |
| None found | Unknown or empty repo | Ask the user which language the repo will use |

```bash
for f in package.json go.mod pyproject.toml requirements.txt Gemfile Cargo.toml; do if [ -f "$f" ]; then echo "$f"; fi; done
```

Load only the references that match. Do not read the others. This step decides which references you read; the verifier in Step 2 does its own detection for its checks. If the two disagree, the verifier is authoritative and the disagreement is a bug to report.

**No reference for a detected language:** tell the user that no reference exists for it yet, and that only the language-independent items G-05, G-07, G-10, and G-11 can be fixed from this skill. Ask whether to proceed with those four or stop. Do not improvise fixes for the other IDs.

**If no marker is found**, ask the user:

**Which language will this repo use?**
- "JavaScript / TypeScript" → read `references/javascript.md`
- "Go" → read `references/go.md`
- "Something else" → apply the global checklist below and tell the user which language-specific items could not be verified

## Step 2: Run the Verifier

The script path is relative to this skill's directory. The argument is the target repo.

```bash
bash scripts/verify-setup.sh /path/to/repo
```

The script detects languages itself, runs one check per ID, and prints one line per ID:

```
G-01 FAIL  no .npmrc with ignore-scripts=true
G-02 PASS  pnpm-lock.yaml committed, save-exact set
G-03 SKIP  no javascript check for G-03 yet
```

Every ID is global, but the check for most IDs is implemented per language, because what satisfies the ID differs by toolchain. An ID prints SKIP when no check exists yet for a detected language. It exits 1 if any line is FAIL and 0 otherwise. SKIP never fails. Pass `--json` for a JSON array with the same content.

A missing tool is a FAIL with a reason, never a PASS. Do not install tools globally to make a check pass without telling the user.

## Step 3: Fix Each FAIL

Work through the FAIL lines in ID order. For each ID:

1. Read that ID's section in the loaded language reference. It gives the exact config lines and the file they go in.
2. If the fix is a template, copy it from `assets/<language>/` or `assets/common/`, then fill in only the placeholders the reference names. Change nothing else.
3. If the fix needs a decision only the repo owner can make, stop and ask. The two common cases are which packages are allowed to run build scripts, and whether to change a policy threshold.

Never hand-write a file that exists as a template. Never loosen a policy to make a check pass.

## Step 4: Re-run and Report

Run the verifier again. Report:

- Every ID that moved from FAIL to PASS, with the file that changed
- Every ID still FAIL and why, including any that need a human decision
- Every SKIP, so the user knows which items were not checked

Do not report success while any ID is FAIL.

## Global Checklist

These apply to every language. The language reference maps each ID onto the concrete toolchain. The verifier checks each ID by its number.

### G-01 Lifecycle scripts disabled by default

- **Requirement:** The package manager never runs install hooks unless the package is on an explicit allowlist.
- **Why:** Install scripts are the cheapest place to put a payload. Most packages have none, so disabling them costs almost nothing.
- **Verify:** `verify-setup.sh` G-01. The reference gives the manual check.
- **Fix:** Reference section G-01. Languages whose toolchain has no install hooks pass by default, and the reference says so.

### G-02 Lockfile committed and exact-pinned

- **Requirement:** The lockfile is in version control and new dependencies are recorded at exact versions.
- **Why:** The gate diffs lockfiles to find what is new. Without a committed lockfile there is nothing to diff, and range specifiers let a later resolve pull a version nobody evaluated.
- **Verify:** `verify-setup.sh` G-02.
- **Fix:** Reference section G-02.

### G-03 Minimum release age enforced

- **Requirement:** Resolution refuses versions published less than a configured number of days ago. Default is three days.
- **Why:** Most malicious publishes are taken down within hours. A cooldown skips the window where they are live without needing any analysis.
- **Verify:** `verify-setup.sh` G-03.
- **Fix:** Reference section G-03. Toolchains without a native cooldown implement it in the gate script.

### G-04 Dependency gate installed and wired to CI

- **Requirement:** `dep-gate.sh` from `assets/<language>/` is present and a GitHub Actions workflow runs it on every pull request that changes the lockfile.
- **Why:** The gate is what evaluates each new package before it is fetched. CI is what protects the main branch from dependencies added by any route, including a human bypassing the local workflow.
- **Verify:** `verify-setup.sh` G-04.
- **Fix:** Copy `assets/<language>/dep-gate.sh` and `assets/<language>/dep-gate.yml`. Reference section G-04 lists the placeholders.

### G-05 Hipcheck policy present and cache relocated into the repo

- **Requirement:** A `Hipcheck.kdl` policy file is at the repo root and the Hipcheck cache path points inside the repo.
- **Why:** Hipcheck scores the upstream source repository for activity, review practice, affiliation, binaries, and typosquatting. The policy file is what turns scores into a verdict. Keeping the cache inside the repo means a sandboxed agent needs no grant outside the repo and unrelated projects do not share state.
- **Verify:** `verify-setup.sh` G-05.
- **Fix:** Copy `assets/common/Hipcheck.kdl`. Read `references/hipcheck.md` for setup, cache relocation, and the token some analyses need.

### G-06 Known-vulnerability scan in CI

- **Requirement:** A scanner runs against the lockfile on every pull request and fails on a finding above the configured severity.
- **Why:** Hipcheck and the age check target unknown-bad packages. Known-bad ones need a vulnerability database. osv-scanner covers every ecosystem this skill supports.
- **Verify:** `verify-setup.sh` G-06.
- **Fix:** Reference section G-06. The gate workflow template includes this step.

### G-07 Agent install commands routed through the gate

- **Requirement:** The agent harness refuses a direct install command and points to the gate, unless the gate has just passed.
- **Why:** The CI gate catches dependencies after they are on a branch. By then the install already ran on the agent's machine. A command hook in the harness makes the gate the only path to an install.
- **Verify:** `verify-setup.sh` G-07.
- **Fix:** Copy the hook snippet from `assets/common/` into the harness's project settings. Read `references/hipcheck.md` for the merge procedure. Harnesses without command hooks get the rule in the agent instructions file instead, and the reference says this is weaker.

### G-08 Artifact provenance verified

- **Requirement:** The gate checks registry signatures or build attestations for each new package where the ecosystem supports them.
- **Why:** Hipcheck evaluates the source repository. A malicious tarball published from a healthy repository passes it. Provenance ties the artifact to the repository and the build that produced it.
- **Verify:** `verify-setup.sh` G-08.
- **Fix:** Reference section G-08. Toolchains that verify checksums by default pass, and the reference says how to confirm it has not been turned off.

### G-09 Toolchain version pinned in the repo

- **Requirement:** The language runtime and package manager versions are recorded in a file the toolchain reads.
- **Why:** An unpinned toolchain means two machines resolve and build differently, and an agent may install whatever version a script fetches. Pin the version in the repo. Do not mandate a specific version manager; most read the same files.
- **Verify:** `verify-setup.sh` G-09.
- **Fix:** Reference section G-09.

### G-10 Repo hygiene files present

- **Requirement:** `.gitignore`, a license file, and `.editorconfig` exist at the repo root. The gitignore covers the dependency directory, the Hipcheck cache, and local env files.
- **Why:** These are the files every later tool assumes. A missing gitignore is how a cache or an env file ends up committed.
- **Verify:** `verify-setup.sh` G-10.
- **Fix:** Copy `assets/common/.editorconfig`. The reference gives the gitignore entries. Ask the user which license to use if none is present.

### G-11 Agent instructions file present

- **Requirement:** The repo's agent instructions file at the root (`AGENTS.md`, or a harness-specific equivalent such as `CLAUDE.md`) tells agents to run the verifier and never to install around the gate.
- **Why:** The hook in G-07 enforces the rule. The instructions file explains it, so an agent understands why a plain install was refused instead of trying variations.
- **Verify:** `verify-setup.sh` G-11.
- **Fix:** Add the paragraph from `assets/common/agent-instructions.md` to the existing file, or create the file with it.

## Gotchas

- **Scripts off is not the same as safe.** G-01 stops install-time execution only. Dependency code still runs the moment a test imports it. The gate lowers the chance that a bad package lands. The sandbox bounds what it can do if one does. Do not describe a repo as protected because G-01 passes.
- **An "investigate" verdict fails the gate.** Hipcheck reports pass or investigate. The gate treats investigate as a failure and prints the reasons. Deciding what to do about it, choosing an alternative, or writing a justification is a separate activity and a separate skill. This skill installs the gate; it does not argue with it.
- **Hipcheck looks at the repository, not the artifact.** It cannot see that the published tarball differs from the tagged source. G-08 is the complement, not an optional extra.
- **Some toolchains satisfy IDs by default.** Go has no install hooks and verifies checksums against a transparency log out of the box. The check for those IDs is that the default has not been disabled, and the reference names the settings that disable it.
- **Do not generate what is in `assets/`.** If a template is missing a placeholder the repo needs, extend the template in this skill rather than writing a one-off in the target repo.
- **Do not add languages as nested skills.** A new language is a new `references/<language>.md`, an `assets/<language>/` directory, and check functions in the verifier. A `SKILL.md` inside a subdirectory is a separate skill to every agent that reads the spec, and it would not share this checklist.

## Extending This Skill

To add a language:

1. Write `references/<language>.md` with one section per G-xx ID, in order, stating the config, the reason, and the manual verify command. Say explicitly when the toolchain satisfies an ID by default.
2. Add `assets/<language>/dep-gate.sh` and `dep-gate.yml` following the resolve, evaluate, fetch structure. The JavaScript gate is the reference implementation.
3. Add check functions to `scripts/verify-setup.sh` and a fixture under `scripts/tests/fixtures/<language>-pass/`.
4. Add the marker row to the detection table in Step 1.

## Related Skills

- create-beads-board skill for setting up issue tracking in the same repo
- project-docs skill once the repo has documentation to write
- create-skill skill when extending this skill with a new language
