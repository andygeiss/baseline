# Pattern: SQLite in Production (Go)

**Last verified: 2026-08-10 · Driver: `modernc.org/sqlite` (pure Go)**

SQLite is the default database. Configured correctly it serves thousands of requests
per second on one small box with zero operational overhead. Configured by default it
throws `SQLITE_BUSY` under the first concurrent write. This document is the difference.

## Opening the database

Pragmas go in the DSN so every pooled connection gets them:

```go
const pragmas = "?_pragma=busy_timeout(5000)" +
	"&_pragma=journal_mode(WAL)" +
	"&_pragma=synchronous(NORMAL)" +
	"&_pragma=foreign_keys(1)"

// Two pools over the same file: many readers, exactly one writer.
readDB, err := sql.Open("sqlite", "file:"+path+pragmas)
readDB.SetMaxOpenConns(max(4, runtime.NumCPU()))

writeDB, err := sql.Open("sqlite", "file:"+path+pragmas+"&_txlock=immediate")
writeDB.SetMaxOpenConns(1)
```

The rules behind it — all MUST:

1. **WAL mode.** Readers never block the writer and vice versa. Non-negotiable.
2. **`busy_timeout(5000)`.** Waits instead of failing instantly with `SQLITE_BUSY`.
3. **`synchronous(NORMAL)`.** Safe in WAL mode (durable at checkpoint, atomic always);
   `FULL` costs an fsync per commit for little gain here.
4. **`foreign_keys(1)`.** Off by default in SQLite for historic reasons. Turn it on.
5. **Single-writer pool.** SQLite has one writer at a time — model that in Go
   (`SetMaxOpenConns(1)`) instead of discovering it as lock errors. All INSERT/UPDATE/
   DELETE go through `writeDB`, all SELECTs through `readDB`. The store struct takes
   both and hides the split from callers.
6. **`_txlock=immediate` on the write pool.** Write transactions take the lock at
   `BEGIN`, not at first write — prevents deadlock-style upgrade failures.
7. **Every query takes a context** (`QueryRowContext`, `ExecContext`) so a disconnected
   client cancels its work.

## Schema migrations

Forward-only, embedded, applied at boot. No migration framework:

- `internal/store/migrations/0001_create_games.sql`, `0002_...` — ordered, immutable
  once merged. New change = new file, never edit an old one.
- At startup, inside one transaction on `writeDB`: read `PRAGMA user_version`, apply
  each `.sql` file with a number greater than it (sorted via `fs.Glob`), set
  `user_version` to the last applied number. Fail the boot on any error.
- No down migrations. Roll forward; restore from backup for disasters.

## Backups

An unreplicated SQLite file is a single point of data loss. Pick one, MUST have one:

| Option | When |
|---|---|
| **Litestream** (sidecar, streams WAL to S3-compatible storage) | Default for anything users depend on. Restore = `litestream restore`. |
| `VACUUM INTO '/var/lib/app/backups/app-<date>.db'` on a timer in-process | Low-stakes apps; consistent snapshot without locking writers. Run it **on the read pool** — it only reads the source database, so it neither occupies the single write connection (starving writes) nor blocks writers. Target MUST be under the systemd `StateDirectory` — `ProtectSystem=strict` makes every other path read-only, and the failure is silent. Copy snapshots off the box. |

`cp` of a live database file is **not** a backup (torn pages). Test the restore path
once per project, not during the incident.

## Testing

Store tests run against real SQLite — the SQL is the unit under test:

```go
db := newTestDB(t) // opens file in t.TempDir() with the production pragmas+migrations
```

Use a temp file, not `:memory:` — in-memory databases vanish per-connection under a
pool and silently diverge from WAL behavior. `t.TempDir()` cleans up automatically.

## Query conventions

- Plain SQL strings next to the store methods. No ORM, no query builder.
- Parameterized queries only (`?` placeholders) — string-built SQL is banned.
- `errors.Is(err, sql.ErrNoRows)` → translate to `domain.ErrNotFound` at the store
  boundary (sentinels live in `domain` — see
  [go-errors-logging.md](go-errors-logging.md)); callers never see `database/sql` errors.
- Timestamps stored as UTC RFC 3339 text or Unix integers — pick per project, never mix.
