# Project Type: Web Application

**Last verified: 2026-09-04**

Server-rendered web application. This is the default and preferred shape for anything
with a UI — from a todo list to a SaaS dashboard.

## Mandated stack

| Layer | Technology | Rule |
|---|---|---|
| Backend | Go (stdlib `net/http`) | MUST. No web frameworks (no Gin, Echo, Fiber, Chi). |
| Templating | `html/template` | MUST. Embedded via `embed.FS`. |
| Interactivity | htmx 2.x | MUST for dynamic behavior. Self-hosted, single script tag. |
| Styling | Pure CSS | MUST. No preprocessor, no Tailwind, no framework. |
| Icons & fonts | CSS mask icons; system font stack by default | MUST. No icon font, no icon package, no third-party origin. A brand web font is self-hosted — see [patterns/css-icons.md](../patterns/css-icons.md) and [patterns/css-typography.md](../patterns/css-typography.md). |
| Markup | Semantic HTML | MUST. Forms and links are the API of the UI. |
| Client-side JS | — | MUST NOT write any. htmx is the only script. |
| Install (PWA) | Web app manifest + icons | MAY, per project. MUST NOT add a service worker — see [patterns/pwa.md](../patterns/pwa.md). |
| Persistence | SQLite (`modernc.org/sqlite`) first | SHOULD. Postgres (`pgx`) only when concurrency/scale demands it. |
| Sessions | `alexedwards/scs/v2`, server-side in SQLite | MUST when there are users. Cookie carries a random token only. |
| CSRF | stdlib `http.CrossOriginProtection` | MUST. No token libraries. |
| Security headers | One `secureHeaders` middleware | MUST. CSP, HSTS, nosniff, Referrer-Policy — one owner, see [patterns/security-headers.md](../patterns/security-headers.md). |
| Config | flags > env vars > built-in defaults | MUST. One `Config` struct parsed in `main`, no config files — see [patterns/go-config.md](../patterns/go-config.md). |
| Outbound HTTP | stdlib `http.Client`, injected | MUST when calling an external API. Never `http.DefaultClient` — see [patterns/go-http-client.md](../patterns/go-http-client.md). |
| Deployment | Single static binary behind a TLS proxy | MUST. Templates, CSS, htmx all embedded. The binary satisfies [operations/web-application.md](../operations/web-application.md); *how* it is deployed belongs to the operations repository. |
| Local commands | Make | MUST. One `Makefile` at the repo root, copied from [stack/makefile.md](../stack/makefile.md). |
| Specification | `SPEC.md` at the repo root | MUST. Job and Why, one line each; Guardrails pointing at the waivers and the named decisions; Done means: the checklist plus `make ci`. Every task's brief is a delta against it — [README.md](../README.md) *The task brief*. |

Versions: see [VERSIONS.md](../VERSIONS.md).

## Required reading (in order)

These seven apply to every web application, so read them before the first line of
code. The order is dependency order.

1. [stack/go.md](../stack/go.md) — language conventions and toolchain
2. [stack/html.md](../stack/html.md) — markup and the no-JS rule
3. [stack/css.md](../stack/css.md) — styling architecture
4. [stack/htmx.md](../stack/htmx.md) — hypermedia interactivity
5. [patterns/go-project-layout.md](../patterns/go-project-layout.md) — directory structure
6. [patterns/go-http-server.md](../patterns/go-http-server.md) — server, routing, middleware, CSRF
7. [patterns/security-headers.md](../patterns/security-headers.md) — the CSP and every other security header, in one place

**A document is required only when it changes a decision you make before the first
line of code.** Anything you can read at the moment you write the thing is a trigger
section in the checklist — that is the difference, and it is what keeps this list short.
Security headers are the deliberate exception: the rule is tier 1, so it does not
wait for an agent to notice a trigger.

## Open when you reach the thing it covers

The triggers are in [checklists/web-application.md](../checklists/web-application.md),
one section each: the moment it fires, the document, and the boxes it will be checked
against. Read it now to learn which moments fire which document, then open each document
when you reach the thing it covers. Nothing there is optional when its trigger fires.

Working on a project that already follows this document? That file and the project's
`SPEC.md` are the only ones you need — everything above is a decision already made.

## Architecture defaults

- **One binary, one process.** HTTP server, background jobs, and static assets in a
  single Go binary, correct on its own — no supervisor, no start script, no second
  process it depends on. A deployment MAY run companion services beside it (a TLS proxy,
  a backup replicator); the application MUST NOT need any of them to be correct, and its
  code MUST NOT name one.
- **Server-side state.** Session data lives in SQLite and the cookie carries only a
  random token, so the browser holds that token and rendered HTML, nothing else. Cookie
  flags: [patterns/go-auth-sessions.md](../patterns/go-auth-sessions.md).
- **Progressive enhancement.** Every feature MUST work with plain HTML forms and links
  if htmx fails to load. htmx upgrades the experience; it is not a dependency for
  correctness.
- **HTTPS in public, plain HTTP inside.** The proxy terminates TLS and redirects HTTP to
  it; the binary only ever speaks plain HTTP, so `curl` against it works with nothing in
  front ([operations/web-application.md](../operations/web-application.md)). HSTS and the
  rest of the policy come from `secureHeaders`
  ([patterns/security-headers.md](../patterns/security-headers.md)).

## Definition of done

Re-read the brief, then walk the boxes of that same file before calling any milestone
complete.

[baseline-reference](https://github.com/andygeiss/baseline-reference) implements this
document end to end (deviations in its README). When a rule here is ambiguous, read how
the reference does it.
