# Shared Mode — Full Walkthrough

Connect a beads board to an external Dolt SQL server so the whole team works from one database.

## Step 1: Verify Server

Before init, confirm the Dolt server is reachable:

```bash
dolt --host <host> --port <port> --user <user> --password "<password>" --no-tls \
  sql -q "SHOW DATABASES;"
```

Common defaults: host `127.0.0.1`, port `3308`, user `root`, empty password.

If this fails, the server isn't running or isn't reachable. Fix connectivity before proceeding.

## Step 2: Initialize

Run from the repo root:

```bash
bd init \
  --server \
  --server-host <host> \
  --server-port <port> \
  --server-user <user> \
  --prefix <repo-name> \
  --role maintainer \
  --non-interactive
```

**Flags:**
- `--server` — use external Dolt server (not embedded)
- `--server-host/port/user` — connection details (set password via `BEADS_DOLT_PASSWORD` env var)
- `--prefix <repo-name>` — determines issue prefix and database name (e.g. `my-project` creates database `my_project`, issues named `my-project-a3f2dd`)
- `--role maintainer` — full read/write access
- `--non-interactive` — skip prompts, use defaults

## Step 3: Add the Dolt Remote

Add the repo's GitHub URL as the Dolt remote so `bd dolt push` / `bd dolt pull` work for the whole team. The `git+https://` scheme is the standard for Dolt remotes backed by GitHub repos:

```bash
bd dolt remote add origin git+https://github.com/<org>/<repo>.git
bd dolt push
```

This stores Dolt's version history (refs/dolt/data) in the same GitHub repo as the code. Each database must have its own remote — multiple databases cannot share one GitHub remote URL.

**Verify the remote was added:**
```bash
bd dolt remote list
```

Expected output:
```
origin               git+https://github.com/<org>/<repo>.git
```

## Step 4: Verify Setup

```bash
bd status
bd list
cat .beads/metadata.json
```

**Expected metadata.json:**
```json
{
  "database": "dolt",
  "backend": "dolt",
  "dolt_mode": "server",
  "dolt_server_host": "<host>",
  "dolt_server_port": <port>,
  "dolt_server_user": "<user>",
  "dolt_database": "<prefix_with_underscores>",
  "project_id": "<uuid>"
}
```

**Verify the database exists on the server:**
```bash
dolt --host <host> --port <port> --user <user> --password "<password>" --no-tls \
  sql -q "USE <database_name>; SHOW TABLES;"
```

Expect ~28 tables (issues, dependencies, events, labels, comments, etc.).

## Step 5: Compare Against a Known-Good Board

If unsure whether setup is correct, compare metadata against a working board in another project:

```bash
cat /path/to/working-project/.beads/metadata.json
```

Key fields to match: `dolt_mode: "server"`, same host/port/user, a real `project_id` UUID (not all zeros).

## Known Issues

### First `bd init` fails with `schema migration: alter pre-existing dirty tables` (exit 1)

The very first `bd init --server [--external]` against a fresh database can abort with:

```
Error: failed to open Dolt store: failed to initialize schema: schema migration:
pending schema migrations alter pre-existing dirty tables:
child_counters, comments, ... issues, labels, metadata
```

**What actually happened (verified 2026-07-02):** init DID create the database and the full schema, but left every table uncommitted in Dolt's working set (`dolt_status` shows them all as `new table`). bd's schema-migration step then refuses to `ALTER` uncommitted tables and bails — leaving a half-initialized board (server schema present, but **no local `.beads/metadata.json` written**, so no bd command can connect yet).

This is NOT a "database migration needed" you fix by hand, and it is NOT a reason to drop the database. The migration is blocked purely by the dirty working set. Recovery is two steps:

1. **Commit the working set bd already created**, so the tables are clean:
   ```bash
   dolt --host <host> --port <port> --user <user> --password "<password>" --no-tls \
     sql -q "USE <database_name>; CALL DOLT_ADD('.'); CALL DOLT_COMMIT('-m','Initialize beads schema');"
   ```
2. **Re-run the exact same `bd init` command.** With clean tables the migration completes, init writes local config, installs hooks/AGENTS.md/integrations, auto-commits the beads files to git, and exits 0.

Then confirm with bd's own tools (do not assert it by hand):
```bash
bd migrate schema   # idempotent → "✓ Schema already at vNN" means nothing pending
bd status           # connects, shows issue counts → board works
```

Re-running init is safe: it detects the existing schema and does not recreate tables. The trailing `⚠ Setup incomplete … No dolt database found` on the successful run is the separate false-negative below.

### False "Setup incomplete: No dolt database found" warning at end of init

Filed upstream as [gastownhall/beads#4553](https://github.com/gastownhall/beads/issues/4553) — init diagnostics stat the local `.beads/dolt` dir, which server-mode repos intentionally don't have. bd 1.0.5 can end an otherwise-successful server-mode init with:

```
⚠ Setup incomplete. Some issues were detected:
  • Database: No dolt database found
Run bd doctor --fix to see details and fix these issues.
```

**Do NOT run `bd doctor --fix`, re-init, or add flags in response.** Verified 2026-07-02: the warning fires even when the database and full 28-table schema were created correctly, and it fires identically with and without `--external`. Verify read-only instead:

```bash
bd status        # connects and shows 0 issues → board works
bd doctor        # (no --fix) database checks pass → warning was false
dolt --host <host> --port <port> --user <user> --password "<password>" --no-tls \
  sql -q "USE <database_name>; SHOW TABLES;"   # expect ~28 tables
```

If those pass, setup is complete — proceed to Step 3. Only if they fail is there a real problem.

### "Cannot merge with uncommitted changes" on `bd dolt pull`

Every `bd remember`/`bd forget`/`bd config set` in server mode leaves the config table dirty. `bd dolt commit` silently no-ops on config-only changes (steveyegge/beads#4078, open as of v1.0.5).

**Recovery:**
```bash
dolt --host <host> --port <port> --user <user> --password "<password>" --no-tls \
  sql -q "USE <database_name>; CALL DOLT_ADD('config'); CALL DOLT_COMMIT('-m','flush config writes (4078 recovery)');"
```
Then `bd dolt pull` works. Recurs after every `bd remember` until the upstream fix lands.

### Dolt remotes are 1-to-1 with databases

Each database needs its own git remote URL. Multiple databases cannot share one remote. To sync multiple projects, each needs a separate DoltHub repo.

### `global_project_id` is nil UUID

As of bd v1.0.5 (pre-release), `global_project_id` in metadata.json may show `00000000-0000-0000-0000-000000000000`. This is cosmetic — the global registration feature is not fully implemented yet. The local board works correctly.

### "No Dolt remote configured" warning

If you skipped Step 3, you'll see this warning. Fix it by adding the remote:

```bash
bd dolt remote add origin git+https://github.com/<org>/<repo>.git
bd dolt push
```

For DoltHub or other remote types, see [shared-remote.md](shared-remote.md).
