# Stack: Go

**Last verified: 2026-08-10 · Pinned: Go 1.26.5** (see [VERSIONS.md](../VERSIONS.md))

## Toolchain

- Format with `gofmt` (via `goimports`). Non-negotiable; no custom style.
- Vet on every CI run: `go vet ./...`.
- Run the modernizers periodically: `go fix ./...` — since Go 1.26 this applies
  ~two dozen analyzers that rewrite code to current idioms. Trust it.
- Lint with `staticcheck` (the only third-party lint tool allowed).
- Race detector in CI: `go test -race ./...`.

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
| `math/rand/v2` | `math/rand` |
| `crypto/rand`, `crypto/hpke`, `crypto/mlkem` | rolling your own crypto — never |

## Approved third-party dependencies

Everything else requires an explicit, written justification in the project README.

| Dependency | Purpose |
|---|---|
| `modernc.org/sqlite` | SQLite driver, pure Go (CGO-free static binaries) |
| `github.com/jackc/pgx/v5` | Postgres, when SQLite is outgrown |
| `golang.org/x/crypto` | argon2/bcrypt for password hashing |
| `golang.org/x/sync` | errgroup |
| `honnef.co/go/tools` (staticcheck) | lint, dev-only |

Explicitly banned: ORMs (GORM etc. — write SQL), web frameworks, dependency-injection
frameworks, viper/cobra for web apps (use `flag` + env vars).

## Module hygiene

- Module path: `github.com/andygeiss/<project>`.
- `go.mod` declares `go 1.26`. Commit `go.sum`. Run `go mod tidy` before every commit.
- No `replace` directives on main branch.
