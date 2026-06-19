---
name: create-beads-board
description: >-
  Set up a beads issue-tracking board in any repo. Supports three modes:
  local (embedded Dolt, no server needed), shared (team Dolt SQL server),
  and shared+remote (shared server with DoltHub sync). Use when initializing
  beads in a new repo, connecting to a shared Dolt server, troubleshooting
  bd init, or migrating from embedded to shared mode. Triggers on "set up
  beads", "create a board", "init beads", "connect to the beads server",
  "new beads board", or "set up issue tracking".
compatibility: Requires beads CLI (bd). Shared/remote modes require a running dolt sql-server.
license: Apache-2.0
metadata:
  author: mitre-saf
---

# Create Beads Board

Initialize a beads issue-tracking board. Three modes, one default.

## Mode Detection

Determine the mode from the user's request. First match wins:

| User says | Mode |
|-----------|------|
| "shared server", "team board", "connect to dolt server", port number | **shared** — read [references/shared.md](references/shared.md) |
| "remote", "dolthub", "sync across machines", "push/pull" | **shared-remote** — read [references/shared-remote.md](references/shared-remote.md) |
| Nothing specific, "local", "just set up beads", "init" | **local** (default) |

If unclear, ask the user:

**Which setup do you need?**
- "Local (just me)" — embedded Dolt, no server needed, good for getting started
- "Shared (team server)" — connect to a team Dolt SQL server for shared issue tracking
- "Shared + remote sync" — shared server with DoltHub/GitHub sync across machines

Default to **local** if the user doesn't have a preference — it works without any server and can be upgraded later.

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

Team-wide board backed by a self-managed Dolt SQL server. This is the recommended setup for teams — you run `dolt sql-server` on a machine the team can reach and each repo connects to it.

Read [references/shared.md](references/shared.md) for the full walkthrough including verification, known issues, and comparison against known-good boards.

**Quick version** (if you already know the server details):
```bash
bd init \
  --server \
  --server-host 127.0.0.1 \
  --server-port 3308 \
  --server-user root \
  --prefix <repo-name> \
  --role maintainer \
  --non-interactive
```

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
| Shared | Shared+Remote | `bd dolt remote add origin git+https://github.com/<org>/<repo>.git` then `bd dolt push` |

## What bd init Creates

In the repo:
- `.beads/` — config directory (metadata.json, hooks/, config.yaml)
- `AGENTS.md` — agent instructions (if not already present)
- `.agents/skills/beads/` — beads skill for agent tools (if supported)

On the Dolt server (shared mode only):
- A new database named after the prefix (hyphens become underscores)
- Full schema (~28 tables): issues, dependencies, events, labels, comments, etc.

## Troubleshooting

Run `bd doctor --fix` to diagnose and repair common issues.

For mode-specific problems, see the reference for your mode:
- [references/shared.md](references/shared.md) — dirty config bug, nil global_project_id, Dolt remote constraints
- [references/migration.md](references/migration.md) — embedded-to-shared migration gotchas
