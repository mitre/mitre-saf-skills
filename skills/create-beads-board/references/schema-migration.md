# Schema-Version Migration on a Remote-Backed Board

Distinct from [migration.md](migration.md), which covers **mode** migration (embedded → shared).
This covers **schema-version** migration — bd's own `schema_migrations` version moving forward
(e.g. v46 → v54) on a board that syncs with a Dolt remote.

## When you hit this

Any `bd` command against the board fails, including read-only ones like `bd stats`:

```
refusing to auto-apply 8 pending schema migrations to a remote-backed database
(v46 -> v54): migrating clones independently forks the schema (#4259)
```

This is bd protecting you, not a bug. Applying schema migrations on more than one clone forks
the schema so `bd dolt pull` can no longer merge — and the break is **silent and unrecoverable**.
bd cannot tell whether another clone exists, so it refuses and asks a human.

## Before you migrate: confirm the sole-migrator precondition

**Only ONE machine may migrate.** This is a question only the human can answer, and getting it
wrong is unrecoverable. Confirm explicitly:

- Is this machine the designated migrator for this board?
- Does any other clone sync this board — another laptop, a colleague, CI?

If other clones exist, they must each `bd dolt pull` **after** the migrator pushes, *before* their
own binary is upgraded. Their upgrade then has nothing to migrate.

Useful evidence while asking (does NOT replace the human's answer):

```bash
# Which boards on the shared server are already at the target version?
for db in <this-db> <a-known-good-db>; do
  dolt --host 127.0.0.1 --port 3308 --user root --password "" --no-tls \
    sql -q "USE \`$db\`; SELECT MAX(version) FROM schema_migrations;"
done

# Recent activity — has something else touched this database?
dolt --host 127.0.0.1 --port 3308 --user root --password "" --no-tls \
  sql -q "USE \`<db>\`; SELECT date, committer, message FROM dolt_log ORDER BY date DESC LIMIT 5;"
```

A sibling board already sitting at the target version is good evidence the target is proven
rather than speculative.

## The deadlock (verified 2026-07-27, bd 1.1.0)

Setting `BD_ALLOW_REMOTE_MIGRATE=1` gets past the fork gate — and then reveals a **second, real**
error that the gate was masking:

```
Error: failed to open database: failed to initialize schema: schema migration:
pending schema migrations alter pre-existing dirty tables: issues;
run 'bd dolt commit' to commit the working set at the current schema,
then re-run the migration (gastownhall/beads#4566)
```

The migration refuses to `ALTER` a table with an uncommitted working set. bd's suggested fix is
`bd dolt commit` — **but that also fails**, because bd will not open an unmigrated database at all.

> Commit needs open → open needs migrate → migrate needs commit.

That is the whole reason "I ran `BD_ALLOW_REMOTE_MIGRATE=1 bd migrate` and had no luck" happens:
the operator follows bd's own instruction and bd cannot execute its own instruction.

**Break the deadlock by committing the working set with the Dolt client directly, bypassing bd.**
Same mechanism as the first-init dirty-tables recovery in [shared.md](shared.md); only the trigger
differs (there: freshly created `new table`s; here: a `modified` table on an existing board).

## Recovery

**1. Take a restore point.** Dolt branches are cheap and give a real rollback target:

```bash
dolt --host 127.0.0.1 --port 3308 --user root --password "" --no-tls \
  sql -q "USE \`<db>\`; CALL DOLT_BRANCH('pre-v<target>-migrate-<YYYYMMDD>');"
```

**2. Inspect what is dirty before committing it blind** — you are about to commit someone's
working set:

```bash
dolt --host 127.0.0.1 --port 3308 --user root --password "" --no-tls \
  sql -q "USE \`<db>\`; SELECT * FROM dolt_status;"
```

**3. Commit the working set via Dolt, not bd:**

```bash
dolt --host 127.0.0.1 --port 3308 --user root --password "" --no-tls \
  sql -q "USE \`<db>\`; CALL DOLT_ADD('.'); CALL DOLT_COMMIT('-m','Commit working set at schema v<current> prior to v<current>-\>v<target> migration');"
```

Re-check `dolt_status` — it must come back empty.

**4. Re-run the migration:**

```bash
BD_ALLOW_REMOTE_MIGRATE=1 bd migrate
```

Success looks like `Updating Dolt schema version: <old> → <new>` / `✓ Version updated`.

**5. Verify with bd's own tools — do not assert it by hand:**

```bash
bd migrate schema   # idempotent → "✓ Schema already at vNN"
bd stats            # connects; issue counts match what you started with
bd ready            # returns real work
bd export -o /tmp/post-migrate.jsonl && wc -l /tmp/post-migrate.jsonl   # round-trips every issue
```

**6. Push — this is mandatory, not cleanup:**

```bash
bd dolt push
```

Publishing the migrated schema is what stops other clones from forking. A migration that is not
pushed leaves every other clone one `bd migrate` away from the unrecoverable state the gate exists
to prevent.

Confirm the push actually landed by checking the remote ref moved — not by trusting the message:

```bash
git ls-remote origin | grep -i dolt   # refs/dolt/data hash should differ from before the push
```

## Gotchas

- **The first error masks the real one.** Do not treat the `#4259` fork warning as the failure —
  it is a gate. The actionable error only appears once `BD_ALLOW_REMOTE_MIGRATE=1` is set. Read the
  second error, not the first.
- **`.beads/push-state.json` may not update after a successful push** (observed bd 1.1.0). The
  authoritative evidence is the remote ref from `git ls-remote`, not the local state file. Someone
  reading that file later may wrongly conclude the board was never pushed.
- **Do not drop the database, and do not hand-edit the schema.** The migration is blocked by a
  dirty working set, nothing more.
- **`bd backup status` fails too** while the database is unmigrated — it is a bd command, and bd
  cannot open the database. Use the Dolt branch as the restore point instead.
- **Legacy artifacts** from an older SQLite→Dolt migration (`.beads/beads.db*`,
  `beads.db.migrated`, `beads.backup-pre-dolt-*.db`) are unrelated dead weight in server mode.
  Removing them is a separate decision — never bundle it into a schema migration.

## Upstream issues referenced by these messages

| Issue | What it governs |
|---|---|
| `gastownhall/beads#4259` | Refusal to auto-apply schema migrations on a remote-backed database |
| `gastownhall/beads#4566` | Migration blocked by pre-existing dirty tables |
| `gastownhall/beads#4516` | The "smart gate" that reads the remote's cached schema state |

bd moves fast; reconcile these against `bd version` and the current messages before relying on
the exact wording.
