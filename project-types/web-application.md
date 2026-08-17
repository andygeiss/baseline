# Project Type: Web Application

**Last verified: 2026-08-17**

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

Versions: see [VERSIONS.md](../VERSIONS.md).

## Required reading (in order)

These eleven apply to every web application, so read them before the first line of
code. The order is dependency order.

1. [stack/go.md](../stack/go.md) — language conventions and toolchain
2. [stack/html.md](../stack/html.md) — markup and the no-JS rule
3. [stack/css.md](../stack/css.md) — styling architecture
4. [stack/htmx.md](../stack/htmx.md) — hypermedia interactivity
5. [patterns/go-project-layout.md](../patterns/go-project-layout.md) — directory structure
6. [patterns/go-config.md](../patterns/go-config.md) — the `Config` struct: flags over env over defaults, validated at boot
7. [patterns/go-http-server.md](../patterns/go-http-server.md) — server, routing, middleware, CSRF
8. [patterns/security-headers.md](../patterns/security-headers.md) — the CSP and every other security header, in one place
9. [patterns/htmx-server-rendering.md](../patterns/htmx-server-rendering.md) — full pages vs fragments
10. [patterns/go-errors-logging.md](../patterns/go-errors-logging.md) — errors and slog
11. [STYLE.md](../STYLE.md) — how everything for humans is written (docs, comments, prompts)

## Open when you reach the thing it covers

The rest of the corpus is a lookup table, not a reading assignment. Each row names the
moment the document becomes relevant. **Open it at that moment — and open it before you
write the thing, not after.** Nothing here is optional when its trigger fires; the
checklist checks all of it either way.

| When you are about to… | Read |
|---|---|
| Name a concept this project owns — a domain type, a route word, a UI label | [patterns/glossary.md](../patterns/glossary.md) — the optional root `GLOSSARY.md`: one word per concept, the runners-up under *Avoid* |
| Write any CSS at all | [patterns/css-tokens.md](../patterns/css-tokens.md) — the tokens layer and dark mode |
| Lay out a page or a component | [patterns/css-layout.md](../patterns/css-layout.md) — mobile-first grid, container queries, bottom nav |
| Write the first line of `app.css` | [patterns/design-system.md](../patterns/design-system.md) — the root `DESIGN.md`, lockstep with the stylesheet |
| Choose how surfaces look | [patterns/css-surfaces.md](../patterns/css-surfaces.md) — minimal (the default), neumorphic, or glass |
| Size text, or add a web font | [patterns/css-typography.md](../patterns/css-typography.md) — the type scale, and the only sanctioned way to self-host a font |
| Add an icon | [patterns/css-icons.md](../patterns/css-icons.md) — CSS masks tinted by `currentColor` |
| Animate or transition anything | [patterns/css-motion.md](../patterns/css-motion.md) — motion as feedback, and reduced motion |
| Store anything | [patterns/go-sqlite.md](../patterns/go-sqlite.md) — pragmas, the two pools, migrations, backups |
| Add users, login, or passwords | [patterns/go-auth-sessions.md](../patterns/go-auth-sessions.md) — sessions, hashing, renewal |
| Let a program sign in (a CLI, a script) | [patterns/go-auth-sessions.md](../patterns/go-auth-sessions.md) §Machine tokens — a bearer token, hashed at rest, shown once |
| Accept a form POST | [patterns/go-forms-validation.md](../patterns/go-forms-validation.md) — validator, 422 re-render, flash messages |
| Keep a page current while the reader watches it | [patterns/htmx-live-updates.md](../patterns/htmx-live-updates.md) — polling with a cursor, the 204, and why not SSE |
| Depend on someone else's system | [patterns/go-ports-adapters.md](../patterns/go-ports-adapters.md) — the port, the hand-written fake, finishing the feature before the API exists |
| Call an external API over HTTP | [patterns/go-http-client.md](../patterns/go-http-client.md) — timeouts, retries, body limits |
| Add an AI capability — a model that answers, summarises, extracts, or classifies | [patterns/go-llm-adapter.md](../patterns/go-llm-adapter.md) — the port, the prompt in `domain`, refusals as sentinels, and the reasoning that leaks into the answer. Load the `claude-api` skill for anything on the wire |
| Write a test | [patterns/go-testing.md](../patterns/go-testing.md) — what to test, and what never to fake |
| Make the app installable | [patterns/pwa.md](../patterns/pwa.md) — manifest, icons, and why there is never a service worker |
| Build anything a browser allows only over HTTPS — camera, microphone, geolocation, notifications, passkeys, install — or try the app on a phone | [patterns/local-https.md](../patterns/local-https.md) — `Caddyfile.lan` in front on the developer's machine, and trusting its root on the device |
| Set up the repo's commands or CI | [stack/makefile.md](../stack/makefile.md), then [operations/ci.md](../operations/ci.md) — `make check` is CI locally |
| Configure the build, or serve a static asset | [patterns/go-performance.md](../patterns/go-performance.md) — GOMEMLIMIT, cache headers, version busting: day-one defaults, not tuning |
| Ship it | [operations/web-application.md](../operations/web-application.md) — the deployment contract: listeners, signals, logs, secrets |

If you are ever unsure whether a row applies, walk
[checklists/web-application.md](../checklists/web-application.md) — every box names the
document behind it, or sits under a bullet that does.

## Architecture defaults

- **One binary, one process.** HTTP server, background jobs, and static assets in a
  single Go binary, complete and correct on its own — no supervisor, no start script,
  no second process it depends on. A deployment MAY run companion services beside it
  (a TLS proxy, a backup replicator); the application MUST NOT need any of them to be
  correct, and its code MUST NOT name one.
- **Server-side state.** Session data lives in SQLite; the cookie (`HttpOnly`,
  `SameSite=Lax`, and `Secure` in production — [patterns/go-auth-sessions.md](../patterns/go-auth-sessions.md))
  carries only a random token. The browser holds a session token and
  rendered HTML, nothing else.
- **Progressive enhancement.** Every feature MUST work with plain HTML forms and links
  if htmx fails to load. htmx upgrades the experience; it is not a dependency for correctness.
- **HTTPS in public, plain HTTP inside.** The proxy terminates TLS and redirects
  HTTP to it; the binary itself only ever speaks plain HTTP, so `curl` against it
  works with nothing in front ([operations/web-application.md](../operations/web-application.md)).
  HSTS and the rest of the policy come from the `secureHeaders` middleware
  ([patterns/security-headers.md](../patterns/security-headers.md)).

## Definition of done

Walk [checklists/web-application.md](../checklists/web-application.md) before calling
any milestone complete.

## Reference implementation

[github.com/andygeiss/baseline-reference](https://github.com/andygeiss/baseline-reference) implements
this document end to end (deviations recorded in its README). When a rule here is
ambiguous, read how the reference does it.
