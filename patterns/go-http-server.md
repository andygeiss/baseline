# Pattern: Go HTTP Server

**Last verified: 2026-08-14**

Stdlib only. `net/http.ServeMux` (Go 1.22+ pattern routing) covers everything a
router package used to do.

## Routing

All routes registered in one file (`internal/app/routes.go`) so the URL surface is
readable at a glance:

```go
// Routes is exported: cmd/server/main.go sets it as the http.Server handler.
func (a *App) Routes() http.Handler {
	mux := http.NewServeMux()

	mux.HandleFunc("GET /{$}", a.handleHome) // {$} = exactly "/"
	mux.HandleFunc("GET /games/{id}", a.handleGameShow)
	mux.HandleFunc("POST /games", a.handleGameCreate)
	mux.HandleFunc("POST /games/{id}/moves", a.handleMoveCreate)

	// a.staticFS = fs.Sub(embedded, "web") so URL /static/css/… resolves to
	// web/static/css/… (see go-project-layout.md); cacheImmutable: go-performance.md.
	// Static sits outside the chain — see the routing notes below.
	root := http.NewServeMux()
	root.Handle("GET /static/", cacheImmutable(http.FileServerFS(a.staticFS)))
	root.Handle("/", a.middleware(mux)) // the one canonical chain — see Middleware below

	return root
}
```

- Method in the pattern, always. Path values via `r.PathValue("id")`.
- Mutations are POST — never GET, and not PUT/DELETE either: plain forms can't send
  those, so they'd break the no-JS fallback. Name the action in the path
  (`"POST /items/{id}/delete"`) — see [stack/htmx.md](../stack/htmx.md).
- Wildcard `{$}` for exact root; avoid trailing-slash subtree matches unless serving files.
- **`/static/` sits outside the middleware chain.** `sessions.LoadAndSave` would
  query the session store on every asset request and `Add` `Vary: Cookie`, which
  makes `immutable`-cached assets ([go-performance.md](go-performance.md))
  unusable each time the session cookie changes (login, logout). CSRF and the
  body cap have nothing to check on a bodiless GET. The trade — no request-log
  line, no security headers on assets — is fine: `FileServerFS` sets the
  `Content-Type` from the extension via Go's mime table, and CSP/HSTS do their
  work on the HTML documents that reference the assets. That table is small,
  so two extensions register themselves at boot: `.webmanifest`
  ([pwa.md](pwa.md)) and `.woff2` ([css-typography.md](css-typography.md)).

## Handlers

Handlers are methods on the app struct (dependencies via struct fields, not globals):

```go
func (a *App) handleGameShow(w http.ResponseWriter, r *http.Request) {
	game, err := a.games.Get(r.Context(), r.PathValue("id"))
	if errors.Is(err, domain.ErrNotFound) {
		a.clientError(w, r, http.StatusNotFound)
		return
	}
	if err != nil {
		a.serverError(w, r, err) // logs with slog, renders 500 page
		return
	}
	a.render(w, r, http.StatusOK, "game.html", "", game)
	// "" = full page. Mutation handlers: fragment (200) only when
	// HX-Request && !HX-Boosted, otherwise 303 (PRG) — see htmx-server-rendering.md.
}
```

- Early returns, no `else` ladders. One `serverError`/`clientError` pair centralizes
  error responses (see [go-errors-logging.md](go-errors-logging.md)).
- `a.render` handles the full-page vs htmx-fragment split
  (see [htmx-server-rendering.md](htmx-server-rendering.md)).

## Middleware

Plain `func(http.Handler) http.Handler`. One method owns the composition — there is
exactly one place the chain exists:

```go
func (a *App) middleware(mux http.Handler) http.Handler {
	csrf := http.NewCrossOriginProtection()
	h := http.MaxBytesHandler(mux, 1<<20)
	h = a.sessions.LoadAndSave(h)
	h = csrf.Handler(h)
	return a.logRequests(a.recoverPanic(a.secureHeaders(h)))
}
```

Outermost → innermost:

1. `logRequests` — slog: method, path, status, duration.
2. `recoverPanic` — turn panics into 500s, log stack.
3. `secureHeaders` — CSP, HSTS, nosniff, and Referrer-Policy. The policy string
   and the middleware live in [security-headers.md](security-headers.md), which
   owns every security header the app sends.
4. **CSRF: `http.NewCrossOriginProtection()`** (stdlib, Go 1.25+) — rejects unsafe
   cross-origin requests via the `Sec-Fetch-Site` header (falling back to
   Origin-vs-Host comparison). No tokens, no per-form wiring. Only pre-2020 browsers
   lack these headers; `SameSite=Lax` session cookies are the independent second
   layer. Do not add a token library on top.
5. `sessions.LoadAndSave` (see [go-auth-sessions.md](go-auth-sessions.md)), then
   `requireAuth` on protected route groups only. Static assets never reach it —
   see Routing.
6. `http.MaxBytesHandler(mux, 1<<20)` — innermost: request bodies capped at 1 MiB so
   `ParseForm` on a hostile body can't exhaust memory. An outer cap **cannot be
   raised downstream** — the body is already wrapped in the smaller
   `MaxBytesReader` before the handler runs. When a route genuinely accepts
   uploads, choose the limit at the cap site instead of the blanket wrapper:
   replace `http.MaxBytesHandler` with a few lines that pick the limit by route
   (`limit := int64(1<<20); if r.URL.Path == "/upload" { limit = 32<<20 };
   r.Body = http.MaxBytesReader(w, r.Body, limit)`) before delegating to the mux.

## Server lifecycle

```go
srv := &http.Server{
	Addr:              net.JoinHostPort(cfg.Host, cfg.Port), // HOST defaults to 127.0.0.1 — Caddy is the public listener (see operations)
	Handler:           a.Routes(),
	ReadHeaderTimeout: 5 * time.Second,
	ReadTimeout:       10 * time.Second,
	WriteTimeout:      30 * time.Second,
	IdleTimeout:       2 * time.Minute,
	ErrorLog:          slog.NewLogLogger(logger.Handler(), slog.LevelError),
}
```

- **Timeouts are mandatory** — the zero values mean "no timeout" and that's an outage.
- **Graceful shutdown is mandatory:** listen for `os.Interrupt`/`SIGTERM` via
  `signal.NotifyContext`, then call `srv.Shutdown` with a **fresh** ~10 s deadline:
  `context.WithTimeout(context.Background(), 10*time.Second)`. The signal context
  only *triggers* shutdown — it is already canceled at that moment, so passing it
  (or a context derived from it) makes `Shutdown` return immediately and kill
  in-flight requests instead of waiting for them.
- Request-scoped work uses `r.Context()` all the way down so client disconnects
  cancel DB queries.

## Background work

Anything periodic (session janitor, `VACUUM INTO` backups) runs under the same signal
context as the server, via `errgroup` — this is the answer to "how does this stop?"
from [stack/go.md](../stack/go.md). No bare `go func()` in `main`:

```go
ctx, stop := signal.NotifyContext(context.Background(), os.Interrupt, syscall.SIGTERM)
defer stop()

g, ctx := errgroup.WithContext(ctx)
g.Go(func() error { return serve(ctx, srv) })     // ListenAndServe; Shutdown when ctx is done
g.Go(func() error { return janitor(ctx, store) }) // ticker loop; returns when ctx is done
err := g.Wait()
```

Every worker takes `ctx`, selects on `ctx.Done()` in its loop, and returns — process
exit is gated on `g.Wait()`, so nothing is killed mid-write.

## The ops listener

`/healthz` and `/debug/pprof` run on a second, localhost-only server — never on
the app listener, so they are never proxied and being localhost-only *is* the
access control ([operations/web-application.md](../operations/web-application.md)
owns the topology). The handler lives in `internal/app/ops.go`:

```go
// OpsHandler serves /healthz and /debug/pprof on the localhost ops listener.
// The health ping uses the read pool: a ping queued behind the write pool's
// single connection times out during any long write — a healthy app flapping 503.
func OpsHandler(readDB *sql.DB, version string) http.Handler {
	mux := http.NewServeMux()
	mux.HandleFunc("GET /healthz", func(w http.ResponseWriter, r *http.Request) {
		ctx, cancel := context.WithTimeout(r.Context(), time.Second)
		defer cancel()
		status, state := http.StatusOK, "ok"
		if err := readDB.PingContext(ctx); err != nil {
			status, state = http.StatusServiceUnavailable, "unavailable"
		}
		w.Header().Set("Content-Type", "application/json")
		w.WriteHeader(status)
		fmt.Fprintf(w, `{"status":%q,"version":%q}`, state, version)
	})
	mux.HandleFunc("/debug/pprof/", pprof.Index) // also serves the named runtime profiles (heap, goroutine, …)
	mux.HandleFunc("/debug/pprof/cmdline", pprof.Cmdline)
	mux.HandleFunc("/debug/pprof/profile", pprof.Profile)
	mux.HandleFunc("/debug/pprof/symbol", pprof.Symbol)
	mux.HandleFunc("/debug/pprof/trace", pprof.Trace)
	return mux
}
```

`main.go` wires it as a second `http.Server` under the same `errgroup` as the
app server:

```go
ops := &http.Server{
	Addr:              "127.0.0.1:6060", // fixed, not a flag: never public, never proxied
	Handler:           app.OpsHandler(readDB, version),
	ReadHeaderTimeout: 5 * time.Second,
	ReadTimeout:       10 * time.Second,
	WriteTimeout:      30 * time.Second,
	IdleTimeout:       2 * time.Minute,
	ErrorLog:          slog.NewLogLogger(logger.Handler(), slog.LevelError),
	// WriteTimeout does not cap long profiles: profile?seconds=30 writes nothing
	// until profiling ends, but net/http/pprof extends its own write deadline to
	// WriteTimeout + seconds on every seconds-based handler.
}
g.Go(func() error { return serve(ctx, ops) })
```

- The pprof handlers come from `net/http/pprof` registered **explicitly** —
  the blank `_ "net/http/pprof"` import registers on `http.DefaultServeMux`,
  which this pattern never serves. `pprof.Index` dispatches the named runtime
  profiles under `/debug/pprof/` itself; `Cmdline`, `Profile`, `Symbol`, and
  `Trace` are the only handlers that need routes of their own. Their patterns
  break the app mux's routing rules on purpose: method-less because `Symbol`
  answers both GET and POST, and a subtree match because that is how `Index`
  dispatches.
- The ops mux takes **none** of the app middleware: no request log (a health
  poll every few seconds is journal noise), no sessions, no CSRF, no body cap.
- `version` is read once at boot via `debug.ReadBuildInfo` — the same string
  the asset cache-buster uses ([go-performance.md](go-performance.md)).
