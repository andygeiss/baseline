# Pattern: Authorization (Go)

**Tier 1** (safety — never waived) · Last verified: 2026-08-17

The actor in the store signature, the predicate in the SQL, the 404 for a row the actor
does not own, and the private-by-default mount are tier 1. Where a role check lives, once
a project has roles at all, is tier 2.

[go-auth-sessions.md](go-auth-sessions.md) answers *who is signed in*. This document
answers the question after it, and that one is where data leaks: *may this actor touch
this row?* Perfect authentication protects nothing if `GET /games/{id}` renders whichever
id it is handed.

## The rule

**Every read and every write of a row somebody owns names the actor in the same SQL
statement that names the row.** One statement, both predicates — never a check before the
query, never a comparison after it:

```go
// Game returns the actor's game. The actor is a parameter, so there is no
// Game(ctx, id) to reach for by mistake: the unsafe call does not compile.
func (s *Store) Game(ctx context.Context, actor domain.UserID, id domain.GameID) (domain.Game, error) {
	var g domain.Game
	err := s.readDB.QueryRowContext(ctx,
		`SELECT id, title, state FROM games WHERE id = ? AND user_id = ?`,
		id, actor,
	).Scan(&g.ID, &g.Title, &g.State)
	if errors.Is(err, sql.ErrNoRows) {
		return domain.Game{}, domain.ErrNotFound // not forbidden — see below
	}
	if err != nil {
		return domain.Game{}, fmt.Errorf("game %q: %w", id, err)
	}
	return g, nil
}
```

The rules behind it — all MUST:

1. **The actor is a parameter of every store method that touches an owned row.** Model the
   constraint in Go instead of remembering it, the same move as the single-writer pool in
   [go-sqlite.md](go-sqlite.md).
2. **The predicate lives in the SQL.** A comparison in Go is a line anyone can delete
   without reddening a test that only exercises the owner.
3. **The actor comes from the session, never from the request.** A `user_id` in a form
   field, a query parameter, or a hidden input is user input, and so is the id in the
   path.
4. **A row the actor does not own is missing, not forbidden — `domain.ErrNotFound`, 404.**
   A 403 confirms the row exists, which turns the id space into a directory an attacker
   can walk. Reserve 403 for a route the actor may never use at all, where existence is
   not the secret.
5. **Lists, counts, and every aggregate carry the predicate too.** The detail read is the
   one people remember; `SELECT count(*) FROM games` is the one that ships.
6. **A write proves ownership in its own statement.** `UPDATE games SET state = ? WHERE id
   = ? AND user_id = ?`, then check `RowsAffected` — zero means not theirs, and it is the
   same 404. A read followed by an unqualified write is two statements where one would do.
7. **Sentinels stay at the store boundary.** Callers see `domain.ErrNotFound`, never a
   `database/sql` error ([go-errors-logging.md](go-errors-logging.md)).

## Private by default

Two muxes, so a new route is signed-in because of where it was registered rather than
because whoever added it remembered a wrapper:

```go
pub := http.NewServeMux()
pub.HandleFunc("GET /{$}", a.home)
pub.HandleFunc("POST /login", a.login)

app := http.NewServeMux() // everything here is behind requireLogin
app.HandleFunc("GET /games/{id}", a.game)
app.HandleFunc("POST /games/{id}/move", a.move)

pub.Handle("/games/", a.requireLogin(app))
```

The inner mux matches the full request path, so its patterns are written out in full and
no prefix gets stripped. Forgetting the mount line fails closed — the route 404s instead
of serving without a check — which is the whole reason to spend a second mux. Routing
still lives in one file ([go-http-server.md](go-http-server.md)).

`requireLogin` decides only whether somebody is signed in. It MUST NOT decide who owns
what: that answer needs the row, and the query that fetches the row already has it.

## Roles, when a project grows them

Wait until a second kind of actor exists. When one does, one function in `domain` answers
every question — `can(actor, action, resource) bool`, table-tested — and no handler grows
an `if actor.IsAdmin`. An admin who may read every row still goes through a store method
that takes an actor; the actor is the admin, and the predicate widens in one place.

A machine token acts as the user who created it and never wider
([go-auth-sessions.md](go-auth-sessions.md) *Machine tokens*).

## Testing

**The two-user test, for every handler that touches an owned row.** A second signed-in
user asks for the first user's id and gets 404:

```go
// The second user is the point. An anonymous request tests requireLogin and
// passes while every ownership bug in the handler survives.
alice, bob := signIn(t, srv), signIn(t, srv)
game := createGame(t, srv, alice)

if res := bob.get(t, "/games/"+game.ID); res.StatusCode != http.StatusNotFound {
	t.Errorf("bob reading alice's game = %d, want 404", res.StatusCode)
}
```

Write it for the write routes as well as the read routes — a POST that moves someone
else's game is the same bug with worse consequences. `-race` and the rest of the suite
are unchanged ([go-testing.md](go-testing.md)).

## Anti-patterns

- ❌ Casbin, OPA, or a policy language. The policy here is a `WHERE` clause and one `can`
  function; a project that has outgrown both has a different shape of problem, and this
  baseline has not met it.
- ❌ Hiding the link and calling it done — `{{if eq .Game.UserID .User.ID}}`. The template
  chooses what to show; the route chooses what to allow, and `curl` never renders a
  template.
- ❌ An unguessable id as the protection. A random id is not a permission: it lands in
  logs, browser history, and pasted screenshots, and it stays valid for everyone who has
  ever seen it.
- ❌ Ownership in a middleware. It has to fetch the row to answer, so the app pays two
  queries for something the one query already knew — and the two can disagree.
