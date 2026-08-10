# Checklist: CLI Tool — Definition of Done

**Last verified: 2026-08-10**

Walk this before declaring any milestone complete. Every unchecked box is either
fixed or explicitly waived by the user in writing.

## Stack compliance

- [ ] Versions match [VERSIONS.md](../VERSIONS.md) (`go.mod` says `go 1.26`)
- [ ] No dependencies outside the approved list in [stack/go.md](../stack/go.md), or each extra one is justified in the README
- [ ] Flags via stdlib `flag` only (no cobra/viper/urfave); config precedence is flags > env > defaults
- [ ] Single static binary builds: `CGO_ENABLED=0 go build .`
- [ ] `main` package at module root; logic in `internal/`

## Code quality

- [ ] CI workflow from [operations/ci.md](../operations/ci.md) is in place and green
      (covers gofmt, vet, staticcheck, **govulncheck**, tidy, race tests, static build)
- [ ] `run(ctx, args, stdout, stderr)` pattern per [patterns/go-cli.md](../patterns/go-cli.md); `os.Exit` in `main` only
- [ ] Errors wrapped with `%w`; every failure surfaces as `tool: <cause>` on stderr, exit 1
- [ ] Ctrl-C/SIGTERM cancels the context; in-flight work finishes or rolls back; interrupted runs exit non-zero
- [ ] Partial work is safe: units of work atomic (temp file + rename, transaction) or reruns idempotent

## Command-line contract

- [ ] stdout carries data only; diagnostics, progress, and usage go to stderr (`tool > out.txt 2>/dev/null` yields clean data)
- [ ] Exit codes: 0 success, 1 failure, 2 usage error; `-h` prints usage and exits 0
- [ ] `-h` documents every flag including its env var default; README shows the same
- [ ] `version` subcommand or `-version` flag reports via `debug.ReadBuildInfo` (correct under both `go install @tag` and checkout builds)
- [ ] If `-json` exists: one object per line, parses back with `encoding/json`, field names treated as API
- [ ] No prompts, no colors, no ANSI sequences; destructive actions require an explicit `-force`-style flag

## Tests

- [ ] `go test -race ./...` passes
- [ ] Core logic in `internal/` covered exhaustively (all rules/edge cases)
- [ ] `run()` table-tested: happy path per subcommand, unknown command, bad flag (→ `errUsage`), `-json` round-trips

## Ship

- [ ] README links to this baseline, shows `go install` line + a 30-second usage example, records any waived rules
- [ ] Release workflow from [operations/cli-release.md](../operations/cli-release.md) in place; tag builds all six targets + `SHA256SUMS`
- [ ] `go install github.com/andygeiss/<tool>@<tag>` verified from a clean machine (or empty `GOMODCACHE`)
- [ ] Semver honored: breaking changes to flags, exit codes, or `-json` fields only in a major release
