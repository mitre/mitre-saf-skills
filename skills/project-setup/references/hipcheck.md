# Hipcheck setup for the dependency gate

Read this when fixing G-05, when the gate reports a Hipcheck error, or when tuning the policy.

## What Hipcheck judges, and what it cannot

Hipcheck (`hc`) clones a package's source repository and scores the project: recent activity, review practice, self-merged commits, committed binaries, high-entropy or oversized commits, committer affiliation, and typosquat-like names. It evaluates the repository, not the published artifact. A malicious tarball published from a healthy repository passes Hipcheck. That is why G-08 provenance verification exists alongside it.

## Layout in a repo

```
.hipcheck/            copied verbatim from this skill's assets/common/hipcheck/
  Hipcheck.kdl        the policy; thresholds and why they are set live here
  Exec.kdl            plugin process settings
  Orgs.kdl            organizations for the affiliation analysis
  Binary.kdl          binary file signatures for the binary analysis
  Typos.kdl           popular package names per ecosystem for the typo analysis
  Langs.kdl           language definitions the linguist plugin uses
.hipcheck-cache/      plugins and cloned repositories; gitignored
.env                  HC_CONFIG, HC_CACHE, HC_VERBOSITY, HC_COLOR; gitignored
```

The policy references its data files with `#rel("...")`, relative to the policy file, so the files must stay together in one directory. That directory is `.hipcheck/` and HC_CONFIG names it.

`.env` content:

```
HC_CONFIG=.hipcheck
HC_CACHE=.hipcheck-cache
HC_VERBOSITY=quiet
HC_COLOR=never
```

Gitignore entries: `.hipcheck-cache/` and `.env`. The verifier's G-10 checks both.

## Why the config and cache are relocated into the repo

Without these variables, `hc setup` writes its config into the user's config directory and `hc` keeps plugins and clones in the user's cache directory. Two problems follow. A sandboxed agent needs a grant outside the repo to run Hipcheck at all. And every project on the machine shares one config and one cache, so a policy edit for one repo changes the verdicts in another. Relocating both into the repo removes both problems and needs no global grant. The same reasoning applies to any tool that keeps state outside the repo.

## Installing hc and its plugins

Install `hc` from the Hipcheck releases (the gate was built against 3.15). Do not run `hc setup`: it writes to the user's config directory and the policy it produces is replaced by the one in `.hipcheck/`. Plugins download on first use into HC_CACHE; the first run of `hc ready` or `hc check` therefore takes longer and needs network access. After that, each `hc` invocation spends about 10 seconds starting plugins before any analysis begins.

Check readiness from the repo root with the env loaded:

```bash
set -a; . ./.env; set +a
export HC_GITHUB_TOKEN=$(gh auth token)
hc ready --policy .hipcheck/Hipcheck.kdl
```

`hc ready` reports "Policy file not found" unless the policy path is passed explicitly, even with HC_CONFIG set. The gate always passes `--policy .hipcheck/Hipcheck.kdl`.

## GitHub token

The review and affiliation analyses query GitHub and need `HC_GITHUB_TOKEN`. A classic token needs `public_repo` (or `repo` for private upstreams) plus `read:user` and `user:email`. Without the email scopes the affiliation analysis errors with a message about the `email` field and the token's scopes. With the GitHub CLI:

```bash
gh auth refresh -s read:user,user:email
export HC_GITHUB_TOKEN=$(gh auth token)
```

In GitHub Actions, `secrets.GITHUB_TOKEN` is an installation token without user scopes, so affiliation errors there. Either store a personal token with the scopes above as a repository secret and pass it as `HC_GITHUB_TOKEN`, or accept that affiliation will error in CI and that the gate treats an errored analysis as a failure.

## Running a check

```bash
hc check --policy .hipcheck/Hipcheck.kdl -t npm  --format json <name>[@<version>]
hc check --policy .hipcheck/Hipcheck.kdl -t pypi --format json <name>[@<version>]
hc check --policy .hipcheck/Hipcheck.kdl -t repo --format json https://github.com/<owner>/<repo>
```

Target types are maven, npm, pypi, repo, request, and sbom. There is no Go target; the Go gate resolves each module path to its repository URL and uses `-t repo`.

Set `HC_VERBOSITY=quiet` (the `.env` above does). Without it, progress lines are written to stdout and the JSON is not parseable.

## Reading the result

The JSON has `recommendation.kind` of `Pass` or `Investigate`, with `recommendation.risk_score` and the policy that produced it, plus three lists: `passing`, `failing`, and `errored`. Each entry names the analysis and its policy expression. The gate's rule:

- `Pass` with an empty `errored` list is a pass.
- `Investigate` is a failure, and the `failing` entries are the reasons to report.
- Any entry in `errored` is also a failure. An analysis that could not run did not clear the package; it was skipped. The gate prints the error so the operator can fix the cause (usually token scope or a missing upstream lockfile) or decide to accept it with a written justification.

Deciding what to do about an Investigate is not this skill's job. This skill installs the gate; the investigation skill argues with it.

## Known failure causes

- **SSH repository URLs.** Some packages publish an `ssh://` or `git@github.com:` repository URL. Hipcheck clones it over SSH, which fails where no SSH keys or known hosts exist, such as a sandboxed agent or CI: "invalid or unknown remote ssh hostkey". The gate retries with `-t repo` and the HTTPS form of the URL.
- **Typo analysis errors.** The typo analysis reads the upstream repository's lockfile. Many libraries do not commit one, and the analysis then errors rather than passing. This is the most common `errored` entry and is not the package's fault; record it as such in the justification if the rest passes.
- **Review and affiliation errors.** Almost always the token: missing, expired, or lacking the user scopes above.
- **"Reached max spawn attempts for plugin ..."** The plugin binaries did not start within Hipcheck's patience, which happens on a cold file cache, under a sandbox, or on a busy CI runner, and usually clears on the next run. The shipped `Exec.kdl` raises the backoff and attempt counts for this reason; the gate also retries once. If it persists, run `hc ready` and check the plugin binaries under HC_CACHE are executable.
- **Timing.** About 10 seconds of plugin startup per invocation, then clone time. Small libraries finish in 12 to 20 seconds. Large monorepos with long histories take minutes, and the entropy and churn analyses walk the whole history. The clone is cached under HC_CACHE for later runs.

- **The empty token `#rel()` inside a comment breaks parsing.** Hipcheck 3.15 reports "Failed to parse KDL document" for a policy whose comment contains `#rel()` with empty parentheses, even though it is a line comment; the same token with an argument parses. Avoid the empty form in prose. The same error message appears when a data file the policy references is missing, so check both.

## Tuning the policy

Edit `.hipcheck/Hipcheck.kdl` in the repo. Every threshold has a comment saying what it protects against. Change a threshold only for a reason that applies to every dependency of the repo, and say why in the commit message. Loosening a threshold so that one package passes is the wrong tool; that case is an Investigate verdict with a written justification. To add an organization to the affiliation analysis, edit `Orgs.kdl`. To treat fuzzing as required, add the `mitre/fuzz` plugin and an analysis for it; it is omitted by default because small libraries almost never participate in OSS-Fuzz.
