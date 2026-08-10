# Pattern: Errors & Logging (Go)

**Last verified: 2026-08-10**

## Errors

1. **Wrap with context at every boundary crossing:**
   `fmt.Errorf("loading game %s: %w", id, err)` — lowercase, no "failed to" prefix
   stutter (the caller adds its own context; chains read as a story).
2. **Sentinel errors** for conditions callers branch on live in `domain`:

   ```go
   var ErrNotFound = errors.New("not found") // domain/errors.go
   ```

   Both the consumer-defined interface in `app` and its `store` implementation
   already import `domain`, so the sentinel crosses the boundary without bending the
   dependency direction (see [go-project-layout.md](go-project-layout.md)).
   Check with `errors.Is`, never `==` or string matching. Custom error *types* +
   `errors.As` only when the caller needs structured data (e.g. validation field errors).
3. **Handle once.** An error is either handled (logged, converted to an HTTP response)
   or returned — never both. Logging *and* returning double-reports.
4. In HTTP handlers, the split is exactly two functions:
   - `clientError(w, r, status)` — expected conditions (404, 400). Not logged above
     debug level. Form-validation failures are **not** `clientError`: they re-render
     the form fragment with errors and values at 422
     (see [htmx-server-rendering.md](htmx-server-rendering.md)).
   - `serverError(w, r, err)` — unexpected. Logs at error level with the full chain,
     renders a generic 500 page. **The internal error text never reaches the browser.**
5. `panic` only for programmer errors (impossible states); `recoverPanic` middleware
   is the safety net, not a control-flow mechanism.

## Logging: `log/slog`, nothing else

Constructed once in `main.go`, injected as a dependency (no package-level logger):

```go
logger := slog.New(slog.NewJSONHandler(os.Stdout, &slog.HandlerOptions{
	Level: cfg.LogLevel, // slog.LevelDebug in dev, Info in prod
}))
```

- **JSON handler in production** (machines read it), `slog.NewTextHandler` in dev
  (humans read it). Switch on an env var.
- **Always key-value attrs, never Sprintf into the message:**
  `logger.Info("game created", "game_id", g.ID, "player", p.Name)` — the message is a
  constant, the variables are attrs.
- **Levels:** `Debug` = development noise; `Info` = state changes worth an audit trail;
  `Warn` = degraded but self-healing; `Error` = a human should eventually look.
  If everything is Info, nothing is.
- **Request logging** in middleware only — handlers don't log successes.
- **Never log:** passwords, tokens, session IDs, full request bodies, or anything
  covered by "would I paste this in a public gist?"
- Log to stdout only. The platform (systemd, container runtime) owns shipping and
  rotation — the app does not open log files.
