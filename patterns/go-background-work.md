# Pattern: Go Background Work

**Tier 2** (shape — waived only on the record) · Last verified: 2026-08-17

Anything the process runs outside a request. Two shapes, and both owe the same answer to
"how does this stop?" from [stack/go.md](../stack/go.md): **work on a schedule**, which
lives as long as the process, and **work a request starts and does not wait for**, which
lives until it is done. **No bare `go func()` anywhere.**

## Work on a schedule

A session janitor, a `VACUUM INTO` backup, a cache refresh. It runs under the same signal
context as the server, via `errgroup`.

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

### Do the work once before the first tick

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

## Work a request starts and does not wait for

Transcoding an upload, building a long report, a model writing a reply a sentence at a
time. The answer is not ready when the response has to go out, so the request answers at
once with something the client can ask again about, and the work carries on without it.

**It is not request-scoped work, and that is the whole difference.**
[go-http-server.md](go-http-server.md) says request-scoped work takes `r.Context()` all
the way down, so a client that disconnects cancels the query. That is right for a handler
answering what it was asked. This work outlives the asking, so it keeps the request's
values and drops its cancellation:

```go
// The work outlives the request that asked for it: someone who closes the tab
// still gets the result. WithoutCancel keeps the values the request carried and
// drops the cancellation it would otherwise impose, and the budget below is
// what ends a wedged dependency instead.
job := a.jobs.start() // the registry further down
ctx, cancel := context.WithTimeout(context.WithoutCancel(r.Context()), jobBudget)
a.running.Add(1) // a sync.WaitGroup on the app
go func() {
	defer a.running.Done()
	defer cancel()
	a.run(ctx, job)
}()
```

**`srv.Shutdown` does not wait for this, and that is the trap.** Shutdown waits for
in-flight *requests*, and this goroutine is not one — the request it came from returned
seconds ago. Without a second wait the process exits mid-write, the work is lost, and
nothing logs a fault, because from the server's side the shutdown was clean. So the app
counts its own and `main` waits for both:

```go
err = g.Wait() // the listeners are down
a.Wait()       // now the work they started; Wait wraps the WaitGroup
return err     // the deferred db.Close() runs after this line, not before
```

**The budget is the only clock on it.** The ladder in
[go-http-client.md](go-http-client.md) is built on a handler's budget sitting under
`WriteTimeout`; this work has no socket above it, so it leaves the ladder and its budget
stands alone. A project that widened `WriteTimeout` to cover the work while it was still
synchronous MUST narrow that waiver when it detaches: only a path that still waits — a
plain form post, which has nowhere to put a poller — needs the room.

**Hold it in a registry, keyed by an id the client can ask about.**
[htmx-live-updates.md](htmx-live-updates.md) is how it asks. Two rules keep the registry
from becoming a leak:

1. **Drop finished entries when the next one starts,** not on a ticker. They only ever
   pile up while more work is being started, so the next start is exactly when there is
   something to clear — and nothing has to be scheduled, stopped, or waited for.
2. **Keep a finished entry for a few minutes.** The request asking for its last result is
   already on its way when the work ends.

**A reader takes a snapshot, never the live state.** The goroutine writes while handlers
read, so every field goes through a mutex, and one read copies everything that response
will decide from. Hand out an append-only slice capped to its own length — `s[:len(s):len(s)]` — so a
later append cannot write into the array the reader is still holding.

**Tests wait on the counter, never on the clock.** `Wait()` is exported for shutdown, and
a test gets it for free; a test that sleeps instead is a test that fails on a loaded
machine.
