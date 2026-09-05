# Pattern: Go HTTP Server

**Tier 2** (shape — waived only on the record) · Last verified: 2026-09-05

**Three rules here are tier 1 and never waived:** the `http.CrossOriginProtection` wrap,
the 1 MiB request-body cap, and the ops listener staying localhost-only and never
proxied. Widening `WriteTimeout` is the tier-2 waiver this document spells out below.

Stdlib only. `net/http.ServeMux` (Go 1.22+ pattern routing) covers everything a router
package used to do.

## Routing

All routes registered in one file (`internal/app/routes.go`) so the URL surface is
readable at a glance. What guards each one is tier 1 and lives in
[go-authorization.md](go-authorization.md):

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
- **`/static/` sits outside the middleware chain.** `sessions.LoadAndSave` would query
  the session store on every asset request and add `Vary: Cookie`, breaking the
  `immutable` cache ([go-performance.md](go-performance.md)) on every login and logout;
  CSRF and the body cap have nothing to check on a bodiless GET. The trade — no request
  log, no security headers on assets — is covered in
  [security-headers.md](security-headers.md). `FileServerFS` sets `Content-Type` from
  Go's mime table, which is small enough that two extensions register themselves at boot:
  `.webmanifest` ([pwa.md](pwa.md)) and `.woff2`
  ([css-typography.md](css-typography.md)).

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
		a.serverError(w, r, err)
		return
	}
	a.render(w, r, http.StatusOK, "game.html", "", game) // "" = full page
}
```

Early returns, no `else` ladders. One `serverError`/`clientError` pair centralizes error
responses ([go-errors-logging.md](go-errors-logging.md)), and `a.render` handles the
full-page vs fragment split ([htmx-server-rendering.md](htmx-server-rendering.md)).

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
3. `secureHeaders` — CSP, HSTS, nosniff, Referrer-Policy. The policy string and the
   middleware live in [security-headers.md](security-headers.md).
4. **CSRF: `http.NewCrossOriginProtection()`** (stdlib, Go 1.25+) — rejects unsafe
   cross-origin requests via `Sec-Fetch-Site`, falling back to Origin-vs-Host. No tokens,
   no per-form wiring. Only pre-2020 browsers lack these headers. Do not add a token
   library on top.
5. `sessions.LoadAndSave` ([go-auth-sessions.md](go-auth-sessions.md)), then
   `requireAuth` on the private routes — never one route at a time, which fails open
   ([go-authorization.md](go-authorization.md)). Static assets never reach it.
6. `http.MaxBytesHandler(mux, 1<<20)` — innermost: bodies capped at 1 MiB so `ParseForm`
   on a hostile body can't exhaust memory. An outer cap **cannot be raised downstream**,
   because the body is already wrapped in the smaller `MaxBytesReader` before the handler
   runs, so a route that genuinely accepts uploads picks its limit at the cap site
   instead. That route and everything after it is
   [go-file-uploads.md](go-file-uploads.md), and it is tier 1.

## Server lifecycle

```go
srv := &http.Server{
	Addr:              net.JoinHostPort(cfg.Host, cfg.Port), // HOST defaults to 127.0.0.1 — the proxy is the public listener (see operations)
	Handler:           a.Routes(),
	ReadHeaderTimeout: 5 * time.Second,
	ReadTimeout:       10 * time.Second,
	WriteTimeout:      30 * time.Second,
	IdleTimeout:       2 * time.Minute,
	ErrorLog:          slog.NewLogLogger(logger.Handler(), slog.LevelError),
}
```

- **Timeouts are mandatory** — the zero values mean "no timeout" and that's an outage.
- **Header limits stay at their defaults:** `MaxHeaderBytes` (1 MiB) and
  `MaxHeaderValueCount` (500, Go 1.27+) — no browser comes near either.
- **Graceful shutdown is mandatory:** listen for `os.Interrupt`/`SIGTERM` via
  `signal.NotifyContext`, then call `srv.Shutdown` with a **fresh** ~10 s deadline:
  `context.WithTimeout(context.Background(), 10*time.Second)`. The signal context only
  *triggers* shutdown — it is already canceled at that moment, so passing it (or anything
  derived from it) makes `Shutdown` return immediately and kill in-flight requests.
- Request-scoped work uses `r.Context()` all the way down, so client disconnects cancel
  DB queries. Work that outlives the request is the exception, and
  [go-background-work.md](go-background-work.md) rules it.

**The four timeouts above are only half of the ladder.** A handler that calls someone
else's system adds two more on the way out, and their order decides which one fires. The
full ladder, its two failure modes, and the waiver for widening `WriteTimeout` past 30 s
are in [go-http-client.md](go-http-client.md) *The timeout ladder* — read it before
writing a handler that waits on another system.

## Background work

The server is one goroutine under an `errgroup` tied to the signal context, and anything
periodic — a session janitor, a `VACUUM INTO` backup — is another. Work a request starts
and does not wait for is the second shape, and it needs a cancel and a wait of its own
after `g.Wait()`. Both shapes, the run-before-the-first-tick rule, and treating
`context.Canceled` as an orderly stop are in
[go-background-work.md](go-background-work.md) — read it when the process grows its first
job outside a request.

## The ops listener

`/healthz` and `/debug/pprof` run on a second, localhost-only server — never on the app
listener, so they are never proxied and being localhost-only *is* the access control
([operations/web-application.md](../operations/web-application.md) owns that contract).
The handler lives in `internal/app/ops.go`:

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

`main.go` wires it as a second `http.Server` under the same `errgroup` as the app server:

```go
ops := &http.Server{
	Addr:    "127.0.0.1:6060", // fixed, not a flag: never public, never proxied
	Handler: app.OpsHandler(readDB, version),
	// The same four timeouts and ErrorLog as the app server. They do not cap a
	// long profile: profile?seconds=30 writes nothing until profiling ends, but
	// net/http/pprof extends its own write deadline to WriteTimeout + seconds on
	// every seconds-based handler.
}
g.Go(func() error { return serve(ctx, ops) })
```

- The pprof handlers are registered **explicitly** — the blank `_ "net/http/pprof"`
  import registers on `http.DefaultServeMux`, which this pattern never serves.
  `pprof.Index` dispatches the named runtime profiles itself; `Cmdline`, `Profile`,
  `Symbol`, and `Trace` are the only ones needing their own routes. Their patterns break
  the app mux's routing rules on purpose: method-less because `Symbol` answers GET and
  POST, and a subtree match because that is how `Index` dispatches.
- The ops mux takes **none** of the app middleware: no request log (a health poll every
  few seconds is log noise), no sessions, no CSRF, no body cap.
- `version` is read once at boot via `debug.ReadBuildInfo` — the same string the asset
  cache-buster uses ([go-performance.md](go-performance.md)).
