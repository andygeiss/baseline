# Pattern: Testing (Go)

**Last verified: 2026-08-10**

Stdlib `testing` only. No assertion libraries (no testify) — a failed comparison is
`t.Errorf("got %v, want %v", got, want)` and that's enough. No mocking frameworks —
hand-written fakes against small consumer-defined interfaces.

## What to test, in priority order

1. **Domain logic** (`internal/domain`) — exhaustively. This is pure code; there is no
   excuse for gaps. Win detection in a tic-tac-toe game lives here and gets every case.
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
  func TestBoard_Winner(t *testing.T) {
  	tests := []struct {
  		name  string
  		moves []Move
  		want  Player
  	}{
  		{"row of three wins", …, PlayerX},
  		{"full board no winner is draw", …, PlayerNone},
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
- **Handler tests** run against `app.Routes()` (the real mux + middleware), not bare
  handler funcs — routing patterns and middleware are part of the behavior:

  ```go
  srv := httptest.NewServer(newTestApp(t).Routes())
  ```

  Assert on status code, critical headers, and *presence* of key HTML fragments
  (`strings.Contains`) — not exact HTML, which makes tests brittle.
  ⚠️ For mutation handlers, the client MUST NOT follow redirects — the default
  client transparently follows the mandated 303 and reports the redirected GET's
  200, indistinguishable from the direct-200 bug the PRG rule exists to prevent.
  Use `&http.Client{CheckRedirect: func(*http.Request, []*http.Request) error {
  return http.ErrUseLastResponse }}` and assert the 303 + `Location` directly.
- **htmx paths:** test each dual-mode handler twice — once plain, once with
  `HX-Request: true` — asserting full page vs fragment.
- **Concurrency:** `testing/synctest` (`synctest.Test`) for anything with timers or
  goroutine coordination — never `time.Sleep`. CI always runs `go test -race ./...`.
- **Fuzzing** (`go test -fuzz`) for parsers and any function taking untrusted input.

## Test placement

- Same package (`package game`) for white-box unit tests.
- `package game_test` for tests that should only exercise the public API.
- No `internal/testutil` dumping ground until three packages need the same helper.
