# Pattern: SQLite in Production (Go)

**Tier 2** (shape — waived only on the record) · Last verified: 2026-08-15 · Driver: `modernc.org/sqlite` (pure Go)

**The pragmas, the single-writer pool, and parameterized queries are tier 1 and never
waived.** Dropping either of the first two loses data; dropping the third hands over the
database.

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

// openDB returns two pools over the same file: many readers, exactly one
// writer. Neither call touches the file — the first query does — so a bad path
// surfaces when the migrations run, not here.
func openDB(path string) (readDB, writeDB *sql.DB, err error) {
	readDB, err = sql.Open("sqlite", "file:"+path+pragmas)
	if err != nil {
		return nil, nil, fmt.Errorf("open read pool: %w", err)
	}
	readDB.SetMaxOpenConns(max(4, runtime.NumCPU()))

	writeDB, err = sql.Open("sqlite", "file:"+path+pragmas+"&_txlock=immediate")
	if err != nil {
		readDB.Close() // already open — don't leak it on the way out
		return nil, nil, fmt.Errorf("open write pool: %w", err)
	}
	writeDB.SetMaxOpenConns(1)
	return readDB, writeDB, nil
}
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

**The question every project MUST answer before launch: if the server disappears
right now, what have you lost?** The database is one file on one machine, and so
is any snapshot written beside it. A dead disk takes both in the same second.

Three answers are legitimate — "I don't know" is not:

| Answer | What you run | Recovery point |
|---|---|---|
| **"Nothing that matters."** The data rebuilds from somewhere else, or nobody would miss it. | Nothing. Record the decision in the README so the next person sees a choice, not an oversight. | — |
| **"Up to a day."** | `VACUUM INTO` on a timer, **plus** a second mechanism that copies the snapshot off the machine. | The last snapshot that left the box |
| **"Seconds."** Anything users create and expect to find again. | Continuous replication of the WAL to storage somewhere else. The deployment provides it; the operations repository has the runbook. | Seconds |

`VACUUM INTO` gives a consistent snapshot, and in WAL mode it blocks no writer:

```go
// The snapshot goes beside the database, built from that file's own directory:
// every other path may be read-only, and VACUUM INTO resolves a relative path
// against the process's working directory, not the database's.
dst := filepath.Join(filepath.Dir(cfg.DatabaseURL), "app-"+day+".db")

// The read pool, never the write pool: this statement only reads, so running
// it on the single write connection would starve writes for its whole duration.
_, err := readDB.ExecContext(ctx, "VACUUM INTO ?", dst)
```

That placement is also its limit — the snapshot is on the same disk as the thing
it protects, so *getting it off the box is a separate job with its own
credentials and its own rehearsal*. Budget for that before picking this row.

`cp` of a live database file is **not** a backup (torn pages). Whichever row you
pick, restore from it once, on purpose, before launch — not during the incident.

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
