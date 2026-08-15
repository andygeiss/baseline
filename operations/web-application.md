# Operations: The Deployment Contract

**Last verified: 2026-08-15**

What the binary MUST do, and what any deployment MUST give it. This document is
an interface, deliberately short. **How** it is satisfied — the proxy, the
container, the server, the backups — lives in the operations repository
(`baseline-ops`), and nothing here names a product.

The rule that keeps the split honest: **a fact belongs here when it changes the
code, and there when it changes only the server.**

## The binary's side

- **One process, correct on its own.** It serves HTTP, runs its own background
  work, and carries its assets. It MUST NOT need a start script, a supervisor,
  or a second process for correctness.
- **Two listeners.**
  - `$HOST:$PORT` — the application ([patterns/go-http-server.md](../patterns/go-http-server.md)).
    It binds what `HOST` says, with no opinion about what that address means.
  - `127.0.0.1:6060` — the ops mux, fixed, never proxied. `GET /healthz` returns
    200 + JSON `{"status":"ok","version":…}` and pings the database **via the
    read pool** with a 1 s timeout, 503 on failure. Never the write pool: its
    single connection is busy during any long write, and a ping queued behind it
    times out — a healthy app flapping 503. `/debug/pprof/…` lives here too;
    being localhost-only *is* its access control.
- **Logs to stdout only**, structured ([patterns/go-errors-logging.md](../patterns/go-errors-logging.md)).
  It MUST NOT open a log file or rotate anything. Whatever runs it owns shipping
  and retention.
- **Exits on SIGTERM**, gracefully, within about 10 seconds
  ([patterns/go-http-server.md](../patterns/go-http-server.md)). A deployment
  that stops it is normal traffic, not an incident.
- **Keeps its state in one place** — the database at `$DATABASE_URL`, and
  anything else it writes beside that file, in the same directory. It assumes no
  other path is writable.
- **Stamps its own version** from VCS data, no ldflags — see *Version stamping*.

## The deployment's side

- **A proxy in front terminates TLS**, adds compression, and is the only public
  listener. It MUST discard client-sent `X-Forwarded-*` headers and write its
  own, because the per-IP rate limiter
  ([patterns/go-auth-sessions.md](../patterns/go-auth-sessions.md)) keys on that
  value. The app trusts it only because nothing else can reach the app.
- **A `HOST` the proxy can actually reach**, and nothing else can. The built-in
  default is loopback, which is right on a laptop and wrong the moment the
  process sits behind a network boundary of its own — the app binds what it is
  told and cannot tell the difference.
- **The proxy adds TLS and compression, never correctness.** The application
  answered on plain HTTP before the proxy existed, and must still.
- **A writable, persistent directory** — the one holding `$DATABASE_URL` — that
  survives restarts and redeployments.
- **Secret files**, one per secret, in the directory named by
  `$CREDENTIALS_DIRECTORY` ([patterns/go-config.md](../patterns/go-config.md)).
  Never environment variables, never flags.
- **A memory limit**, with `GOMEMLIMIT` set below it.
- **Whatever it takes to build from a git checkout**, `.git` included: the
  version stamp has no other source.

## Version stamping

No ldflags ceremony — the toolchain already embeds VCS info, and `-trimpath`
keeps it. `debug.ReadBuildInfo` reports it as `info.Main.Version`: the tag when
HEAD sits on one, a pseudo-version otherwise, with `+dirty` appended when the
tree had uncommitted changes. The canonical reader is `version()` in
[patterns/go-cli.md](../patterns/go-cli.md) — it checks the `ok` result, because
a binary built outside module mode gets no `BuildInfo` at all, and reading a
field off the nil it returns panics at boot.

Read it once at boot. That one string is the boot log line, the `/healthz`
field, and the static-asset cache-buster
(see [patterns/go-performance.md](../patterns/go-performance.md)). Release from
clean, tagged checkouts, so no deployed version carries `+dirty`.

Two things silently break the stamp wherever the build happens: a missing `.git`,
and a missing `git` binary. Neither produces an error — every binary just
reports `unknown`. A version of `unknown` at `/healthz` means one of the two.

**Past v1, "the tag" holds only if the module path says so.** Go accepts a
`vX.Y.Z` tag for the main module only when the path ends in the matching major
suffix, so an application tagged `v2.0.0` whose `go.mod` still reads
`github.com/you/app` gets no error and no warning — the toolchain quietly falls
back to a pseudo-version off the last v1 tag, and `/healthz` names a version
nobody released. Before the first v2 tag, the module path becomes
`github.com/you/app/v2` and every internal import moves with it:

```
module github.com/you/app/v2   ← go.mod, and every internal import path
```

The cost lands in operations, not in Go: images are tagged by version and a
rollback is identified by it, so a `v2.0.0` image whose `/healthz` reports
`v1.7.3-0.20260815…` leaves "what is running?" without one answer. Check it once
per major, with `go version -m ./bin/app` against a clean tagged checkout — the
`mod` line is the string the binary will report.

## Environment contract

The binary is configured by exactly these. `HOST`, `PORT`, `DATABASE_URL`, and
`LOG_LEVEL` are flags with env-var defaults (a flag overrides its env var);
`ENV`, `GOMEMLIMIT`, and `CREDENTIALS_DIRECTORY` are read from the environment
only. Secrets are not in this table on purpose — they arrive as files. The
parser that produces all of it is
[patterns/go-config.md](../patterns/go-config.md):

| Var | Meaning | Built-in default |
|---|---|---|
| `HOST` | bind address | `127.0.0.1` (a laptop wants loopback) |
| `PORT` | app listener port | `8080` |
| `DATABASE_URL` | SQLite file path | `app.db` |
| `LOG_LEVEL` | slog level | `info` |
| `ENV` | `dev` / `prod` (text vs JSON logs) | `dev` |
| `GOMEMLIMIT` | runtime memory limit | unset |
| `CREDENTIALS_DIRECTORY` | directory holding secret files | unset (no secrets in dev) |

Every default MUST produce a working app on `127.0.0.1:8080` with an empty
environment ([patterns/go-config.md](../patterns/go-config.md) rule 3). A
deployment overrides what it must; it never needs to patch the binary.

## Backups

**Answer this before launch: if the server disappears right now, what have you
lost?** The database is one file on one machine, and so is any snapshot written
beside it. [patterns/go-sqlite.md](../patterns/go-sqlite.md) has the three
legitimate answers and what each one costs. "I don't know" is not one of them.

The answer decides what the deployment runs; the rehearsed restore is what
proves it works. Both belong to the operations repository — the question belongs
here, because it is a product decision and it sometimes changes the code.
