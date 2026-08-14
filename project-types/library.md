# Project Type: Library

**Last verified: 2026-08-14**

A reusable Go module imported by other projects. Libraries are **extracted, not
invented**: code starts in an application's `internal/` and becomes a library only
when a second project actually needs it (rule 2 of
[patterns/go-project-layout.md](../patterns/go-project-layout.md)). A library
nobody imports twice is an application's internal package with extra ceremony.

## Mandated stack

| Concern | Rule |
|---|---|
| Language | Go stdlib. MUST. Same conventions as everywhere: [stack/go.md](../stack/go.md). |
| Third-party dependencies | **Zero.** MUST — a library taxes every consumer with its dependency tree. Any exception is justified in the README and weighed against not extracting the library at all. |
| Binaries / assets | MUST NOT ship a `main` package, embedded assets, or CLI. A module is a library or a program, not both. |
| Logging | MUST NOT log. Return errors; the consumer decides what is log-worthy. |
| License | MUST carry a `LICENSE` file (MIT unless there is a reason otherwise) — an unlicensed public repo is legally unusable. |
| Local commands | MUST use the `Makefile` from [stack/makefile.md](../stack/makefile.md), with its rule-5 library adjustments. |

Versions: see [VERSIONS.md](../VERSIONS.md). `go.mod` follows the same module
hygiene as applications ([stack/go.md](../stack/go.md)).

## Required reading (in order)

1. [stack/go.md](../stack/go.md) — language conventions and toolchain
2. [patterns/go-library.md](../patterns/go-library.md) — layout, doc comments, Example functions, fuzz corpus, release mechanics
3. [patterns/go-errors-logging.md](../patterns/go-errors-logging.md) — error wrapping and sentinel errors (the logging half does not apply: libraries return, consumers log)
4. [patterns/go-testing.md](../patterns/go-testing.md) — testing strategy
5. [operations/ci.md](../operations/ci.md) — the CI workflow, used verbatim
6. [stack/makefile.md](../stack/makefile.md) — the Makefile every project copies (`make check` = CI locally)
7. [patterns/go-performance.md](../patterns/go-performance.md) — when something is slow (and not before)
8. [STYLE.md](../STYLE.md) — how everything for humans is written (docs, comments, prompts)

## API design rules

- **Small surface.** Export the minimum that solves the consumer's problem; grow
  on demand. Every exported symbol is a compatibility promise. In a
  single-package library, implementation detail is simply unexported; once the
  module grows more packages, detail packages live in `internal/` —
  unexported-by-directory beats unexported-by-convention.
- **Accept interfaces, return structs.** Take `io.Reader`/`fs.FS`/small
  consumer-shaped interfaces instead of concrete types and file paths; return
  concrete types the caller can grow with.
- **`context.Context` first parameter** on anything that does I/O or can block.
- **Take the HTTP client, never build one.** A library that constructs its own
  `*http.Client` has chosen a timeout and retry policy for every consumer, with
  no way to override it. Accept `*http.Client` or a one-method interface —
  [patterns/go-http-client.md](../patterns/go-http-client.md).
- **Usable zero values.** `var b thing.Builder` should work; where construction
  genuinely needs input, one `New(...)` with a config struct. Functional options
  MUST NOT be the default — they earn their complexity only on APIs with many
  independent optional knobs.
- **Errors, never panics, across the API boundary.** Panic only for programmer
  error (nil where documented non-nil), and document it. Export sentinel errors
  (`var ErrNotFound = errors.New(...)`) for conditions callers must branch on.
- **No hidden machinery:** no `init()` side effects, no package-level mutable
  state, no background goroutines the caller didn't start — anything with a
  lifecycle takes a `ctx` or provides a `Close`.

## Compatibility discipline

- **Start at v0** and stay there until the API has survived contact with at least
  two real consumers. v0 is the design phase; break freely, note it in the release.
- **Tagging v1.0.0 is the promise:** from then on, nothing exported is renamed,
  removed, or changed in behavior that consumers can observe. Additions are minor
  releases; fixes are patches.
- **A breaking change after v1 requires a `/v2` module path** — which splits every
  consumer and doubles maintenance. Treat needing v2 as a design failure to learn
  from; exhaust additive options (new function alongside old, deprecation notes)
  first.

## Documentation

- Package doc comment (`// Package x ...`) that states what the package does and
  shows the primary entry point — write it for the pkg.go.dev rendering.
- Every exported symbol has a doc comment.
- Runnable `Example` functions (`func ExampleParse()`) for the main entry points —
  they render on pkg.go.dev *and* compile in CI, so the docs can't rot.
- README: install line, the 30-second example, link to this baseline, any waived
  rules.

## Testing

- The exported API is tested from an external test package (`package foo_test`) —
  the tests then consume the library exactly as users do and prove the API is
  usable without private access.
- White-box tests (`package foo`) only for internals genuinely unreachable from
  the public surface.
- Parsers and anything consuming untrusted bytes get a fuzz test (`go test -fuzz`
  locally; the seed corpus runs in normal CI).

## Definition of done

Walk [checklists/library.md](../checklists/library.md) before calling any
milestone complete.

## Reference implementation

None yet. The first library extracted under this document SHOULD be promoted to
reference status.
