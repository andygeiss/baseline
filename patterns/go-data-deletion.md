# Pattern: Deleting Data (Go)

**Tier 1** (safety — never waived) · Last verified: 2026-08-18

What a delete reaches, a credential resolving to a row rather than to an id, and the actor
predicate on the delete itself are tier 1. Which tables anonymize rather than erase, where
the confirmation lives, and the janitor are tier 2 — they decide how a delete reads, not
whether the data is gone.

Every other document here rules data arriving. This one rules data leaving, and it is the
one that composes: deleting a person touches their rows
([go-authorization.md](go-authorization.md)), their bytes
([go-file-uploads.md](go-file-uploads.md)), their queued mail
([go-email.md](go-email.md)), and every credential that names them
([go-auth-sessions.md](go-auth-sessions.md)). **A delete that misses one of those looks
exactly like a delete that did not** — the page says the account is gone, and the data is
still there.

## Decide what a delete means, table by table

Three answers, and every table holding a person's data gets exactly one.

| | What happens | For |
|---|---|---|
| **Erase** | The row goes. | What is only theirs: their games, their files, their tokens. |
| **Anonymize** | The row stays, the person is cut out of it. | Rows that are other people's context — a message in a shared room, an audit line. |
| **Refuse** | The delete fails while the row exists. | What a person may not walk away from: an unpaid invoice. |

**Write the answer beside the shared-rows line** [go-authorization.md](go-authorization.md)
*Say which rows are shared* already requires — same file, one line per table. A missing
cascade and a deliberate keep look identical in a schema, which is the same reason that
line exists.

## The schema is the delete

`foreign_keys(1)` is on ([go-sqlite.md](go-sqlite.md)), so those three answers are
declarations rather than code:

```sql
-- Erase. Index the child column: a parent delete runs
-- SELECT rowid FROM files WHERE user_id = ?, and without an index that is a
-- linear scan of the child table on every account deletion.
CREATE TABLE files (
	id      TEXT PRIMARY KEY,
	user_id TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE
);
CREATE INDEX files_user_id ON files(user_id);

-- Anonymize. The message stays in the room; the author does not.
CREATE TABLE messages (
	id        TEXT PRIMARY KEY,
	room_id   TEXT NOT NULL REFERENCES rooms(id) ON DELETE CASCADE,
	author_id TEXT     NULL REFERENCES users(id) ON DELETE SET NULL,
	body      TEXT NOT NULL
);

-- Refuse. The DELETE errors while one of these exists.
CREATE TABLE invoices (
	id      TEXT PRIMARY KEY,
	user_id TEXT NOT NULL REFERENCES users(id) ON DELETE RESTRICT
);
```

The rules behind it — all MUST:

1. **The cascade is declared once, in the schema, never re-implemented in a handler.** A
   handler that deletes ten tables in order is ten places to forget the eleventh, and it
   forgets silently. Cascades are recursive, so a child's children go too.
2. **A `user_id` column with no `REFERENCES` clause cascades from nothing.** That is the
   whole failure mode: the delete succeeds, the table keeps the row, every test stays
   green. The test below is what finds it.
3. **`ON DELETE SET NULL` needs a nullable column and a render that handles the null.**
   Decide "deleted user" once, in a template helper — not on the six pages that show an
   author.
4. **`RESTRICT`, not `NO ACTION`.** Both refuse; RESTRICT reports it the moment the parent
   row is touched rather than at the end of the statement, which puts the intent in the
   schema and the error where it happened. The store maps that failure to a sentinel
   like any other ([go-errors-logging.md](go-errors-logging.md)), and the handler tells
   the person what is holding their account open. A 500 says "we broke"; this says "you
   have an unpaid invoice".
5. **One transaction, on the write pool.** The cascade is part of the statement, so this
   is one `DELETE FROM users WHERE id = ?` and the rest is the schema keeping its promise.
6. **A rebuild that changes an `ON DELETE` action copies the children out first.** SQLite
   cannot alter a constraint, so changing one is create-copy-drop-rename — and
   `DROP TABLE` with foreign keys on
   runs an implicit `DELETE FROM` that *does* fire foreign key actions, so dropping a
   parent to rebuild it takes its children with it. The usual escape, turning foreign keys
   off around the rebuild, is closed to a migration that runs inside one transaction:
   `PRAGMA foreign_keys` is a no-op there. Decide the action before the table ships and
   none of this comes up.

## A credential resolves to a row, not to an id

**Sessions are the hole no cascade reaches.** The session table is keyed by token and its
payload is opaque to SQL ([go-auth-sessions.md](go-auth-sessions.md)), so no foreign key
can name the user in it. Delete the person and their browser stays signed in — the id is
still in a session that is still valid for hours.

The fix is not a `user_id` column on the session table. It is that the middleware resolving
the credential loads the row:

```go
// "Signed in" means a user that exists, not an id written into a session twelve
// hours ago. One indexed read, and a deleted account is signed out everywhere it
// was signed in — with no session rows to hunt and no second place to remember.
id := domain.UserID(a.sessions.GetString(r.Context(), "userID"))
if id == "" {
	a.redirectToLogin(w, r)
	return
}
u, err := a.users.User(r.Context(), id)
if errors.Is(err, domain.ErrNotFound) {
	a.sessions.Destroy(r.Context()) // the row is gone, so the cookie goes too
	a.redirectToLogin(w, r)
	return
}
if err != nil {
	a.serverError(w, r, err) // a database that is down is not a signed-out reader
	return
}
// The row, not the id it came from — go-auth-sessions.md rule 6.
next.ServeHTTP(w, r.WithContext(context.WithValue(r.Context(), userKey, u)))
```

- **Machine tokens need no rule of their own.** They are rows with a `user_id`, so they
  cascade, and the next request presenting one gets the `401` that
  [go-auth-sessions.md](go-auth-sessions.md) rule 6 already requires.
- **Without this the reader gets a signed-in shell full of 404s**, because every store
  method answers `domain.ErrNotFound` for an actor who no longer exists. That is the
  visible half. The half that makes it tier 1 is a schema that ever reuses an id: the next
  person to be handed it inherits a live session.

## The bytes are not in the transaction

A blob is a row and needs nothing here. **Bytes in a directory are not**, so:

- **Collect the stored names inside the transaction, before the delete.** After it commits
  there is no row left to say which files were theirs.
- **Commit, then unlink.** Bytes first is a rolled-back transaction pointing rows at files
  that are gone — the same order, for the same reason, as
  [go-file-uploads.md](go-file-uploads.md) *Where the bytes live*.
- **The janitor is the backstop, not the plan.** Files with no row are already swept
  ([go-background-work.md](go-background-work.md)); a delete that leans on the sweep leaves
  a stranger's bytes on disk until it next runs.

## Queued mail holds an address

An outbox row carries an address, which is the person's data sitting outside `users`. Give
it a nullable `user_id REFERENCES users(id) ON DELETE CASCADE` — nullable because an
invitation goes to somebody who is not a user yet — and the delete reaches it.

**A goodbye message therefore cannot be queued by the transaction that deletes the
account.** Queued before the delete, the cascade takes it away again; queued after, it has
no user to reference. Send it in an earlier transaction, or do not send it.

## Deleting is a write

[go-authorization.md](go-authorization.md) rules it whole — the actor from the session and
never the form, the predicate in the statement, `RowsAffected` checked, and somebody else's
account answering exactly like one that was never there. Three things it adds:

- **The route is a POST behind a confirmation the server can check** — a page that asks
  them to type the account name, which is a second request with something in it to verify.
  `hx-confirm` is enough for a revoke somebody can redo; for this it is a dialog htmx
  draws, so with htmx switched off there is no confirmation at all, and there was never
  anything on the wire for the server to check either way.
- **A self-service delete asks for the password again.** A session found unlocked is
  otherwise enough to erase somebody.
- **A restore is out of the binary's hands.** The rows come back with the backup, so the
  retention window is what makes a delete final; that window lives in the operations
  repository, and the README says which one applies.

## Testing

**The all-tables test is the one that matters,** because the defect is a table added a year
from now with no `REFERENCES` clause:

```go
// Reading the schema at runtime is the whole point: a table created next year is
// in this test the day it exists. A test that names its tables goes stale in the
// same commit that creates the problem.
for _, table := range tableNames(t, db) {
	for _, col := range textColumns(t, db, table) {
		var n int
		// Identifiers cannot be bound, so they are quoted from sqlite_master —
		// never from anything a request touched.
		q := fmt.Sprintf(`SELECT count(*) FROM %q WHERE %q = ?`, table, col)
		if err := db.QueryRow(q, deletedID).Scan(&n); err != nil {
			t.Fatal(err)
		}
		if n != 0 {
			t.Errorf("%s.%s still holds the deleted user in %d row(s)", table, col, n)
		}
	}
}
```

Seed one row for the user in every table the app writes before deleting, or the test proves
only that empty tables are empty.

**It finds references, not copies**, and that is the limit worth knowing before you trust
it. A row holding somebody's data under another name — an address in an outbox, a display
name copied at write time — carries no id for the sweep to match, so it stays green while
the data stays. Name those columns and assert on them by value. The session table is
invisible for a third reason: its id sits inside an opaque payload rather than a column,
which is what the next test is for.

- **The signed-out test.** A request carrying the deleted user's cookie gets the sign-in
  page — not a 500, and not a rendered page.
- **The two-user delete.** Bob deletes Alice's file id, gets the ordinary answer for a
  row that never existed, and the file is still there
  ([go-file-uploads.md](go-file-uploads.md) *Testing*).
- **The refusing table.** With an invoice outstanding, the delete answers the domain
  sentinel and the account still exists afterwards.

## Anti-patterns

- ❌ A `deleted_at` column called a delete. Soft delete is a filter every future query has
  to remember, and the data is still there. A project may want one; it MUST NOT then tell
  anybody their data is gone.
- ❌ Deleting table by table in a handler, or a `DELETE` loop over a list of table names.
- ❌ `ON DELETE CASCADE` on a shared row to make an error go away. That deletes the room
  because its creator left.
- ❌ A GET link that deletes.
- ❌ Keeping "just the email" of a deleted account for a mailing list. That is the one
  field they asked you to lose.

## Facts verified (2026-08-18)

- Foreign keys are off by default and enabled per connection; `ON DELETE` actions are
  enforcement, so they do nothing without the pragma:
  https://www.sqlite.org/foreignkeys.html
- RESTRICT "happens as soon as the field is updated — not at the end of the current
  statement as it would with an immediate constraint":
  https://www.sqlite.org/foreignkeys.html#fk_actions
- Child key indices are "not required … but they are almost always beneficial"; without
  one the parent delete's lookup is "forced to do a linear scan of the entire child
  table":
  https://www.sqlite.org/foreignkeys.html#fk_indexes
- Foreign key actions count as trigger programs against `SQLITE_MAX_TRIGGER_DEPTH`, so
  cascades are recursive and bounded: https://www.sqlite.org/foreignkeys.html#fk_actions
- `DROP TABLE` "performs an implicit DELETE FROM command before removing the table", and
  that implicit delete "does cause any configured foreign key actions to take place":
  https://www.sqlite.org/lang_droptable.html
- `PRAGMA foreign_keys` "is a no-op within a transaction; foreign key constraint
  enforcement may only be enabled or disabled when there is no pending BEGIN or SAVEPOINT":
  https://www.sqlite.org/pragma.html#pragma_foreign_keys
