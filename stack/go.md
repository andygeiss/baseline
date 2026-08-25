# Stack: Go

**Tier 2** (shape — waived only on the record) · Last verified: 2026-08-14 · Pinned:
Go 1.26.7 ([VERSIONS.md](../VERSIONS.md))

The Go pin itself is tier 1: its note in [VERSIONS.md](../VERSIONS.md) names a security
fix.

## Toolchain

- Format with `gofmt` (via `goimports`). Non-negotiable; no custom style.
- Vet on every run of the gates: `go vet ./...`.
- Run the modernizers periodically: `go fix ./...` — since Go 1.26 this applies
  ~two dozen analyzers that rewrite code to current idioms. Trust it.
- Lint with `staticcheck` (the only third-party lint tool allowed).
- Scan for known vulnerabilities: `govulncheck ./...` — on every `make check`, and
  once per 90-day cycle even when nothing changed
  (see [operations/ci.md](../operations/ci.md)).
- Race detector on every test run: `go test -race -shuffle=on ./...`.
- All the gates above are one command, `make check`, and `make ci` runs it against
  the commit (see [stack/makefile.md](makefile.md) — the Makefile every project
  copies).

## Language conventions

- **Standard library first.** Reach for a dependency only when stdlib genuinely can't
  (see approved list below).
- **Errors:** wrap with `fmt.Errorf("doing x: %w", err)`; never discard with `_` unless
  commented why. Details in [patterns/go-errors-logging.md](../patterns/go-errors-logging.md).
- **Context:** first parameter of any function that does I/O: `func (s *Store) Get(ctx context.Context, id string)`.
- **Generics:** use for data structures and genuinely type-parametric helpers.
  MUST NOT be used to build Java-style abstraction layers. When in doubt, write the
  concrete version.
- **Interfaces are defined by the consumer,** not the producer. Keep them small
  (1–3 methods). Accept interfaces, return structs.
- **Zero values matter.** Design types so their zero value is usable (`sync.Mutex`,
  `bytes.Buffer` style).
- **Concurrency:** don't start goroutines you don't own the lifecycle of. Every
  `go func()` needs a documented answer to "how does this stop?" Prefer
  channels/`errgroup` for coordination, mutexes for state.
- **Iterators:** use range-over-func (`iter.Seq[T]`, Go 1.23+) for new sequence APIs
  instead of returning slices when the sequence is large or lazy.
- Use `any`, not `interface{}`. Use `min`/`max`/`clear` builtins. Since Go 1.26,
  `new(expr)` with an initial value is allowed — use it where it removes a helper.

## Modern stdlib choices (do not use the old way)

| Use | Instead of |
|---|---|
| `log/slog` (structured) | `log`, third-party loggers |
| `net/http.ServeMux` with method+wildcard patterns (`"GET /items/{id}"`) | gorilla/mux, chi, etc. |
| `errors.Is` / `errors.As` / `errors.Join` | string matching, `== err` |
| `slices` and `maps` packages | hand-rolled loops for sort/contains/clone |
| `embed.FS` | file paths resolved at runtime |
| `testing/synctest` for concurrent code | `time.Sleep` in tests |
| `http.NewCrossOriginProtection` for CSRF (Go 1.25+) | token libraries, hand-rolled double-submit cookies |
| an injected `*http.Client` with a `Timeout` ([patterns/go-http-client.md](../patterns/go-http-client.md)) | `http.DefaultClient`, `http.Get`, `http.Post` — none of them has a timeout |
| `cmp.Or` for "value, or this default" | a hand-rolled `envOr`/`firstNonEmpty` helper |
| `math/rand/v2` | `math/rand` |
| `crypto/rand`, `crypto/hpke`, `crypto/mlkem` | rolling your own crypto — never |

## Approved third-party dependencies

Everything else requires an explicit, written justification in the project README.

| Dependency | Purpose |
|---|---|
| `modernc.org/sqlite` | SQLite driver, pure Go (CGO-free static binaries) |
| `github.com/jackc/pgx/v5` | Postgres, when SQLite is outgrown |
| `github.com/alexedwards/scs/v2` | server-side sessions — with a hand-written `CtxStore` against the app's two DB pools, **not** the bundled `sqlite3store` (single-pool API). See [patterns/go-auth-sessions.md](../patterns/go-auth-sessions.md) |
| `golang.org/x/crypto` | argon2/bcrypt for password hashing |
| `golang.org/x/sync` | errgroup |
| `golang.org/x/time` | rate limiting (auth endpoints) |
| `golang.org/x/tools` (goimports) | formatting, dev-only (run via `go run`, not a module dependency) |
| `honnef.co/go/tools` (staticcheck) | lint, dev-only (run via `go run`, not a module dependency) |
| `golang.org/x/vuln` (govulncheck) | CVE scanning, dev-only (run via `go run`) |

Explicitly banned: ORMs (GORM etc. — write SQL), web frameworks, dependency-injection
frameworks, viper/cobra everywhere — CLIs included (stdlib `flag` + env vars, see
[patterns/go-cli.md](../patterns/go-cli.md)).

## Module hygiene

- Module path: `github.com/andygeiss/<project>`.
- `go.mod` declares `go 1.26`. Commit `go.sum`. Run `go mod tidy` before every commit.
- No `replace` directives on main branch.
