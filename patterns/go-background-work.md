# Pattern: Go Background Work

**Tier 2** (shape — waived only on the record) · Last verified: 2026-08-27

Anything the process runs outside a request. Two shapes, and both owe the same answer to
"how does this stop?" from [stack/go.md](../stack/go.md): **work on a schedule**, which
lives as long as the process, and **work a request starts and does not wait for**, which
lives until it is done or the process stops, whichever comes first. **No bare `go func()`
in a server** — not in `main`, and not in a handler.

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

A model writing a reply a sentence at a time, a thumbnail for the picture just uploaded, a
summary of what somebody just saved. The answer is not ready when the response has to go
out, so the request answers at once with something the client can ask again about, and the
work carries on without it. **Losing it has to be survivable** — *Work that must not be
lost* below says why.

**It is not request-scoped work, and that is the whole difference.**
[go-http-server.md](go-http-server.md) says request-scoped work takes `r.Context()` all
the way down, so a client that disconnects cancels the query. That is right for a handler
answering what it was asked. This work outlives the asking, so it drops the request's
cancellation and keeps its values — but it does not outlive the process:

```go
// The work outlives the request that asked for it: someone who closes the tab
// still gets the result. WithoutCancel keeps the values the request carried and
// drops the cancellation it would otherwise impose. a.stopping puts the
// process back in charge, so a shutdown ends this too, and jobBudget is only
// what ends a wedged dependency.
job := a.jobs.start() // the registry further down
ctx, cancel := context.WithTimeout(context.WithoutCancel(r.Context()), jobBudget)
release := context.AfterFunc(a.stopping, cancel) // shutdown cancels it too
// a.running is a sync.WaitGroup on the app.
a.running.Go(func() {
	defer release() // or the AfterFunc registration outlives the job
	defer cancel()
	a.run(ctx, job)
})
```

**`srv.Shutdown` does not wait for this, and that is the trap.** Shutdown waits for
in-flight *requests*, and this goroutine is not one — the request it came from returned
seconds ago. Without a second wait the process exits mid-write, the work is lost, and
nothing logs a fault, because from the server's side the shutdown was clean. So the app
counts its own, and the wait comes after the cancel:

```go
g, ctx := errgroup.WithContext(ctx)
a.stopping = ctx // errgroup cancels it as Wait returns, whatever ends the process
// … the listeners and the ticker go under g, as above …
err := g.Wait() // the listeners are down, and ctx with them
a.Wait()        // the work they started, now cancelled, returns like any other worker
return err      // the deferred db.Close() runs after this line, not before
```

**Cancel first, then wait.** `a.stopping` is the errgroup's context, which `errgroup`
cancels as `Wait` returns — so by the time `a.Wait()` runs, every job has been told to
stop. A bare wait would instead hold the process for `jobBudget`, and `return err`, with
the deferred `db.Close()` behind it, would never run at all.

**The stop grace bounds that wait.** `srv.Shutdown` takes a fresh ~10 s deadline
([go-http-server.md](go-http-server.md)), and it runs inside the container's
`stop_grace_period` — 15 s in `baseline-ops/templates/compose.yaml`. A slow shutdown can
leave this wait as little as five seconds before SIGKILL takes whatever is still running.

**Work that must not be lost is a table, not a registry.** Everything here lives in
memory, so that SIGKILL, a crash, or a panic loses every job in flight. This shape is for
work you can throw away — a reply the reader can ask for again, a thumbnail the next
request regenerates. Work somebody paid for, or work that leaves half a file behind,
belongs in a queue on disk written in the transaction that caused it.
[go-email.md](go-email.md)'s outbox is that shape, and its rule that a second kind of work
is a second table says to build your own rather than borrow that one.

**The budget is the backstop, not the clock.** The ladder in
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
will decide from. Hand out an append-only slice capped to its own length —
`s[:len(s):len(s)]` — so a later append cannot write into the array the reader is still
holding.

**Tests wait on the counter, never on the clock.** `Wait()` is exported for shutdown, and
a test gets it for free; a test that sleeps instead is a test that fails on a loaded
machine.

**Waiting is the easy half. Proving the counter counts takes `testing/synctest`.** Swap
`running.Go` for a bare `go` and every ordinary test stays green, because an uncounted
goroutine still finishes first on an idle machine. In a bubble
([go-testing.md](go-testing.md)), `synctest.Wait` returns only once every other goroutine
is durably blocked — so a `Wait` that has already returned is visible to a plain `select`
with a `default`, and no clock or deadlock is involved. Two things have to stay outside
the bubble: a listener, because a goroutine blocked on a socket is never durably blocked,
and anything holding a ticker that never exits, because the bubble waits for it.

**A test outside the process has no counter to reach.** A shell driving the real binary
retries until the work shows up — bounded, so work that never comes fails the gate rather
than hanging it.
