---
name: create-beads-board
description: >-
  Set up a beads issue-tracking board in any repo. Takes a deterministic mode
  argument (compose tokens: local | shared | external | remote), e.g.
  "shared external" connects to an already-running team Dolt server without
  managing it, "shared external remote" also configures Dolt push/pull, and
  "remote" alone is the upgrade path — adds the Dolt sync remote to an existing
  board after you create the GitHub repo. The arg IS the mode — run it, do not
  re-derive or ask. Use when initializing beads in
  a new repo, connecting to a shared Dolt server, troubleshooting bd init, or
  migrating from embedded to shared mode. Triggers on "set up beads", "create a
  board", "init beads", "connect to the beads server", "new beads board", or
  "set up issue tracking".
argument-hint: "[local | shared | shared external | shared external remote | remote]"
compatibility: Requires beads CLI (bd). Shared/remote modes require a running dolt sql-server.
license: Apache-2.0
metadata:
  author: mitre-saf
---

# Create Beads Board

Initialize a beads issue-tracking board. The **mode argument** this skill is invoked with selects the mode deterministically. Do not re-derive it from prose.

## Mode Argument — deterministic, no guessing

The words passed to this skill (e.g. `shared external`) ARE the mode. They compose as tokens:

| Token | Effect |
|-------|--------|
| _(none)_ or `local` | Embedded Dolt, no server (default) |
| `shared` | Connect to the shared Dolt SQL server (default `127.0.0.1:3308`, user `root`, empty password) |
| `external` | The shared server is **externally managed / already running** — pass `--external` so bd does NOT try to start or stop it. Combine with `shared`. |
| `remote` | Register the Dolt sync remote and push. **Composes** with an init mode (`shared external remote` = init + remote in one go), or runs **standalone** on a board that already exists (`remote` alone = just add/update the remote — no re-init). |

Common combinations:
- `local` (or no arg) → embedded board
- `shared` → bd-managed shared server
- **`shared external` → connect to the team's already-running server on 3308 — the standard MITRE setup**
- `shared external remote` → the above, plus set up the Dolt remote and push
- **`remote` (alone) → board already exists; you've since created the GitHub repo — just wire up the remote and push. This is the upgrade path.**

### Execution contract — READ THIS FIRST

**A mode arg IS the user's explicit authorization.** When one is present, do exactly this and nothing more:

1. Run the single init command for that mode (see [Commands by mode](#commands-by-mode)). Prefix defaults to the current directory name unless the arg supplies `prefix=<name>`.
2. Verify read-only: `bd status`.
3. If `remote` was requested, add the remote and push.

When a mode arg is given, do **NOT**:
- re-derive the mode from surrounding prose,
- read the reference files before acting,
- run exploratory probes (`SHOW DATABASES`, `git remote -v`, `ls .beads/`, `bd init --help`) before running the command,
- ask clarifying questions, or
- pause for confirmation — **the arg is the confirmation.**

Read a reference file or troubleshoot ONLY if a command actually errors. If no arg was given and intent is genuinely unknown, default to `local` — do not ask.

## Commands by mode

Standard shared server constants: host `127.0.0.1`, port `3308`, user `root`, empty password (`export BEADS_DOLT_PASSWORD=""`). `<dir>` = current directory name (hyphens become underscores in the DB name).

**`local`** (or no arg):
```bash
bd init --non-interactive --role maintainer --prefix <dir>
```

**`shared`** (bd contacts the server as a plain client):
```bash
BEADS_DOLT_PASSWORD="" bd init --server \
  --server-host 127.0.0.1 --server-port 3308 --server-user root \
  --prefix <dir> --role maintainer --non-interactive
```

**`shared external`** (server is already running / externally managed — the standard case):
```bash
BEADS_DOLT_PASSWORD="" bd init --server --external \
  --server-host 127.0.0.1 --server-port 3308 --server-user root \
  --prefix <dir> --role maintainer --non-interactive
```

**`remote`** — configure the Dolt sync remote and push. Runs both as the tail of a `shared` init AND standalone on an existing board (the upgrade path — you created the GitHub repo after the board). Steps:

1. **Resolve the URL.** From `git remote get-url origin` if a git origin is set, converting either form to the Dolt scheme:
   - `https://github.com/<org>/<repo>.git` → `git+https://github.com/<org>/<repo>.git`
   - `git@github.com:<org>/<repo>.git` → `git+https://github.com/<org>/<repo>.git`
   - No git origin → default `git+https://github.com/mitre/<dir>.git`.
2. **Register it, idempotently.** Check `bd dolt remote list` first:
   ```bash
   bd dolt remote list
   ```
   - No `origin` → `bd dolt remote add origin <url>`
   - `origin` already set to the same URL → skip (nothing to do)
   - `origin` set to a *different* URL → report it and stop; do not silently overwrite.
3. **Push.**
   ```bash
   bd dolt push
   ```
   If `bd dolt push` fails because the GitHub repo doesn't exist yet, stop and report it — that is the one real blocker.

Standalone precondition: a board must already exist (`.beads/` present). If it does not, run an init mode first — do not silently init as a side effect of `remote`.

## Prerequisites

**All modes:**
- beads CLI: `brew install beads` (or `go install github.com/steveyegge/beads/cmd/bd@latest`)

**Shared/remote modes additionally:**
- A running Dolt SQL server (verify: `dolt --host <host> --port <port> --user root --password "" --no-tls sql -q "SHOW DATABASES;"`)

## Local Mode (default)

Embedded Dolt, no external server. Good for solo work or getting started.

### Initialize

```bash
bd init --non-interactive --role maintainer --prefix <repo-name>
```

The prefix determines issue naming: `<prefix>-<hash>` (e.g. `my-project-a3f2dd`).

### Verify

```bash
bd status
cat .beads/metadata.json
```

Expected metadata — no `dolt_mode` or `dolt_mode: "embedded"`:
```json
{
  "database": "dolt",
  "backend": "dolt",
  "project_id": "<uuid>"
}
```

Done. Start creating issues with `bd create`.

## Shared Mode

Team-wide board backed by a Dolt SQL server. This is the recommended setup for teams — someone runs `dolt sql-server` on a machine the team can reach and each repo connects to it.

**`--external` matters:** if the server is already running / externally managed (the normal case — e.g. the standing MITRE server on 3308), pass `--external` so bd connects as a client instead of trying to start and manage its own server. Use the `shared external` mode arg. Omit `--external` only if you want bd to manage the server lifecycle.

The exact commands are in [Commands by mode](#commands-by-mode) above. Read [references/shared.md](references/shared.md) for the full walkthrough including verification, known issues, and comparison against known-good boards.

**If init ends with `⚠ Setup incomplete … No dolt database found`:** the warning is a known bd 1.0.5 false negative — the board is usually fine. Verify read-only (`bd status`, `bd doctor` without `--fix`) per the known-issues section in [references/shared.md](references/shared.md). Do NOT run `bd doctor --fix`, re-init, or add flags in response.

**Then add the Dolt remote for push/pull** (self-managed, uses the repo's own GitHub URL):
```bash
bd dolt remote add origin git+https://github.com/<org>/<repo>.git
bd dolt push
```

The `git+https://` remote stores Dolt version history in the same GitHub repo as your code. This is self-managed and free.

**Hosted alternatives** exist if you prefer not to run your own server: [DoltHub](https://www.dolthub.com/) offers hosted Dolt databases (SOC2 compliant, private repos free up to 1GB), and [Hosted Dolt](https://hosted.doltdb.com/) provides fully managed Dolt SQL servers. See [references/shared-remote.md](references/shared-remote.md) for remote URL formats.

## Shared + Remote Mode

Shared server with a hosted remote (DoltHub, S3, GCS) instead of `git+https://`. Read [references/shared-remote.md](references/shared-remote.md) — this builds on shared mode by swapping the remote type.

## Upgrading Modes

| From | To | How |
|------|----|-----|
| Local | Shared | Read [references/migration.md](references/migration.md) |
| Shared | Shared+Remote | Run this skill with the standalone `remote` arg (adds the Dolt remote and pushes on the existing board) |

## What bd init Creates

In the repo:
- `.beads/` — config directory (metadata.json, hooks/, config.yaml)
- `AGENTS.md` — agent instructions (if not already present)
- `.agents/skills/beads/` — beads skill for agent tools (if supported)

On the Dolt server (shared mode only):
- A new database named after the prefix (hyphens become underscores)
- Full schema (~28 tables): issues, dependencies, events, labels, comments, etc.

## Troubleshooting

Diagnose read-only FIRST: run `bd doctor` (no `--fix`) and `bd status`, and read what they actually report before changing anything. Only reach for `bd doctor --fix` after confirming a real failure — init can print a false "No dolt database found" warning on a healthy board (see [references/shared.md](references/shared.md)).

bd moves fast and flags change between releases — if a command here errors or warns unexpectedly, reconcile against `bd init --help` / `bd version` before retrying.

**First `bd init` exits 1 with `schema migration: … alter pre-existing dirty tables`:** init created the schema but left it uncommitted, blocking its own migration. Commit the working set (`CALL DOLT_ADD('.')` + `CALL DOLT_COMMIT`) then re-run the same init — full recovery in [references/shared.md](references/shared.md). Do NOT drop the database or hand-migrate.

For mode-specific problems, see the reference for your mode:
- [references/shared.md](references/shared.md) — first-init dirty-tables recovery, dirty config bug, nil global_project_id, Dolt remote constraints
- [references/migration.md](references/migration.md) — embedded-to-shared migration gotchas
