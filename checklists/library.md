# Library — Triggers and Definition of Done

**Last verified: 2026-08-15**

One topic per section: **the moment it fires, the document that rules it, and what done
looks like.** Read a section before you write the thing it covers; walk its boxes before
you call the work complete. A section with no box is the honest answer where the document
rules something no milestone can verify. Paths are from the repository root.

Every unchecked box is either fixed or waived on the record — the waiver format lives in
`README.md` under *Which rules can be waived*. The compatibility promises are not
waivable: after v1.0.0 they are a promise to every consumer, not a preference.

## Every library

No trigger: these fire for every library. Layout, doc comments, and release mechanics are
ruled by `patterns/go-library.md`; the port rules by `patterns/go-ports-adapters.md`. Both
are required reading.

### Justification

- [ ] A second project actually imports (or is about to import) this — extracted, not invented
- [ ] `LICENSE` file present

### Stack compliance

- [ ] `go.mod` says `go 1.26`, matching `VERSIONS.md`
- [ ] Zero third-party dependencies, or each one justified in the README
- [ ] No `main` package
- [ ] No embedded assets
- [ ] No logging — errors are returned, not printed
- [ ] Implementation detail is inaccessible to consumers: unexported in a single-package library, under `internal/` when multi-package
- [ ] The exported surface is the minimum needed

### API contract

- [ ] Accept interfaces, return structs
- [ ] `context.Context` is the first parameter on anything that blocks
- [ ] Zero values usable, or a single `New(...)` with a config struct
- [ ] No functional options without justification
- [ ] No panics across the API boundary except documented programmer error
- [ ] No `init()` side effects
- [ ] No package-level mutable state
- [ ] No unowned goroutines — lifecycles have `ctx` or `Close`

### Compatibility

- [ ] v0 until proven by ≥2 consumers
- [ ] v1.0.0 tagged deliberately
- [ ] Since v1: no exported symbol renamed, removed, or behavior-changed (additive = minor, fixes = patch)
- [ ] No `replace` directives on main
- [ ] The module path would be `/v2` for any post-v1 break — and that was fought hard

### Documentation

- [ ] Package doc comment shows the primary entry point; reads well on pkg.go.dev
- [ ] Every exported symbol documented
- [ ] Runnable `Example` functions for the main entry points (they compile in CI)
- **README:**
  - [ ] Install line
  - [ ] 30-second example
  - [ ] Link to this baseline
  - [ ] Any waived rule recorded in the format `README.md` *Which rules can be waived* defines

## Returning an error across the API boundary

`patterns/go-errors-logging.md` — wrapping and sentinel errors. The logging half does not
apply: libraries return, consumers log.

- [ ] Branchable failures exported as sentinel errors

## Writing a comment, a doc comment, a README, or a commit message

`STYLE.md` — point first, short sentences, plain words: the bar for everything a human
reads.

- [ ] Doc comments follow godoc
- [ ] Other comments say *why*, not what
- [ ] The README leads with the point
- [ ] Commits are semantic (`type(scope): subject`)
- [ ] Any LLM prompts follow `patterns/llm-prompting.md`

## Writing a test

`patterns/go-testing.md` — plus the external-test-package and fuzz rules in
`project-types/library.md`.

- [ ] `go test -race -shuffle=on ./...` passes
- [ ] Exported API tested from `package foo_test` (consumer's view)
- [ ] Edge cases and error paths covered exhaustively
- [ ] Fuzz test + seed corpus for any parser of untrusted input

## Setting up the repo's commands or CI

`stack/makefile.md`, then `operations/ci.md` — used verbatim; `make check` is CI locally.

- [ ] CI workflow in place and green
- [ ] `Makefile` at the repo root, with its rule-5 library adjustments
- [ ] `make check` is green
- [ ] `make check` is gate-for-gate identical to ci.yml

## Accepting an HTTP client from a consumer

`patterns/go-http-client.md` — what the consumer owns, and why the library never builds
one.

- [ ] If it speaks HTTP: the client is a parameter, not built inside — the consumer owns timeouts and retries

## Fixing something measurably slow

`patterns/go-performance.md` — and not before. No box: the rule is *don't*, and a rule
nobody can be in the middle of violating has nothing to check at the end.
