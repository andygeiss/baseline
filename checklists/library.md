# Checklist: Library — Definition of Done

**Last verified: 2026-08-10**

Walk this before declaring any milestone complete. Every unchecked box is either
fixed or explicitly waived by the user in writing.

## Justification

- [ ] A second project actually imports (or is about to import) this — extracted, not invented
- [ ] `LICENSE` file present

## Stack compliance

- [ ] Versions match [VERSIONS.md](../VERSIONS.md) (`go.mod` says `go 1.26`)
- [ ] Zero third-party dependencies, or each one justified in the README
- [ ] No `main` package, no embedded assets, no logging — errors are returned, not printed
- [ ] Implementation detail is inaccessible to consumers (unexported in a single-package library; under `internal/` when multi-package); the exported surface is the minimum needed

## API contract

- [ ] Accept interfaces / return structs; `context.Context` first param on anything that blocks
- [ ] Zero values usable, or a single `New(...)` with a config struct (no functional options without justification)
- [ ] No panics across the API boundary except documented programmer error; branchable failures exported as sentinel errors
- [ ] No `init()` side effects, package-level mutable state, or unowned goroutines; lifecycles have `ctx` or `Close`

## Compatibility

- [ ] v0 until proven by ≥2 consumers; v1.0.0 tagged deliberately
- [ ] Since v1: no exported symbol renamed/removed/behavior-changed (additive = minor, fixes = patch)
- [ ] No `replace` directives on main; module path would be `/v2` for any post-v1 break (and that was fought hard)

## Documentation

- [ ] Package doc comment shows the primary entry point; reads well on pkg.go.dev
- [ ] Every exported symbol documented
- [ ] Runnable `Example` functions for the main entry points (they compile in CI)
- [ ] README: install line, 30-second example, link to this baseline, waived rules recorded

## Tests

- [ ] CI workflow from [operations/ci.md](../operations/ci.md) in place and green
- [ ] `go test -race ./...` passes; exported API tested from `package foo_test` (consumer's view)
- [ ] Edge cases and error paths covered exhaustively; fuzz test + seed corpus for any parser of untrusted input
