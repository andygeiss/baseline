# Pattern: Testing (Go)

**Tier 2** (shape — waived only on the record) · Last verified: 2026-09-08

**One rule here is tier 1: a test never sends a request off this machine.**

Stdlib `testing` only. No assertion libraries (no testify) — a failed comparison is
`t.Errorf("got %v, want %v", got, want)` and that's enough. No mocking frameworks —
hand-written fakes against small consumer-defined interfaces.

## What to test, in priority order

1. **Domain logic** (`internal/domain`) — exhaustively. This is pure code; there is no
   excuse for gaps. The title rules of a todo app live here and get every case.
2. **HTTP edge** (`internal/app`) — happy path + each error path per handler, via
   `net/http/httptest`.
3. **Store** — against real SQLite, not fakes: a temp file opened with the production
   pragmas and migrations (`newTestDB(t)` — see [go-sqlite.md](go-sqlite.md)). Never
   `:memory:` — it vanishes per pooled connection and diverges from WAL behavior.
   The SQL is the thing being tested.

Coverage target: meaningful, not numeric. Every bug fix adds the test that would have
caught it.

## Idioms

- **Table-driven tests with subtests**, names describing behavior:

  ```go
  func TestValidateTitle(t *testing.T) {
  	tests := []struct {
  		name  string
  		title string
  		want  error
  	}{
  		{"a plain title is fine", "Buy milk", nil},
  		{"only spaces is empty", "   ", ErrEmptyTitle},
  	}
  	for _, tt := range tests {
  		t.Run(tt.name, func(t *testing.T) {
  			…
  		})
  	}
  }
  ```

- `t.Parallel()` in every test that doesn't share state; `t.TempDir()`, `t.Setenv`,
  `t.Cleanup` over hand-rolled setup/teardown. Use `t.Context()` (Go 1.24+) for
  context plumbing in tests.
- **Handler tests** run against the app's `Routes()` (the real mux + middleware), not bare
  handler funcs — routing patterns and middleware are part of the behavior:

  ```go
  srv := httptest.NewTestServer(t, newTestApp(t).Routes()) // Go 1.27+: in-memory, closed by t.Cleanup
  c := srv.Client()                                        // the one client that reaches it
  ```

  `srv.Client()` is the network here, not a convenience: it reaches the handler at any
  host and either scheme, and `srv.URL` becomes `http://example.com` the moment anything
  uses the server. **Any other client sends the request to the real example.com** —
  `http.Get(srv.URL)` returns IANA's 200 and the test passes having asserted nothing. A
  case that needs its own jar or redirect rule builds
  `&http.Client{Transport: srv.Client().Transport}`; nothing else reaches the server.

  Assert on status code, critical headers, and *presence* of key HTML fragments
  (`strings.Contains`) — not exact HTML, which makes tests brittle.
  ⚠️ For mutation handlers, the client MUST NOT follow redirects, which `c` does by
  default: it transparently follows the mandated 303 and reports the redirected GET's
  200, indistinguishable from the direct-200 bug the PRG rule exists to prevent.
  Set `c.CheckRedirect = func(*http.Request, []*http.Request) error { return
  http.ErrUseLastResponse }` and assert the 303 + `Location` directly. `srv.Client()`
  hands back the same client every call, so that assignment is the server's: one server
  per test, never one shared by subtests that want different redirect rules.
- **htmx paths:** test each dual-mode handler twice — once plain, once with
  `HX-Request: true` — asserting full page vs fragment.
- **Concurrency:** `testing/synctest` (`synctest.Test`) for anything with timers or
  goroutine coordination — never `time.Sleep`. Inside the bubble, advance time with
  `synctest.Sleep` (Go 1.27+): it moves the clock and then waits until every other
  goroutine is durably blocked. The in-memory server above can sit inside the bubble; a
  real socket must stay outside: a goroutine blocked on it is never durably blocked, so the
  bubble's clock never advances and `synctest.Wait` never returns. A bubble is not a test:
  `t.Run`, `t.Parallel` and `t.Deadline` panic inside one, and the panic takes the rest of
  the package's tests with it. The bubble goes *inside* the subtest, and `t.Parallel()` is
  called before entering it. `make check` always runs `go test -race -shuffle=on ./...`.
- **Fuzzing** (`go test -fuzz`) for parsers and any function taking untrusted input.

## Test placement

- Same package (`package game`) for white-box unit tests.
- `package game_test` for tests that should only exercise the public API.
- No `internal/testutil` dumping ground until three packages need the same helper.
