# Shared + Remote Mode

Adds a Dolt remote on top of shared server mode. Enables `bd dolt push` / `bd dolt pull` for cross-machine sync and team collaboration.

## Prerequisites

- A working shared-mode board (follow [shared.md](shared.md) first)
- A GitHub repo for the project (the default remote target)

## Step 1: Set Up Shared Mode First

If not already done, follow [shared.md](shared.md) to initialize the board with `--server`. Step 3 there already covers adding the `git+https://` remote — if you followed it, you're done.

## Step 2: Add a Dolt Remote

### GitHub repo (default — recommended)

Use the repo's own GitHub URL with the `git+https://` scheme. This stores Dolt version history alongside the code:

```bash
bd dolt remote add origin git+https://github.com/<org>/<repo>.git
```

This is the standard pattern — Vulcan, saf-cli, and other MITRE SAF projects all use it.

### Alternative remote types

Only use these if you have a specific reason not to use the GitHub remote:

```bash
# DoltHub (SOC2 compliant, private repos free up to 1GB)
bd dolt remote add origin https://doltremoteapi.dolthub.com/<org>/<database>

# File-based (local/NFS)
bd dolt remote add origin file:///path/to/remote

# S3
bd dolt remote add origin aws://[bucket:table]/database

# GCS
bd dolt remote add origin gs://[bucket]/database
```

## Step 3: Push and Verify

```bash
bd dolt push
bd dolt remote list    # confirm the remote is registered
bd dolt pull           # verify round-trip
```

## Constraints

- Dolt remotes are 1-to-1 with databases. Each project needs its own remote URL — two projects cannot share one GitHub remote for Dolt data.
- `bd dolt push` pushes the current branch. Use `bd branch` to manage branches.
- The dirty-config bug (#4078) can block `bd dolt pull` — see [shared.md](shared.md) for the recovery command.

## Team Onboarding

Once the remote is configured, other team members set up their local board pointing at the same shared database:

```bash
bd init \
  --server \
  --server-host <host> \
  --server-port <port> \
  --server-user <user> \
  --prefix <same-prefix> \
  --role maintainer \
  --non-interactive
bd dolt remote add origin git+https://github.com/<org>/<repo>.git
bd dolt pull
```

They connect to the same shared database and pull the latest state from the remote.
