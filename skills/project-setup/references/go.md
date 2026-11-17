# Go setup

Read this after the verifier reports FAIL lines tagged `[go]` or `[go:path]`, or when setting up a repo whose detection marker is `go.mod` or `go.work`. Each section maps one checklist ID onto the Go toolchain and says why. Several IDs are satisfied by toolchain defaults; for those the job is to confirm the default has not been turned off, and the settings that turn it off are named.

## Units

The root `go.mod`, if any, is a unit, and every module listed in `go.work` is a unit. A repo with `go.work` and no root `go.mod` is a Go repo. Run `bash scripts/verify-setup.sh --list-units .` to see the modules the verifier found. The gate's `check` mode diffs every module's `go.sum`; its `add` mode takes `-C <module-dir>` in a workspace.

## G-01 Lifecycle scripts disabled by default

- **Satisfied by the toolchain.** Go modules have no install hooks. `go get` and `go mod download` fetch and verify archives and execute nothing. Dependency code runs only when you build or test, which the sandbox bounds.
- **What can still execute foreign code at build time:** cgo compiles C shipped in a module, and `go generate` runs whatever a `//go:generate` line says, but only when invoked explicitly and only for the current module, never for dependencies. `GOFLAGS=-mod=mod` lets a build silently add modules; keep the default `-mod=readonly`.
- **Verify:** `go env GOFLAGS` is empty or lacks `-mod=mod`. The verifier reports G-01 PASS with this reason.

## G-02 Lockfile committed and exact-pinned

- **Config:** every module's `go.sum` is tracked in git and not gitignored. Go versions are exact by construction; `go.mod` records the selected version and `go.sum` records the hash of its archive and of its `go.mod`.
- **Why:** the gate finds new modules by diffing `go.sum` against the base branch. A missing or ignored `go.sum` leaves nothing to diff, and a module listed in `go.work` without a `go.mod` is a broken workspace, which the verifier reports under G-02 with the module path.
- **Verify:** per unit, `go.sum` present and `git check-ignore go.sum` says nothing. `go mod verify` confirms the module cache matches `go.sum`.

## G-03 Minimum release age enforced

- **No native cooldown.** The Go toolchain has no release-age setting. The gate's AGE check enforces it from the module proxy's publish time, so G-03 is satisfied when the Go gate is installed and matches the template, and fails otherwise.
- **Verify:** `verify-setup.sh` G-03, which checks the gate.

## G-04 Dependency gate installed and wired to CI

- **Files:** `scripts/dep-gate.sh` (dispatcher, from `assets/common/`), `scripts/dep-gate-go.sh` (from `assets/go/`), `.dep-gate/exceptions`, `.github/workflows/dep-gate-go.yml` (from `assets/go/`).
- **Why:** `scripts/dep-gate.sh add github.com/x/y@v1.2.3` runs `go get`, which updates `go.mod` and `go.sum` and downloads archives without building, evaluates every module that is new in `go.sum`, and on PASS runs `go mod verify`. On FAIL it restores `go.mod` and `go.sum`. In CI, `check` evaluates whatever is new in any module's `go.sum` relative to the base branch.
- **What the gate checks per new module:** AGE (proxy publish time against the cooldown), SUMDB (checksum database verification is active and the module is not excluded from it), VULNS (OSV, ecosystem Go; versions keep their `v`), HIPCHECK (verdict Pass with no errored analyses, run with `-t repo` on the module's repository). Hipcheck has no Go target, so the repository URL is resolved from the module path for github.com and similar hosts, from the proxy's Origin field, or from the go-import meta tag for vanity paths such as golang.org/x.
- **Transitive modules:** `go.sum` carries a full hash only for modules whose packages are needed, and a `/go.mod` hash for the rest. The gate evaluates the former. A module that becomes needed later is evaluated when its hash appears.
- **Exceptions:** `.dep-gate/exceptions`, copied from `assets/common/dep-gate/exceptions`, lines of the form `module@version CHECK justification`, exact-version and per-check. The Go check names are AGE, SUMDB, VULNS, HIPCHECK, and PROXY. One file serves every gate in the repo.
- **Requirements:** bash 3.2+, git, curl, jq, go, hc. `HC_GITHUB_TOKEN` from the environment or `gh auth token`.

## G-05 Hipcheck policy

Repo-level. Read `references/hipcheck.md`. Note that the review and affiliation analyses query GitHub; for a module hosted elsewhere, such as go.googlesource.com, those analyses are skipped rather than errored, so a vanity-path module can come back with fewer errored entries than a GitHub one.

## G-06 Known-vulnerability scan in CI

- **Config:** the workflow runs `govulncheck ./...` in every module and `osv-scanner` over the `go.mod` files. govulncheck reports only vulnerabilities in code paths the module actually calls, which is the lower-noise signal; osv-scanner covers everything in the dependency set.
- **Why:** the gate's VULNS check covers new modules. The full scans cover modules already present when an advisory is published later.

## G-07 Agent install commands routed through the gate

Repo-level. Read `references/agent-hook.md`. For Go the hook denies `go get`, `go mod tidy|edit|vendor`, `go work sync`, and `go install` or `go run` with a `module@version` argument, and allows `go mod download|verify|graph|why` and `go build|test|run` of local packages.

## G-08 Artifact provenance verified

- **Satisfied by the toolchain when its defaults are kept.** Every module archive the toolchain downloads is checked against the checksum database at sum.golang.org, a transparency log, before use; `go.sum` then pins the hash. This is stronger than a registry signature: a changed archive fails the build everywhere.
- **What turns it off:** `GOSUMDB=off`, `GOINSECURE`, `GOFLAGS=-insecure` or `-mod=mod`, and exclusion patterns. `GONOSUMDB` excludes matching module paths from checksum verification; `GOPRIVATE` sets `GONOSUMDB` (and `GONOPROXY`) when they are unset, and `go env GONOSUMDB` then reports GOPRIVATE's value. The verifier tells the two apart and fails only on a pattern that reaches public modules: `*`, or a public host such as `github.com`, `golang.org`, `gopkg.in`, or `k8s.io` without a narrower path. A pattern scoped to a private host passes, and the verifier reports it.
- **What the gate does with it:** the gate's SUMDB check fails a module that any `GONOSUMDB` or `GOPRIVATE` pattern matches, because that module was not verified against the checksum database. For a genuinely private module that is the expected outcome; record it in `.dep-gate/exceptions` with the justification. A public module failing SUMDB means a pattern is too broad.
- **Verify:** `go env GOSUMDB GONOSUMDB GOPRIVATE GOINSECURE GOFLAGS`. The verifier reports G-08 from these values. The gate repeats the environment check per run, so a CI environment that disables verification is caught there too.

## G-09 Toolchain version pinned in the repo

- **Config:** in a workspace, the `go` or `toolchain` directive in `go.work` governs every module. Without a workspace, a `toolchain go1.X.Y` directive in `go.mod`. `GOTOOLCHAIN=auto`, the default, downloads and uses the named toolchain when the local one is older, verified through the same checksum database as modules.
- **Why:** the `go` line is a minimum language version; `toolchain` is the exact toolchain. In a workspace the `go.work` line governs selection for the whole workspace, which is why the verifier accepts it. No version manager is needed.
- **Verify:** `verify-setup.sh` G-09, or by hand: `grep -E '^(go|toolchain) ' go.work` or `grep '^toolchain ' go.mod`, and `go env GOTOOLCHAIN` prints `auto` (or a specific toolchain), never `local` with an older local Go than the repo names.

## G-10 Repo hygiene files

Repo-level. Go has no dependency directory to ignore; module archives live in the module cache outside the repo. If a module vendors (`vendor/`), that is a deliberate choice and is committed, not ignored.

## G-11 Agent instructions file

Repo-level. Paste `assets/common/agent-instructions.md` into `AGENTS.md` or `CLAUDE.md` at the repo root.

## Private module proxies

`GOPRIVATE` and `GONOSUMDB` exclude matching module paths from the public proxy and checksum database. Scope the pattern to the private host, never to a public one: the verifier's G-08 fails `*` and public hosts, and the gate's SUMDB check fails every module a pattern matches, which for a private module is recorded as an exception and for a public one is the signal that the pattern is too broad.
