# Project Type: CLI Tool

**Last verified: 2026-08-17**

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

These three apply to every CLI, so read them before the first line of code. The order
is dependency order.

1. [stack/go.md](../stack/go.md) — language conventions and toolchain
2. [patterns/go-cli.md](../patterns/go-cli.md) — the `run()` pattern, flags, streams, exit codes, version
3. [STYLE.md](../STYLE.md) — how everything for humans is written (docs, comments, prompts)

**A document is required only when it changes a decision you make before the first
line of code.** Anything you can read at the moment you write the thing is a row in
the table below — that is the difference, and it is what keeps this list short.

## Open when you reach the thing it covers

A lookup table, not a reading assignment. Each row names the moment the document becomes
relevant — open it before you write the thing, not after.

| When you are about to… | Read |
|---|---|
| Name a concept this tool owns — a domain type, a subcommand, a flag | [patterns/glossary.md](../patterns/glossary.md) — the optional root `GLOSSARY.md`: one word per concept, the runners-up under *Avoid* |
| Read a flag, an environment variable, or a secret | [patterns/go-config.md](../patterns/go-config.md) — flags over env over defaults, validated before any work starts; §A CLI holds its secret differently |
| Return an error, or log anything | [patterns/go-errors-logging.md](../patterns/go-errors-logging.md) — wrapping, sentinels, and slog |
| Write a test | [patterns/go-testing.md](../patterns/go-testing.md) — what to test, and what never to fake |
| Depend on someone else's system | [patterns/go-ports-adapters.md](../patterns/go-ports-adapters.md) — the port and its fake: build and test the tool before the API is integrated |
| Call an external API over HTTP | [patterns/go-http-client.md](../patterns/go-http-client.md) — timeouts, retries, body limits |
| Add an AI capability — a model that answers, summarises, extracts, or classifies | [patterns/go-llm-adapter.md](../patterns/go-llm-adapter.md) — the port, the prompt in `domain`, refusals as sentinels. A tool holds its key differently: [patterns/go-config.md](../patterns/go-config.md) §A CLI holds its secret differently |
| Store anything between runs | [patterns/go-sqlite.md](../patterns/go-sqlite.md) — pragmas, pools, migrations (prefer staying stateless) |
| Set up the repo's commands or CI | [stack/makefile.md](../stack/makefile.md), then [operations/ci.md](../operations/ci.md) — `make check` is CI locally |
| Tag and publish a release | [operations/cli-release.md](../operations/cli-release.md) — cross-compiling, checksums, `go install` |
| Fix something measurably slow | [patterns/go-performance.md](../patterns/go-performance.md) — and not before |

If you are ever unsure whether a row applies, walk
[checklists/cli-tool.md](../checklists/cli-tool.md) — every box names the document
behind it, or sits under a bullet that does.

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
- **Check the name with `command -v` before you commit to it.** A plain English
  word is a name somebody already took: the reference client below was called
  `chat` for a day, and `/usr/sbin/chat` is a PPP utility on every macOS box — so
  the tool a person installed was not the tool that ran, with nothing to say so.
  Prefix it (`gochat`) and the collision is gone. The env vars follow the name
  ([patterns/go-config.md](../patterns/go-config.md) rule 6), so renaming later
  moves those too — which is why this is a decision to make first.

## Definition of done

Walk [checklists/cli-tool.md](../checklists/cli-tool.md) before calling any
milestone complete.

## Reference implementation

The `gochat` client in
[github.com/andygeiss/baseline-reference](https://github.com/andygeiss/baseline-reference)
implements this document end to end (deviations recorded in its README). When a
rule here is ambiguous, read how the reference does it.

It is the sanctioned multi-binary case: the module ships a server and a client,
so `main` sits in `cmd/gochat/` rather than at the module root, and the install
path gains the suffix.

**The one part it does not exercise is the release** — that repository's tags
mirror baseline versions rather than the tool's own contract, so it publishes no
artifacts and [operations/cli-release.md](../operations/cli-release.md) has no
reference yet.
