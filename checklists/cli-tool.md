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

## Code quality

- [ ] CI workflow from [operations/ci.md](../operations/ci.md) is in place and green
      (covers gofmt, vet, staticcheck, **govulncheck**, tidy, race tests, static build)
- [ ] `Makefile` from [stack/makefile.md](../stack/makefile.md) at the repo root (with the rule-5 adjustments for its layout); `make check` green and gate-for-gate identical to ci.yml
- [ ] `run(ctx, args, stdout, stderr)` pattern per [patterns/go-cli.md](../patterns/go-cli.md); `os.Exit` in `main` only
- [ ] Errors wrapped with `%w`; every failure surfaces as `tool: <cause>` on stderr, exit 1
- [ ] Config parsed and validated before any work starts; a bad value exits 2 with one line, never a half-done run
- [ ] If the repo has a `.env`: it is gitignored, only `make run` reads it, and production takes its secrets from credential files instead — [stack/makefile.md](../stack/makefile.md) rule 6
- [ ] Any outbound HTTP uses an injected client with a timeout (never `http.DefaultClient`), checks `resp.StatusCode`, and caps the body it reads — [patterns/go-http-client.md](../patterns/go-http-client.md)
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

## Ship

- [ ] README links to this baseline, shows `go install` line + a 30-second usage example, and records any waived rule in the format [README.md](../README.md) *Which rules can be waived* defines
- [ ] Release workflow from [operations/cli-release.md](../operations/cli-release.md) in place; tag builds all six targets + `SHA256SUMS`
- [ ] `go install github.com/andygeiss/<tool>@<tag>` (or `…/cmd/<name>@<tag>` in a multi-binary module) verified from a clean machine (or empty `GOMODCACHE`)
- [ ] Semver honored: breaking changes to flags, exit codes, `-json` fields, or the meaning of stdout output only in a major release
