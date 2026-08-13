# Project Type: Web Application

**Last verified: 2026-08-13**

Server-rendered web application. This is the default and preferred shape for anything
with a UI — from a tic-tac-toe game to a SaaS dashboard.

## Mandated stack

| Layer | Technology | Rule |
|---|---|---|
| Backend | Go (stdlib `net/http`) | MUST. No web frameworks (no Gin, Echo, Fiber, Chi). |
| Templating | `html/template` | MUST. Embedded via `embed.FS`. |
| Interactivity | htmx 2.x | MUST for dynamic behavior. Self-hosted, single script tag. |
| Styling | Pure CSS | MUST. No preprocessor, no Tailwind, no framework. |
| Markup | Semantic HTML | MUST. Forms and links are the API of the UI. |
| Client-side JS | — | MUST NOT write any. htmx is the only script. |
| Persistence | SQLite (`modernc.org/sqlite`) first | SHOULD. Postgres (`pgx`) only when concurrency/scale demands it. |
| Sessions | `alexedwards/scs/v2`, server-side in SQLite | MUST when there are users. Cookie carries a random token only. |
| CSRF | stdlib `http.CrossOriginProtection` | MUST. No token libraries. |
| Deployment | Single static binary behind Caddy | MUST. Templates, CSS, htmx all embedded. |
| Local commands | Make | MUST. One `Makefile` at the repo root, copied from [stack/makefile.md](../stack/makefile.md). |

Versions: see [VERSIONS.md](../VERSIONS.md).

## Required reading (in order)

1. [stack/go.md](../stack/go.md) — language conventions and toolchain
2. [stack/html.md](../stack/html.md) — markup and the no-JS rule
3. [stack/css.md](../stack/css.md) — styling architecture
4. [stack/htmx.md](../stack/htmx.md) — hypermedia interactivity
5. [patterns/go-project-layout.md](../patterns/go-project-layout.md) — directory structure
6. [patterns/go-http-server.md](../patterns/go-http-server.md) — server, routing, middleware, CSRF
7. [patterns/htmx-server-rendering.md](../patterns/htmx-server-rendering.md) — full pages vs fragments
8. [patterns/css-layout.md](../patterns/css-layout.md) — mobile-first page and component layouts (grid)
9. [patterns/css-tokens.md](../patterns/css-tokens.md) — the concrete tokens layer and dark mode
10. [patterns/css-motion.md](../patterns/css-motion.md) — motion as feedback: transitions, view transitions, reduced motion
11. [patterns/design-system.md](../patterns/design-system.md) — the root `DESIGN.md`: theme values lockstep with `app.css`
12. [patterns/css-surfaces.md](../patterns/css-surfaces.md) — the surface style: minimal (the default), neumorphic, or glass
13. [patterns/go-sqlite.md](../patterns/go-sqlite.md) — production SQLite: pragmas, pools, migrations, backups
14. [patterns/go-auth-sessions.md](../patterns/go-auth-sessions.md) — sessions, login, password hashing (when there are users)
15. [patterns/go-errors-logging.md](../patterns/go-errors-logging.md) — errors and slog
16. [patterns/go-forms-validation.md](../patterns/go-forms-validation.md) — the form loop: validator, 422 re-render, flash messages
17. [patterns/go-testing.md](../patterns/go-testing.md) — testing strategy
18. [operations/web-application.md](../operations/web-application.md) — deployment, TLS, health, backups
19. [operations/ci.md](../operations/ci.md) — the CI workflow every project copies
20. [stack/makefile.md](../stack/makefile.md) — the Makefile every project copies (`make check` = CI locally)
21. [patterns/go-performance.md](../patterns/go-performance.md) — build/runtime defaults (GOMEMLIMIT, asset caching, version busting) apply from day one; optimization work only when something is measurably slow
22. [STYLE.md](../STYLE.md) — how everything for humans is written (docs, comments, prompts)

## Architecture defaults

- **One binary, one process.** HTTP server, background jobs, and static assets in a
  single Go binary, complete and correct on its own. Exactly two companion services
  are sanctioned, neither needed for correctness: Caddy (TLS + compression) and
  Litestream (backup replication) — nothing else without written justification.
- **Server-side state.** Session data lives in SQLite; the cookie (`Secure`, `HttpOnly`,
  `SameSite=Lax`) carries only a random token. The browser holds a session token and
  rendered HTML, nothing else.
- **Progressive enhancement.** Every feature MUST work with plain HTML forms and links
  if htmx fails to load. htmx upgrades the experience; it is not a dependency for correctness.
- **HTTPS everywhere**, HTTP only as a redirect. Security headers set in middleware
  (see [patterns/go-http-server.md](../patterns/go-http-server.md)).

## Definition of done

Walk [checklists/web-application.md](../checklists/web-application.md) before calling
any milestone complete.

## Reference implementation

[github.com/andygeiss/baseline-reference](https://github.com/andygeiss/baseline-reference) implements
this document end to end (deviations recorded in its README). When a rule here is
ambiguous, read how the reference does it.
