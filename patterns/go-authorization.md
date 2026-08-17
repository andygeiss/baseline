# Pattern: Authorization (Go)

**Tier 1** (safety — never waived) · Last verified: 2026-08-17

The actor in the store signature, the predicate in the SQL, the two answers being
indistinguishable, and a route's protection not being optional where it is registered are
tier 1. Naming the shared rows and deciding where a role check lives are tier 2.

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
4. **Somebody else's row and a row that never existed answer identically.** That property
   is the rule; the status code follows the route. A render answers `domain.ErrNotFound` →
   404, and a mutation that redirects answers with its ordinary redirect and a flash — "that
   token is already gone" — because a revoked row and another user's row are the same
   sentence to the person reading it. **Never 403**, which confirms the row exists and turns
   the id space into a directory an attacker can walk. Reserve 403 for a route the actor may
   never use at all, where existence is not the secret.
5. **Lists, counts, and every aggregate carry the predicate too.** The detail read is the
   one people remember; `SELECT count(*) FROM games` is the one that ships.
6. **A write proves ownership in its own statement.** `UPDATE games SET state = ? WHERE id
   = ? AND user_id = ?`, then check `RowsAffected` — zero means not theirs, and it answers
   by rule 4. A read followed by an unqualified write is two statements where one would do.
7. **Sentinels stay at the store boundary.** Callers see `domain.ErrNotFound`, never a
   `database/sql` error ([go-errors-logging.md](go-errors-logging.md)).

## Private by default

**A route's protection MUST NOT be optional where the route is registered.** Wrapping each
handler by hand reads well and fails open: the day somebody adds a route and forgets the
wrapper, it is public, and nothing says so. Two shapes hold the invariant. Pick by how many
protection classes the app has.

**One class, all under one prefix — mount a second mux.**

```go
pub := http.NewServeMux() // the public routes are registered on this one
app := http.NewServeMux() // everything registered here is behind requireLogin
app.HandleFunc("GET /games", a.games)
app.HandleFunc("GET /games/{id}", a.game)
app.HandleFunc("POST /games/{id}/move", a.move)

pub.Handle("/games", a.requireLogin(app))  // the collection path
pub.Handle("/games/", a.requireLogin(app)) // and everything under it
```

The inner mux matches the full request path, so its patterns are written out in full.
Forgetting a mount fails closed — the route 404s rather than serving unchecked.

⚠️ **Mount both paths.** A pattern ending in `/` does not cover the collection path
itself: with only `"/games/"` registered, `GET /games` becomes a redirect to `/games/`
(307 on Go 1.26), which the inner mux — holding `GET /games` — then 404s. The list route
disappears, and it disappears at runtime.

**More than one class, or paths that do not nest — put the class in a route table.**

```go
type access int

const (
	_        access = iota // not a class: an omitted one must not mean "public"
	public                 // no credential
	pageAuth               // session or token; a browser without one gets the sign-in page
	apiAuth                // session or token; a program without one gets 401 and JSON
)

// Positional literals, so a route with no access class does not compile.
routes := []route{
	{"GET /login", public, a.handleLoginForm},
	{"GET /rooms", pageAuth, a.handleRoomList},
	{"GET /api/me", apiAuth, a.handleAPIMe},
}
```

The wrapper that reads a class MUST panic on anything it does not know, the zero value
included: an unrecognised class is a programming error, and answering it with "public" is
the one wrong answer. Boot is the right time to find out. Routing still lives in one file
([go-http-server.md](go-http-server.md)), and a test walks the table to prove every
non-public row turns an anonymous request away.

`requireLogin` decides only whether somebody is signed in. It MUST NOT decide who owns
what: that answer needs the row, and the query that fetches the row already has it.

## Say which rows are shared

**A project MUST name the rows nobody owns.** Rooms everyone in the company can read,
a public price list, an audit log every admin sees — for these there is no actor
predicate, and that is correct. But a missing predicate and a forgotten one look
identical in a diff, so the project states the answer where the shape lives: `README.md`
or `DESIGN.md`, one line per table. A reader who cannot tell "shared by design" from
"we forgot" has to re-derive the whole model before touching a query.

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

Write it for the write routes too — a POST that moves someone else's game is the same bug
with worse consequences. There, assert the route's own answer *and* that the row did not
move: a refused write and a successful one can share a status code, so the status alone
proves nothing. `-race` and the rest of the suite are unchanged
([go-testing.md](go-testing.md)).

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
