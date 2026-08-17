# Pattern: Go Background Work

**Tier 2** (shape — waived only on the record) · Last verified: 2026-08-17

Anything the process does on a schedule rather than in response to a request: a session
janitor, a `VACUUM INTO` backup, a cache refresh. It runs under the same signal context as
the server, via `errgroup` — this is the answer to "how does this stop?" from
[stack/go.md](../stack/go.md). **No bare `go func()` in `main`.**

```go
ctx, stop := signal.NotifyContext(context.Background(), os.Interrupt, syscall.SIGTERM)
defer stop()

g, ctx := errgroup.WithContext(ctx)
g.Go(func() error { return serve(ctx, srv) })  // ListenAndServe; Shutdown when ctx is done
g.Go(func() error { return janitor(ctx, store, logger, 6*time.Hour) }) // ticker loop; returns when ctx is done
err := g.Wait()
```

Every worker takes `ctx`, selects on `ctx.Done()` in its loop, and returns — process exit
is gated on `g.Wait()`, so nothing is killed mid-write. The server itself is one of these
goroutines; [go-http-server.md](go-http-server.md) owns its lifecycle and timeouts.

## Do the work once before the first tick

```go
func janitor(ctx context.Context, store *store.Store, logger *slog.Logger, every time.Duration) error {
	purge := func() {
		n, err := store.PurgeExpired(ctx)
		switch {
		case errors.Is(err, context.Canceled):
			// Shutting down over a purge is not a fault. Logging it as one puts
			// an ERROR line in every orderly stop that lands on this.
		case err != nil:
			logger.Error("purge", "error", err)
		case n > 0:
			logger.Info("purged", "rows", n)
		}
	}

	purge() // before the loop — see below

	ticker := time.NewTicker(every)
	defer ticker.Stop()
	for {
		select {
		case <-ctx.Done():
			return nil
		case <-ticker.C:
			purge()
		}
	}
}
```

`time.NewTicker` does not fire at zero, so **a process restarted more often than the
interval never reaches a tick at all** — every binary under development, and every
service that deploys more often than it cleans up. The loop looks like it is running,
`g.Wait()` holds it open, and the table it was meant to trim grows forever. One call
before the loop is the whole fix.

**`context.Canceled` at shutdown is not an error.** Shutdown cancels the context
mid-purge, and without that case every orderly stop logs an error nobody should go
looking at.

