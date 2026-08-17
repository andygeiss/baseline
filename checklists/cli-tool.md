# Checklist: CLI Tool — Definition of Done

**Last verified: 2026-08-17**

Walk this before declaring any milestone complete. Every unchecked box is either
fixed or waived on the record — the waiver format lives in [README.md](../README.md)
under *Which rules can be waived*. The safety tier is not waivable: partial work staying
safe, a destructive action needing an explicit flag, and every box about how a secret is
handled — a secret never arrives as a flag *value*, and `.env` is gitignored. Tier 1 is
decided by what a rule protects, not by which section it landed in.

This checklist stands on its own. Every box — or the bold bullet it sits under — names
the document behind it, so you can walk it without holding the whole corpus in your
head.

**One box, one check.** A box that needs two answers is two boxes: a box holding six
conditions gets ticked while three of them fail. Where several checks share a scope,
the scope is a bold bullet and the checks sit under it. Keep it that way when you add
here.

## Stack compliance

- [ ] `go.mod` says `go 1.26`, matching [VERSIONS.md](../VERSIONS.md)
- [ ] No dependencies outside the approved list in [stack/go.md](../stack/go.md), or each extra one is justified in the README
- [ ] Flags via stdlib `flag` only — no cobra, viper, or urfave
- [ ] Config precedence is flags > env > defaults per [patterns/go-config.md](../patterns/go-config.md)
- [ ] Single static binary builds: `CGO_ENABLED=0 go build .` (or `./cmd/...` in a multi-binary module)
- [ ] `main` package at module root — `cmd/<name>/` only when the module ships several binaries
- [ ] Logic in `internal/`
- [ ] The binary's name is free: `command -v <name>` finds nothing on a stock macOS and Linux box — a collision means the tool that runs is not the tool that was installed ([project-types/cli-tool.md](../project-types/cli-tool.md))

## Code quality

- [ ] CI workflow from [operations/ci.md](../operations/ci.md) is in place and green
      (covers gofmt, vet, staticcheck, **govulncheck**, tidy, race tests, static build)
- [ ] `Makefile` from [stack/makefile.md](../stack/makefile.md) at the repo root, with the rule-5 adjustments for its layout
- [ ] `make check` is green
- [ ] `make check` is gate-for-gate identical to ci.yml
- [ ] `run(ctx, args, stdout, stderr)` pattern per [patterns/go-cli.md](../patterns/go-cli.md)
- [ ] `os.Exit` in `main` only
- [ ] Errors wrapped with `%w`
- [ ] Every failure surfaces as `tool: <cause>` on stderr, exit 1
- [ ] Config parsed and validated before any work starts
- [ ] A bad value exits 2 with one line, never a half-done run
- **If the repo has a `.env`** — [stack/makefile.md](../stack/makefile.md) rule 6:
  - [ ] It is gitignored
  - [ ] Only `make run` reads it
  - [ ] Production takes its secrets from credential files instead
- **Any outbound HTTP** — [patterns/go-http-client.md](../patterns/go-http-client.md):
  - [ ] Uses an injected client with a timeout, never `http.DefaultClient`
  - [ ] Checks `resp.StatusCode`
  - [ ] Caps the body it reads
- **Any adapter for someone else's system** — [patterns/go-ports-adapters.md](../patterns/go-ports-adapters.md):
  - [ ] It sits in its own package
  - [ ] It defines no port of its own
  - [ ] It exposes domain methods instead of `*http.Response`
  - [ ] It imports `internal/domain` and nothing else of yours — `go list -deps` proves it
- **Any secret (API token, key)** — [patterns/go-config.md](../patterns/go-config.md) *A CLI holds its secret differently*:
  - [ ] It is read from a file named by `-token-file`/`$MYTOOL_TOKEN_FILE`
  - [ ] `$MYTOOL_TOKEN` is documented as the leaky fallback
  - [ ] It is **never** taken from a flag value
- **Any AI capability** — [patterns/go-llm-adapter.md](../patterns/go-llm-adapter.md):
  - [ ] The `claude-api` skill was loaded before the request was written
  - [ ] The prompt and conversation shape live in `domain`
  - [ ] A refusal is a domain sentinel, checked **before** the response text is read
  - [ ] The thinking/effort setting is explicit
  - [ ] The token ceiling covers thinking plus answer
  - [ ] The request is pinned by an `httptest` test rather than the live API
- [ ] Ctrl-C/SIGTERM cancels the context
- [ ] In-flight work finishes or rolls back
- [ ] Interrupted runs exit non-zero
- [ ] Partial work is safe: units of work atomic (temp file + rename, transaction) or reruns idempotent
- **Prose passes [STYLE.md](../STYLE.md)**:
  - [ ] Comments say *why*, not what
  - [ ] The README leads with the point
  - [ ] Commits are semantic (`type(scope): subject`)
  - [ ] Any LLM prompts follow [patterns/go-llm-adapter.md](../patterns/go-llm-adapter.md) *Writing the prompt*
- **If the tool keeps a `GLOSSARY.md`** — [patterns/glossary.md](../patterns/glossary.md):
  - [ ] The README links it
  - [ ] Every term is the word the code, the subcommands, and the flags use
  - [ ] A `git grep` for each *Avoid* word finds no use of it for that concept, except where its entry says so
  - [ ] No term restates baseline or general-programming vocabulary

## Command-line contract

- [ ] stdout carries data only; diagnostics, progress, and usage go to stderr (`tool > out.txt 2>/dev/null` yields clean data)
- [ ] Exit codes: 0 success, 1 failure, 2 usage error
- [ ] `-h` prints usage and exits 0
- [ ] `-h` documents every flag including its env var default
- [ ] README shows the same
- [ ] `version` subcommand or `-version` flag reports via `debug.ReadBuildInfo` (correct under both `go install @tag` and checkout builds)
- **If `-json` exists**:
  - [ ] One object per line
  - [ ] It parses back with `encoding/json`
  - [ ] Field names treated as API
- [ ] No prompts, no colors, no ANSI sequences
- [ ] Destructive actions require an explicit `-force`-style flag

## Tests

- [ ] `go test -race -shuffle=on ./...` passes
- [ ] Core logic in `internal/` covered exhaustively (all rules/edge cases)
- **`run()` is table-tested**:
  - [ ] Happy path per subcommand (or the single command)
  - [ ] Unknown command and top-level `-h` where dispatch exists
  - [ ] Bad flag (→ `errUsage`)
  - [ ] `-json` round-trips where the flag exists
- [ ] Every port has a hand-written fake, never a mock — [patterns/go-ports-adapters.md](../patterns/go-ports-adapters.md)
- [ ] Tests assert the outcome, not call counts or call order

## Ship

- [ ] README links to this baseline
- [ ] README shows the `go install` line + a 30-second usage example
- [ ] Any waived rule recorded in the format [README.md](../README.md) *Which rules can be waived* defines
- [ ] Release workflow from [operations/cli-release.md](../operations/cli-release.md) in place
- [ ] A tag builds all six targets + `SHA256SUMS`
- [ ] `go install github.com/andygeiss/<tool>@<tag>` (or `…/cmd/<name>@<tag>` in a multi-binary module) verified from a clean machine (or empty `GOMODCACHE`)
- [ ] Semver honored: breaking changes to flags, exit codes, `-json` fields, or the meaning of stdout output only in a major release
