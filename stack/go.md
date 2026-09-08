# Stack: Go

**Tier 2** (shape — waived only on the record) · Last verified: 2026-09-08 · Pinned:
Go 1.27.1 ([VERSIONS.md](../VERSIONS.md))

The Go pin itself is tier 1: its note in [VERSIONS.md](../VERSIONS.md) names a security
fix.

## Toolchain

- Format with `gofmt` (via `goimports`). Non-negotiable; no custom style.
- Vet on every run of the gates: `go vet ./...`.
- Rewrite to current idiom with `go fix ./...` (`make fmt`); `make check` fails while
  a rewrite is pending, and the diff is yours to read before you commit it.
- Lint with `staticcheck` (the only third-party lint tool allowed).
- Scan for known vulnerabilities: `govulncheck ./...` — on every `make check`, and
  once per 90-day cycle even when nothing changed
  (see [operations/ci.md](../operations/ci.md)).
- Race detector on every test run: `go test -race -shuffle=on ./...`.
- The gates above are one command, `make check`, and `make ci` runs it against the
  commit (see [stack/makefile.md](makefile.md) — the Makefile every project copies).

## Language conventions

- **Standard library first.** Reach for a dependency only when stdlib genuinely can't
  (see approved list below).
- **Errors:** wrap with `fmt.Errorf("doing x: %w", err)`; never discard with `_` unless
  commented why. Details in [patterns/go-errors-logging.md](../patterns/go-errors-logging.md).
- **Context:** first parameter of any function that does I/O: `func (s *Store) Get(ctx context.Context, id string)`.
- **Generics:** use for data structures and genuinely type-parametric helpers.
  MUST NOT be used to build Java-style abstraction layers. When in doubt, write the
  concrete version. **A generic method is not a port method:** a method may declare its
  own type parameters (Go 1.27) but an interface method may not, so a type parameter on
  any method a port names is a dead end. Put it on a function that takes the port.
- **Interfaces are defined by the consumer,** not the producer. Keep them small
  (1–3 methods). Accept interfaces, return structs.
- **Zero values matter.** Design types so their zero value is usable (`sync.Mutex`,
  `bytes.Buffer` style).
- **A struct literal key may name a promoted field** (Go 1.27), and `go fix` rewrites the
  nested form to it. Never then give the outer struct a field of that name: every
  flattened literal moves to it silently, leaves the embedded field zero, and compiles.
- **Concurrency:** don't start goroutines you don't own the lifecycle of. Every
  `go func()` needs a documented answer to "how does this stop?" Prefer
  channels/`errgroup` for coordination, mutexes for state.
- **Iterators:** use range-over-func (`iter.Seq[T]`, Go 1.23+) for new sequence APIs
  instead of returning slices when the sequence is large or lazy. Every `yield` call is
  `if !yield(v) { return }` — ignoring the result panics on the caller's `break`, and no
  gate catches it.
- Use the `min`/`max`/`clear` builtins, and `new(expr)` where it removes a helper —
  `go fix` inlines the callers and leaves the helper marked `//go:fix inline`; removing
  it is yours.

## Modern stdlib choices (do not use the old way)

| Use | Instead of |
|---|---|
| `log/slog` (structured) | `log`, third-party loggers |
| `net/http.ServeMux` with method+wildcard patterns (`"GET /items/{id}"`) | gorilla/mux, chi, etc. |
| `errors.Is` / `errors.AsType` / `errors.Join` | string matching, `== err`, `errors.As` — unless the target is an interface without `Error()`, which `AsType` cannot take |
| `slices` and `maps` packages | hand-rolled loops for sort/contains/clone |
| `sync.WaitGroup.Go` | `wg.Add(1)` + `go func()` + `defer wg.Done()` — `go fix` rewrites it, so `make check` goes red on the old form |
| `embed.FS` | file paths resolved at runtime |
| `testing/synctest` for concurrent code | `time.Sleep` in tests |
| `http.NewCrossOriginProtection` for CSRF (Go 1.25+) | token libraries, hand-rolled double-submit cookies |
| an injected `*http.Client` with a `Timeout` ([patterns/go-http-client.md](../patterns/go-http-client.md)) | `http.DefaultClient`, `http.Get`, `http.Post` — none of them has a timeout |
| `cmp.Or` for "value, or this default" | a hand-rolled `envOr`/`firstNonEmpty` helper |
| `math/rand/v2` | `math/rand` |
| `uuid` (Go 1.27+) | `github.com/google/uuid` |
| `encoding/json/v2` (Go 1.27+) | `encoding/json` — v2's engine under v1's loose defaults |
| `crypto/rand`, `crypto/hpke`, `crypto/mlkem` | rolling your own crypto — never |
| `crypto/rand.Text` for a token or an id | `rand.Read` plus an encoder — and an error branch that cannot fire |
| `os.Root` for a directory a name goes into (Go 1.24+) | `filepath.Join` plus a prefix check |

New code imports `encoding/json/v2`. An existing `encoding/json` call site moves the
first time a change touches it — unless its JSON is a contract a tag promises: a CLI's
`-json` output at any tag, a library's wire format from v1. There the move waits for the
next major and is one: a name now matches case-sensitively, a duplicate name or invalid
UTF-8 is an error, and a nil slice or map marshals as `[]` or `{}`, so both what goes
out and what is accepted change. A web application's `/api` has no semver contract; its
move ships with the next deploy, and those stricter defaults are the reason to make it.
Every call site on v2, new or moved:

- `json.Marshal` hands back the bytes it got through *and* a non-nil error, where v1
  handed back `nil`. Marshal into a variable, check, then write: a `MarshalWrite` aimed at
  a `ResponseWriter` commits a 200 and half a body before it can fail.
- Never let `errors.ErrUnsupported` into an error a `MarshalJSONTo` or `UnmarshalJSONFrom`
  returns. v2 reads it as "use the default representation", so a marshaler written to
  redact a secret fails open and silent, with a nil error.
- `omitempty` omits only an empty JSON value (`null`, `""`, `[]`, `{}`); a zero value that
  encodes as anything else — a number, a bool, a `time.Time` — takes `omitzero`.
- Map keys marshal in Go's map order, which is random; pass `json.Deterministic(true)`
  where the bytes must be stable.
- A test of JSON output compares decoded values; it compares bytes only where
  `Deterministic(true)` made them the contract.
- There is no `MarshalIndent`. Indentation is `jsontext.WithIndent("  ")`, which does
  not sort, so a pretty-printed file takes `Deterministic(true)` beside it or it churns
  into a new key order on every write.
- There is no `UseNumber` either, and its absence is silent: a number decoded into an
  `any` lands in a `float64`, which corrupts a 64-bit id on the way back out. Keeping the
  text takes a typed field: `json.Number` from v1, or `jsontext.Value`.
- `json.MarshalWrite` writes no trailing newline, unlike v1's `Encoder.Encode`; the
  loop that emits one object per line writes the `\n` itself.
- `json.UnmarshalRead` rejects anything after the value but whitespace: write no
  trailing-data check.
- Pass `json.RejectUnknownMembers(true)` where both sides of the JSON ship in one
  repository.
- Never pass v2 an option `encoding/json` exports, and never v2's own
  `MatchCaseInsensitiveNames`: a call site that needs one is a call site to fix.
- v2 output never lands inside HTML — v2 does not escape `<`, `>`, or `&`. It goes
  out as a JSON body with its own content type, or to stdout.

## Approved third-party dependencies

Everything else requires an explicit, written justification in the project README.

| Dependency | Purpose |
|---|---|
| `modernc.org/sqlite` | SQLite driver, pure Go (CGO-free static binaries) |
| `github.com/jackc/pgx/v5` | Postgres, when SQLite is outgrown |
| `github.com/alexedwards/scs/v2` | server-side sessions — with a hand-written `CtxStore` against the app's two DB pools, **not** the bundled `sqlite3store` (single-pool API). See [patterns/go-auth-sessions.md](../patterns/go-auth-sessions.md) |
| `golang.org/x/crypto` | argon2/bcrypt for password hashing — stdlib has pbkdf2, hkdf and sha3, and no password hash |
| `golang.org/x/sync` | errgroup — `WaitGroup.Go` returns no error and cancels no sibling; shutdown needs both |
| `golang.org/x/time` | rate limiting (auth endpoints) |
| `golang.org/x/tools` (goimports) | import management, dev-only — `gofmt` never adds or removes an import (run via `go run`, not a module dependency) |
| `honnef.co/go/tools` (staticcheck) | lint, dev-only (run via `go run`, not a module dependency) |
| `golang.org/x/vuln` (govulncheck) | CVE scanning, dev-only (run via `go run`) |

Explicitly banned: ORMs (GORM etc. — write SQL), web frameworks, dependency-injection
frameworks, viper/cobra everywhere — CLIs included (stdlib `flag` + env vars, see
[patterns/go-cli.md](../patterns/go-cli.md)).

## Module hygiene

- Module path: `github.com/andygeiss/<project>`.
- `go.mod` declares `go 1.27` — `go mod init` writes the running patch, so correct it.
  Commit `go.sum`. Run `go mod tidy` before every commit.
- No `replace` directives on main branch.
