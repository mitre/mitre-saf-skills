# Embedded to Shared Server Migration

Move an existing local/embedded beads board to a shared Dolt SQL server.

## When to Use

- You started with `bd init` (embedded mode) and now want team-wide access
- The `.beads/dolt/<db>/` directory exists locally with issue data
- The shared server database is empty or doesn't exist yet

## Step 1: Export from Embedded

```bash
dolt --data-dir=.beads/dolt/<db> sql -r json \
  -q "SELECT * FROM issues" > /tmp/issues-export.json
```

Check the row count:
```bash
python3 -c "import json; data=json.load(open('/tmp/issues-export.json')); print(f'{len(data[\"rows\"])} issues')"
```

## Step 2: Initialize Shared Mode

```bash
bd init \
  --server \
  --server-host <host> \
  --server-port <port> \
  --server-user <user> \
  --prefix <same-prefix-as-before> \
  --role maintainer \
  --non-interactive
```

## Step 3: Import to Shared Server

Generate SQL with column filtering (shared schema may differ from embedded):

```bash
python3 -c "
import json
data = json.load(open('/tmp/issues-export.json'))
for row in data['rows']:
    cols = ', '.join(row.keys())
    vals = ', '.join(
        'NULL' if v is None else f\"'{str(v).replace(chr(39), chr(39)+chr(39))}'\".replace('\\n','\\\\n')
        for v in row.values()
    )
    print(f'INSERT INTO issues ({cols}) VALUES ({vals});')
" > /tmp/import.sql
```

Then import:
```bash
dolt --host <host> --port <port> --user <user> --password "<password>" --no-tls \
  sql -q "USE <database_name>; $(cat /tmp/import.sql)"
```

For large imports, pipe the SQL:
```bash
(echo "USE <database_name>;"; cat /tmp/import.sql) | \
  dolt --host <host> --port <port> --user <user> --password "<password>" --no-tls sql
```

## Step 4: Verify

```bash
bd list                    # should show all migrated issues
bd status                  # counts should match export
```

## Gotchas

- **NOT NULL text columns** need empty string, not NULL. If import fails on a NOT NULL constraint, replace NULL text values with `''`.
- **Boolean fields** are stored as 0/1 in Dolt, not true/false.
- **`bd export`** does NOT read from embedded storage when a shared server is configured. Use `dolt --data-dir=` to access embedded data directly.
- **Schema drift** — the shared server schema (created by the current bd version) may have columns the old embedded schema didn't. The import SQL should only reference columns that exist in both. Filter columns if needed.
- **Commit after import** — the imported data is in the Dolt working set but not committed:
  ```bash
  dolt --host <host> --port <port> --user <user> --password "<password>" --no-tls \
    sql -q "USE <database_name>; CALL DOLT_ADD('-A'); CALL DOLT_COMMIT('-m','migrate: import from embedded');"
  ```
