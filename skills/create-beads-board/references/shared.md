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
