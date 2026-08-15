# Project Type: CLI Tool

**Last verified: 2026-08-15**

Command-line tool: starts, does one job, exits. If the process is meant to stay up
and serve requests, it is not a CLI — build a [web application](web-application.md).

## Mandated stack

| Layer | Technology | Rule |
|---|---|---|
| Language | Go (stdlib) | MUST. Same conventions as everywhere: [stack/go.md](../stack/go.md). |
| Flags | stdlib `flag`, one `FlagSet` per subcommand | MUST. No cobra, viper, urfave/cli, kong. |
| Config | flags > env vars > built-in defaults | MUST. No config files until genuinely needed — see [patterns/go-config.md](../patterns/go-config.md). |
| Output | stdout = data, stderr = everything else | MUST. See [patterns/go-cli.md](../patterns/go-cli.md). |
| Machine output | `encoding/json` behind a `-json` flag | SHOULD, when other programs consume the output. |
| Outbound HTTP | stdlib `http.Client`, built in `run()` | MUST when the tool calls an API. Never `http.DefaultClient` — see [patterns/go-http-client.md](../patterns/go-http-client.md). |
| Persistence | none; SQLite (`modernc.org/sqlite`) if the tool keeps state | SHOULD prefer stateless. |
| Deployment | single static binary (`CGO_ENABLED=0`) | MUST. |
| Distribution | `go install` + GitHub release binaries | MUST. See [operations/cli-release.md](../operations/cli-release.md). |
| Local commands | Make | MUST. `Makefile` from [stack/makefile.md](../stack/makefile.md), with the rule-5 adjustments for its layout. |

Versions: see [VERSIONS.md](../VERSIONS.md).

## Required reading (in order)

These five apply to every CLI, so read them before the first line of code. The order is
dependency order.

1. [stack/go.md](../stack/go.md) — language conventions and toolchain
2. [patterns/go-cli.md](../patterns/go-cli.md) — the `run()` pattern, flags, streams, exit codes, version
3. [patterns/go-config.md](../patterns/go-config.md) — flags over env over defaults, validated before any work starts
4. [patterns/go-errors-logging.md](../patterns/go-errors-logging.md) — errors and slog
5. [STYLE.md](../STYLE.md) — how everything for humans is written (docs, comments, prompts)

## Open when you reach the thing it covers

A lookup table, not a reading assignment. Each row names the moment the document becomes
relevant — open it before you write the thing, not after.

| When you are about to… | Read |
|---|---|
| Write a test | [patterns/go-testing.md](../patterns/go-testing.md) — what to test, and what never to fake |
| Depend on someone else's system | [patterns/go-ports-adapters.md](../patterns/go-ports-adapters.md) — the port and its fake: build and test the tool before the API is integrated |
| Call an external API over HTTP | [patterns/go-http-client.md](../patterns/go-http-client.md) — timeouts, retries, body limits |
| Store anything between runs | [patterns/go-sqlite.md](../patterns/go-sqlite.md) — pragmas, pools, migrations (prefer staying stateless) |
| Set up the repo's commands or CI | [stack/makefile.md](../stack/makefile.md), then [operations/ci.md](../operations/ci.md) — `make check` is CI locally |
| Tag and publish a release | [operations/cli-release.md](../operations/cli-release.md) — cross-compiling, checksums, `go install` |
| Fix something measurably slow | [patterns/go-performance.md](../patterns/go-performance.md) — and not before |

If you are ever unsure whether a row applies, walk
[checklists/cli-tool.md](../checklists/cli-tool.md) — every box names the document
behind it.

## Architecture defaults

- **Layout:** for the common case — a module that ships exactly one binary — the
  `main` package lives at the **module root** (wiring only, same size budget as
  [patterns/go-project-layout.md](../patterns/go-project-layout.md)), all logic in
  `internal/`. This makes the install path clean:
  `go install github.com/andygeiss/<tool>@latest`. Use `cmd/<name>/` only when one
  module genuinely ships several binaries.
- **The `run()` pattern.** `main` parses nothing and decides nothing: it builds a
  signal-aware context, calls `run(ctx, args, stdout, stderr)`, maps the returned
  error to an exit code. `os.Exit` appears in `main` only. Details and canonical
  code in [patterns/go-cli.md](../patterns/go-cli.md).
- **A CLI terminates.** Ctrl-C/SIGTERM cancels the context and the tool exits
  cleanly, finishing or rolling back the current unit of work. No daemon mode, no
  `--watch` loops by default — a process that should run forever is a different
  project type.
- **No interactivity.** Everything arrives via flags, arguments, environment, or
  stdin. No prompts, no TUI. A tool that needs a conversation with the user
  probably wants to be a web application.
- **Subcommands are a smell until they aren't.** Single-purpose tools take flags
  only. Add manual dispatch (stdlib, ~10 lines) when the tool genuinely does
  several things; at more than ~5 subcommands, question whether it is several tools.

## Definition of done

Walk [checklists/cli-tool.md](../checklists/cli-tool.md) before calling any
milestone complete.

## Reference implementation

None yet. Until one exists, the snippets in
[patterns/go-cli.md](../patterns/go-cli.md) are canonical — the first CLI built
against this document SHOULD be promoted to reference status.
