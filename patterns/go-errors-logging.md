# Pattern: Errors & Logging (Go)

**Tier 2** (shape — waived only on the record) · Last verified: 2026-08-17

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

## Required steps and enhancement steps

An operation that calls several systems fails in parts. Decide per step which
kind it is, once, when you write it:

- **Required** — the operation is meaningless without it. Failure aborts:
  `serverError`, nothing persisted, nothing half-done.
- **Enhancement** — it improves the result and cannot replace it. Failure logs
  at `Warn`, and the operation succeeds in a degraded form.

**Order the steps so the irreplaceable result is safe before any enhancement is
attempted.** That ordering is what makes degrading possible at all; backwards,
an enhancement failure takes the real work down with it.

```go
// Required: without this the answer is lost, so nothing below it runs.
reply, err := a.store.Append(ctx, conversation, domain.RoleAgent, said)
if err != nil {
	a.serverError(w, r, err)
	return
}

// Enhancement, and it runs after the answer is safe: the worst case is a reply
// the listener reads instead of hears.
audio, mime, err := a.voice.Speak(ctx, said)
if err != nil {
	a.logger.Warn("synthesis failed", "error", err, "message_id", reply.ID)
} else if err := a.store.SaveSpeech(ctx, reply.ID, mime, audio); err != nil {
	a.logger.Warn("storing speech failed", "error", err, "message_id", reply.ID)
}
```

- **`Warn`, not `Error`** — this is the level's definition below: degraded but
  self-healing. Keep `Error` for the required steps, or the level stops meaning
  anything.
- **Say on the page what degraded**, in the reader's words, rather than leaving
  them to notice something missing. A step that fails invisibly is an outage
  nobody reports.
- **Every enhancement needs an answer to "and if it never succeeds?"** Above,
  the text is stored and can be synthesised again later. An enhancement whose
  failure loses something permanently was a required step wearing the wrong
  label.
- **One test per enhancement failure**, asserting the operation still succeeds
  when that dependency is down: the fake from
  [go-ports-adapters.md](go-ports-adapters.md) returns the error, and the
  assertion is on the response, never on the log line.

## Logging: `log/slog`, nothing else

Constructed once in `main.go`, injected as a dependency (no package-level logger):

```go
logger := slog.New(slog.NewJSONHandler(os.Stdout, &slog.HandlerOptions{
	Level: cfg.LogLevel, // parsed at boot into a slog.Level, never a string
}))
```

- **JSON handler in production** (machines read it), `slog.NewTextHandler` in dev
  (humans read it). The switch is `cfg.Env`, which `main` already parsed
  ([go-config.md](go-config.md)) — not a fresh `os.Getenv` here.
- **Always key-value attrs, never Sprintf into the message:**
  `logger.Info("game created", "game_id", g.ID, "player", p.Name)` — the message is a
  constant, the variables are attrs.
- **Levels:** `Debug` = development noise; `Info` = state changes worth an audit trail;
  `Warn` = degraded but self-healing; `Error` = a human should eventually look.
  If everything is Info, nothing is.
- **Request logging** in middleware only — handlers don't log successes.
- **Never log:** passwords, tokens, session IDs, full request bodies, or anything
  covered by "would I paste this in a public gist?"
- Log to stdout only (server processes; a CLI logs to stderr because its stdout
  carries data — see [go-cli.md](go-cli.md)). Whatever runs the binary owns
  shipping and rotation — the app does not open log files, and does not rotate
  anything ([operations/web-application.md](../operations/web-application.md)).
