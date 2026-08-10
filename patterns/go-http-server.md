# Pattern: Go HTTP Server

**Last verified: 2026-08-10**

Stdlib only. `net/http.ServeMux` (Go 1.22+ pattern routing) covers everything a
router package used to do.

## Routing

All routes registered in one file (`internal/app/routes.go`) so the URL surface is
readable at a glance:

```go
func (a *App) routes() http.Handler {
	mux := http.NewServeMux()

	mux.Handle("GET /static/", http.FileServerFS(a.staticFS))

	mux.HandleFunc("GET /{$}", a.handleHome)          // {$} = exactly "/"
	mux.HandleFunc("GET /games/{id}", a.handleGameShow)
	mux.HandleFunc("POST /games", a.handleGameCreate)
	mux.HandleFunc("POST /games/{id}/moves", a.handleMoveCreate)

	return a.secureHeaders(a.logRequests(mux))
}
```

- Method in the pattern, always. Path values via `r.PathValue("id")`.
- Mutations are POST/PUT/DELETE — never GET.
- Wildcard `{$}` for exact root; avoid trailing-slash subtree matches unless serving files.

## Handlers

Handlers are methods on the app struct (dependencies via struct fields, not globals):

```go
func (a *App) handleGameShow(w http.ResponseWriter, r *http.Request) {
	game, err := a.games.Get(r.Context(), r.PathValue("id"))
	if errors.Is(err, store.ErrNotFound) {
		a.clientError(w, r, http.StatusNotFound)
		return
	}
	if err != nil {
		a.serverError(w, r, err) // logs with slog, renders 500 page
		return
	}
	a.render(w, r, http.StatusOK, "game.html", "", game) // "" = full page; a mutation handler passes its fragment block, e.g. "board"
}
```

- Early returns, no `else` ladders. One `serverError`/`clientError` pair centralizes
  error responses (see [go-errors-logging.md](go-errors-logging.md)).
- `a.render` handles the full-page vs htmx-fragment split
  (see [htmx-server-rendering.md](htmx-server-rendering.md)).

## Middleware

Plain `func(http.Handler) http.Handler`, composed innermost-first at the end of
`routes()`. Standard chain, outermost → innermost:

1. `logRequests` — slog: method, path, status, duration.
2. `recoverPanic` — turn panics into 500s, log stack.
3. `secureHeaders` — `Content-Security-Policy: default-src 'self'`,
   `X-Content-Type-Options: nosniff`, `Referrer-Policy: same-origin`,
   `X-Frame-Options: DENY`.
4. **CSRF: `http.NewCrossOriginProtection()`** (stdlib, Go 1.25+) — rejects unsafe
   cross-origin requests via the `Sec-Fetch-Site` header (falling back to
   Origin-vs-Host comparison). No tokens, no per-form wiring:

   ```go
   csrf := http.NewCrossOriginProtection()
   ```

   wrap the mux with `csrf.Handler(...)`. Only pre-2020 browsers lack these headers;
   `SameSite=Lax` session cookies are the independent second layer. Do not add a
   token library on top.
5. `sessions.LoadAndSave` (see [go-auth-sessions.md](go-auth-sessions.md)), then
   `requireAuth` on protected route groups.

```go
return a.logRequests(a.recoverPanic(a.secureHeaders(csrf.Handler(a.sessions.LoadAndSave(mux)))))
```

## Server lifecycle

```go
srv := &http.Server{
	Addr:              net.JoinHostPort("", cfg.Port),
	Handler:           app.routes(),
	ReadHeaderTimeout: 5 * time.Second,
	ReadTimeout:       10 * time.Second,
	WriteTimeout:      30 * time.Second,
	IdleTimeout:       2 * time.Minute,
	ErrorLog:          slog.NewLogLogger(logger.Handler(), slog.LevelError),
}
```

- **Timeouts are mandatory** — the zero values mean "no timeout" and that's an outage.
- **Graceful shutdown is mandatory:** listen for `os.Interrupt`/`SIGTERM` via
  `signal.NotifyContext`, then `srv.Shutdown(ctx)` with a ~10s deadline so in-flight
  requests finish.
- Request-scoped work uses `r.Context()` all the way down so client disconnects
  cancel DB queries.
