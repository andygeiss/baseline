# Checklist: Library — Definition of Done

**Last verified: 2026-08-15**

Walk this before declaring any milestone complete. Every unchecked box is either
fixed or waived on the record — the waiver format lives in [README.md](../README.md)
under *Which rules can be waived*. The compatibility promises are not waivable: after
v1.0.0 they are a promise to every consumer, not a preference.

This checklist stands on its own. Every box — or the bold bullet it sits under — names
the document behind it, so you can walk it without holding the whole corpus in your
head.

**One box, one check.** A box that needs two answers is two boxes: a box holding six
conditions gets ticked while three of them fail. Where several checks share a scope,
the scope is a bold bullet and the checks sit under it. Keep it that way when you add
here.

## Justification

- [ ] A second project actually imports (or is about to import) this — extracted, not invented
- [ ] `LICENSE` file present

## Stack compliance

- [ ] `go.mod` says `go 1.26`, matching [VERSIONS.md](../VERSIONS.md)
- [ ] Zero third-party dependencies, or each one justified in the README
- [ ] No `main` package
- [ ] No embedded assets
- [ ] No logging — errors are returned, not printed
- [ ] Implementation detail is inaccessible to consumers: unexported in a single-package library, under `internal/` when multi-package
- [ ] The exported surface is the minimum needed

## API contract

- [ ] Accept interfaces, return structs
- [ ] `context.Context` is the first parameter on anything that blocks
- [ ] Zero values usable, or a single `New(...)` with a config struct
- [ ] No functional options without justification
- [ ] No panics across the API boundary except documented programmer error
- [ ] Branchable failures exported as sentinel errors
- [ ] No `init()` side effects
- [ ] No package-level mutable state
- [ ] No unowned goroutines — lifecycles have `ctx` or `Close`
- [ ] If it speaks HTTP: the client is a parameter, not built inside — the consumer owns timeouts and retries ([patterns/go-http-client.md](../patterns/go-http-client.md))

## Compatibility

- [ ] v0 until proven by ≥2 consumers
- [ ] v1.0.0 tagged deliberately
- [ ] Since v1: no exported symbol renamed, removed, or behavior-changed (additive = minor, fixes = patch)
- [ ] No `replace` directives on main
- [ ] The module path would be `/v2` for any post-v1 break — and that was fought hard

## Documentation

- [ ] Package doc comment shows the primary entry point; reads well on pkg.go.dev
- [ ] Every exported symbol documented
- [ ] Runnable `Example` functions for the main entry points (they compile in CI)
- **README**:
  - [ ] Install line
  - [ ] 30-second example
  - [ ] Link to this baseline
  - [ ] Any waived rule recorded in the format [README.md](../README.md) *Which rules can be waived* defines
- **Prose passes [STYLE.md](../STYLE.md)**:
  - [ ] Doc comments follow godoc
  - [ ] Other comments say *why*, not what
  - [ ] The README leads with the point
  - [ ] Commits are semantic (`type(scope): subject`)
  - [ ] Any LLM prompts follow [patterns/go-llm-adapter.md](../patterns/go-llm-adapter.md) *Writing the prompt*

## Tests

- [ ] CI workflow from [operations/ci.md](../operations/ci.md) in place and green
- [ ] `Makefile` from [stack/makefile.md](../stack/makefile.md) at the repo root, with its rule-5 library adjustments
- [ ] `make check` is green
- [ ] `make check` is gate-for-gate identical to ci.yml
- [ ] `go test -race -shuffle=on ./...` passes
- [ ] Exported API tested from `package foo_test` (consumer's view)
- [ ] Edge cases and error paths covered exhaustively
- [ ] Fuzz test + seed corpus for any parser of untrusted input
