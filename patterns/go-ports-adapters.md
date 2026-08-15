# Pattern: Ports & Adapters (Go)

**Last verified: 2026-08-15**

The one decision this document owns: **how your code meets somebody else's
system.** A *port* is the small interface your code needs. An *adapter* is the
package that speaks the outside world's language and satisfies it. The payoff
is the reason to bother: **the feature is finished and tested before the
external API is integrated at all.**

[stack/go.md](../stack/go.md) already says interfaces are defined by the
consumer, and [go-project-layout.md](go-project-layout.md) rule 3 already fixes
the dependency direction (`app → domain ← store`). This document is what those
two rules look like when the thing on the other side is not yours: what a port
may say, what the adapter must translate, and how the stand-in stays honest.

Three packages share the work, and which file holds what is the whole shape —
an extension of the tree in [go-project-layout.md](go-project-layout.md), not a
second one:

```
project/
├── cmd/server/main.go        ← the only file that names both sides (wiring)
└── internal/
    ├── app/
    │   ├── reminders.go      ← the port, beside the feature that needs it
    │   └── reminders_test.go ← the fake, and the feature's tests
    ├── domain/
    │   └── task.go           ← the types and sentinel errors both sides speak
    └── email/
        ├── client.go         ← the adapter: the only package that knows HTTP
        └── client_test.go    ← the status-translation table, over httptest
```

`internal/email` imports `internal/domain` and nothing else of yours. It never
imports `internal/app`, and `go list -deps ./internal/email` is how you check.

## Fakes, not mocks

A **fake** is a working implementation you wrote by hand. A **mock** records
calls and asserts them. Use fakes.

The difference decides how the tests age. A mock test asserts that `Notify` was
called twice in a given order — so it fails on every refactor that keeps the
behavior, and passes on behavior that is wrong. A fake test asserts that two
reminders reached the right two addresses, which is what the code actually
promised. Mock frameworks (gomock, mockery, testify's `mock`) are not on the
approved list in [stack/go.md](../stack/go.md) either, and a generated mock is
more code than the ten lines it replaces.

## The port belongs to the consumer

```go
// internal/app/reminders.go

// Notifier delivers one reminder to one address.
//
// Notify returns domain.ErrUnknownRecipient when the address does not exist —
// the one failure a caller branches on. Every other error is treated as
// transient. app declares this interface because app is what needs it; the
// adapter satisfies it without importing this package.
type Notifier interface {
	Notify(ctx context.Context, to, subject, body string) error
}
```

1. **The consumer declares it, in domain words.** The port lives in the package
   that calls it, never in the adapter and never in a `ports/` package of its
   own. If the interface names HTTP, JSON, SQL, or the vendor, it is not a port
   — it is their API with an interface taped on, and it buys nothing the day
   the vendor changes.
2. **One port per dependency you actually swap.** Swapping means a fake in
   tests, or a second real implementation. "Might need it later" is not
   swapping. An interface per struct, added so everything is mockable, is the
   Java-style abstraction layer [stack/go.md](../stack/go.md) bans — and it is
   the most common way this pattern turns into ceremony.
3. **One to three methods**, per the interface rule in
   [stack/go.md](../stack/go.md). An eight-method port is the vendor's SDK
   wearing a costume: nobody can write a fake for it, so nobody does.

## The adapter translates, and that is its whole job

```go
// internal/email/client.go — the only package that knows a reminder leaves
// the process as an HTTP call. Client construction, timeouts, and retries
// follow go-http-client.md; none of it appears in the port.

func (c *Client) Notify(ctx context.Context, to, subject, body string) error {
	// ... build the request with the caller's ctx, send it, drain and close ...
	switch resp.StatusCode {
	case http.StatusOK, http.StatusAccepted:
		return nil
	case http.StatusUnprocessableEntity:
		return fmt.Errorf("email: notify %s: %w", to, domain.ErrUnknownRecipient)
	default:
		return fmt.Errorf("email: notify %s: %s", to, resp.Status)
	}
}
```

4. **Translate in both directions.** Domain types go in and come out, and the
   vendor's failures become the domain sentinels
   ([go-errors-logging.md](go-errors-logging.md)) the port documents. That
   translation is what makes a fake possible at all: anything that leaks — an
   `*http.Response`, `sql.ErrNoRows`, a vendor error type — is a detail the
   fake would have to imitate, and imitating it is exactly where fakes drift
   from the truth. [go-sqlite.md](go-sqlite.md) already applies the same rule
   at the store boundary.
5. **Every knob stays in the adapter.** Timeouts, retries, base URL, auth,
   pagination, rate limits. A port with an options struct has stopped being
   what the consumer needs and started being what the vendor offers.

## The fake comes first

This is the answer to "how do I build against an API I have not integrated
yet": write the port, write the fake, finish the feature. The adapter is a leaf
you add last.

```go
// internal/app/reminders_test.go

// fakeNotifier answers per address, so one test drives both branches of the
// port's contract. Hand-written and ten lines: no mock framework earns its
// keep against that.
type fakeNotifier struct {
	fail map[string]error // address → what Notify returns
	sent []string
}

func (f *fakeNotifier) Notify(_ context.Context, to, _, _ string) error {
	if err := f.fail[to]; err != nil {
		return err
	}
	f.sent = append(f.sent, to)
	return nil
}
```

6. **Hand-written, and it lives with the consumer's tests.** The consumer owns
   the port, so it owns the stand-in. Two shapes cover everything: an in-memory
   fake with real behavior for a stateful port, and the map or func field above
   when a test needs to drive one specific failure. A fake shared by three
   packages may move to a small package of its own — not before, per
   [go-testing.md](go-testing.md).
7. **Finish the feature against the fake.** Every branch the port can produce
   gets a test while the vendor account does not exist yet. When the adapter
   arrives, nothing above it changes — and if something does have to change,
   the port was shaped by the vendor rather than by the need.

Add a mutex to the fake only when the code under test calls the port from more
than one goroutine. CI runs `-race` ([operations/ci.md](../operations/ci.md)),
so the suite says which case you are in.

## Keeping the fake honest

A fake that agrees with nothing is a second bug waiting for production. One
mechanism keeps it tied to reality, and at one adapter it is enough:

8. **The port's doc comment names every error a caller branches on.** The
   adapter's test proves it produces them, and the fake returns the same ones.
   The adapter's test is a table over the statuses the vendor documents, driven
   by `httptest.Server` ([go-http-client.md](go-http-client.md)) — never the
   live API, which is slow, flaky, and somebody's bill:

   ```go
   // errTransient is a table marker, not a value the adapter returns: it means
   // "must fail, and must not carry a domain sentinel".
   want error // nil = success; a sentinel = must wrap it; errTransient = see above

   {"accepted is success", http.StatusAccepted, nil},
   {"422 is an unknown recipient", http.StatusUnprocessableEntity, domain.ErrUnknownRecipient},
   {"503 fails without a domain sentinel", http.StatusServiceUnavailable, errTransient},
   ```

   The marker earns its line. Without it the success row and the transient row
   both want `nil`, meaning two different things — and the case that matters
   most, a transient failure quietly wrapping the sentinel and making the app
   skip a task forever, is the one a bare `nil` stops checking.

   A shared contract suite — one set of cases run against *every*
   implementation — waits until there is a **second real adapter**. Then it
   earns its package, and the stdlib shows the shape: `testing/fstest.TestFS`
   is a contract test for `fs.FS`. Writing one for a single adapter plus its
   fake is machinery guarding a seam that has only one side.

## Wiring: `main` is the assertion

9. **No `var _ app.Notifier = (*email.Client)(nil)`.** The wiring already
   checks it, and it is the only place that names both sides:

   ```go
   // The key is a secret, so it arrives as a credential file (go-config.md).
   n := email.NewClient(cfg.EmailURL, cfg.EmailKey)
   sent, err := app.RemindDue(ctx, n, due)
   ```

   Let the adapter's signature drift and both packages still compile on their
   own — `cmd/server` is what fails, and it says exactly what broke:

   ```
   cmd/server/main.go:12:45: cannot use n (variable of type *email.Client) as
   app.Notifier value in argument to app.RemindDue: *email.Client does not
   implement app.Notifier (wrong type for method Notify)
           have Notify(context.Context, string, string) error
           want Notify(context.Context, string, string, string) error
   ```

   That is the assertion line, written by the compiler, in the place the
   mistake actually matters.

## What not to fake

10. **Never fake what you own and can run for real.** SQLite runs for real in a
    temp file ([go-sqlite.md](go-sqlite.md), [go-testing.md](go-testing.md));
    time gets `testing/synctest`; files get `t.TempDir()`; your own HTTP
    handlers get `httptest`. A fake is for a system across a network that you
    do not control and cannot run in CI. Faking your own store replaces the SQL
    — the thing most likely to be wrong — with a Go map that always agrees with
    you.

## Anti-patterns

- ❌ Asserting call counts or call order instead of the outcome. `RemindDue` is
  right when two reminders reached the right two addresses, not when `Notify`
  "was called twice".
- ❌ A `ports/`, `interfaces/`, or `contracts/` package. It puts the interface
  next to the producer, which is rule 1 upside down, and every consumer then
  depends on every port.
- ❌ An interface per struct, so that everything is mockable. Ports exist for
  dependencies you swap; the rest is a struct.
- ❌ `func NewClient(...) Notifier` — accept interfaces, return structs
  ([stack/go.md](../stack/go.md)). Returning the interface hides the adapter's
  own methods and forces every consumer through one shape.
- ❌ A fake that is smarter than the real thing — sorting what the API returns
  unsorted, succeeding where the API rejects. The tests pass and production
  does not.
- ❌ The live API in CI, or a recorded-cassette library replaying it. The
  status table above is the whole need.
- ❌ Generated mocks (gomock, mockery). Not on the approved list, and the
  generated file is longer than the fake it replaces.
