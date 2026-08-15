# Checklist: CLI Tool — Definition of Done

**Last verified: 2026-08-15**

Walk this before declaring any milestone complete. Every unchecked box is either
fixed or waived on the record — the waiver format lives in [README.md](../README.md)
under *Which rules can be waived*. The safety tier is not waivable: partial work
staying safe, and a destructive action needing an explicit flag.

This checklist stands on its own. Every box names the document behind it, so you can
walk it without holding the whole corpus in your head.

## Stack compliance

- [ ] Versions match [VERSIONS.md](../VERSIONS.md) (`go.mod` says `go 1.26`)
- [ ] No dependencies outside the approved list in [stack/go.md](../stack/go.md), or each extra one is justified in the README
- [ ] Flags via stdlib `flag` only (no cobra/viper/urfave); config precedence is flags > env > defaults per [patterns/go-config.md](../patterns/go-config.md)
- [ ] Single static binary builds: `CGO_ENABLED=0 go build .` (or `./cmd/...` in a multi-binary module)
- [ ] `main` package at module root (`cmd/<name>/` only when the module ships several binaries); logic in `internal/`
- [ ] The binary's name is free: `command -v <name>` finds nothing on a stock macOS and Linux box — a collision means the tool that runs is not the tool that was installed ([project-types/cli-tool.md](../project-types/cli-tool.md))

## Code quality

- [ ] CI workflow from [operations/ci.md](../operations/ci.md) is in place and green
      (covers gofmt, vet, staticcheck, **govulncheck**, tidy, race tests, static build)
- [ ] `Makefile` from [stack/makefile.md](../stack/makefile.md) at the repo root (with the rule-5 adjustments for its layout); `make check` green and gate-for-gate identical to ci.yml
- [ ] `run(ctx, args, stdout, stderr)` pattern per [patterns/go-cli.md](../patterns/go-cli.md); `os.Exit` in `main` only
- [ ] Errors wrapped with `%w`; every failure surfaces as `tool: <cause>` on stderr, exit 1
- [ ] Config parsed and validated before any work starts; a bad value exits 2 with one line, never a half-done run
- [ ] If the repo has a `.env`: it is gitignored, only `make run` reads it, and production takes its secrets from credential files instead — [stack/makefile.md](../stack/makefile.md) rule 6
- [ ] Any outbound HTTP uses an injected client with a timeout (never `http.DefaultClient`), checks `resp.StatusCode`, and caps the body it reads — [patterns/go-http-client.md](../patterns/go-http-client.md)
- [ ] Any adapter for someone else's system sits in its own package, defines no port of its own, exposes domain methods instead of `*http.Response`, and imports `internal/domain` and nothing else of yours — `go list -deps` proves it ([patterns/go-ports-adapters.md](../patterns/go-ports-adapters.md))
- [ ] Any secret (API token, key) is read from a file named by `-token-file`/`$MYTOOL_TOKEN_FILE`, with `$MYTOOL_TOKEN` documented as the leaky fallback and **never** taken from a flag value — [patterns/go-config.md](../patterns/go-config.md) *A CLI holds its secret differently*
- [ ] Ctrl-C/SIGTERM cancels the context; in-flight work finishes or rolls back; interrupted runs exit non-zero
- [ ] Partial work is safe: units of work atomic (temp file + rename, transaction) or reruns idempotent
- [ ] Prose passes [STYLE.md](../STYLE.md): comments say *why* (not what), README leads with the point, commits are semantic (`type(scope): subject`), any LLM prompts follow its prompt rules

## Command-line contract

- [ ] stdout carries data only; diagnostics, progress, and usage go to stderr (`tool > out.txt 2>/dev/null` yields clean data)
- [ ] Exit codes: 0 success, 1 failure, 2 usage error; `-h` prints usage and exits 0
- [ ] `-h` documents every flag including its env var default; README shows the same
- [ ] `version` subcommand or `-version` flag reports via `debug.ReadBuildInfo` (correct under both `go install @tag` and checkout builds)
- [ ] If `-json` exists: one object per line, parses back with `encoding/json`, field names treated as API
- [ ] No prompts, no colors, no ANSI sequences; destructive actions require an explicit `-force`-style flag

## Tests

- [ ] `go test -race -shuffle=on ./...` passes
- [ ] Core logic in `internal/` covered exhaustively (all rules/edge cases)
- [ ] `run()` table-tested: happy path per subcommand (or the single command); unknown command and top-level `-h` where dispatch exists; bad flag (→ `errUsage`); `-json` round-trips where the flag exists
- [ ] Every port has a hand-written fake, never a mock; tests assert the outcome, not call counts or call order — [patterns/go-ports-adapters.md](../patterns/go-ports-adapters.md)

## Ship

- [ ] README links to this baseline, shows `go install` line + a 30-second usage example, and records any waived rule in the format [README.md](../README.md) *Which rules can be waived* defines
- [ ] Release workflow from [operations/cli-release.md](../operations/cli-release.md) in place; tag builds all six targets + `SHA256SUMS`
- [ ] `go install github.com/andygeiss/<tool>@<tag>` (or `…/cmd/<name>@<tag>` in a multi-binary module) verified from a clean machine (or empty `GOMODCACHE`)
- [ ] Semver honored: breaking changes to flags, exit codes, `-json` fields, or the meaning of stdout output only in a major release
