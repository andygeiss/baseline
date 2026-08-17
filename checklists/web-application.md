# Checklist: Web Application — Definition of Done

**Last verified: 2026-08-17**

Walk this before declaring any milestone complete. Every unchecked box is either fixed
or waived on the record — the waiver format lives in [README.md](../README.md) under
*Which rules can be waived*. **Nothing under Security below is waivable**, and neither
are the SQLite pragmas and the single-writer pool, nor the three secret-handling boxes
that sit under *Code quality* — `Config.LogValue`, the `.env` block, and secrets arriving
as credential files. Tier 1 is decided by what a rule protects, not by which section it
landed in, so an unchecked box in any of those means the work is not done.

This checklist stands on its own. Every box — or the bold bullet it sits under — names
the document behind it, so you can walk it without holding the whole corpus in your
head.

**One box, one check.** A box that needs two answers is two boxes: a box holding six
conditions gets ticked while three of them fail. Where several checks share a scope,
the scope is a bold bullet and the checks sit under it. Keep it that way when you add
here.

## Stack compliance

- [ ] `go.mod` says `go 1.26`, matching [VERSIONS.md](../VERSIONS.md)
- [ ] The vendored htmx is 2.0.10, matching [VERSIONS.md](../VERSIONS.md)
- [ ] No dependencies outside the approved list in [stack/go.md](../stack/go.md), or each extra one is justified in the README
- [ ] Zero hand-written JavaScript
- [ ] htmx is the only `<script>`
- [ ] No service worker registered
- [ ] No CSS, font, icon, or script loaded from a third-party origin
- [ ] Single static binary builds: `CGO_ENABLED=0 go build ./cmd/server` (assets embedded)
- [ ] The binary never serves TLS — no `-tls-cert` flag, in development or anywhere else ([patterns/local-https.md](../patterns/local-https.md))

## Code quality

- [ ] CI workflow from [operations/ci.md](../operations/ci.md) is in place and green
      (covers gofmt, vet, staticcheck, **govulncheck**, tidy, race tests, static build)
- [ ] `Makefile` from [stack/makefile.md](../stack/makefile.md) at the repo root
- [ ] `make check` is green
- [ ] `make check` is gate-for-gate identical to ci.yml
- [ ] Routes registered in one file
- [ ] Every mutation is a POST route — never GET, and no PUT/DELETE (they break the plain-form fallback)
- [ ] Server sets read, write, and idle timeouts
- [ ] Server shuts down gracefully
- **The timeout ladder holds** — [patterns/go-http-client.md](../patterns/go-http-client.md):
  - [ ] Any handler that waits on another system sets its own `context.WithTimeout` — that is the budget
  - [ ] `WriteTimeout` sits above the budget
  - [ ] Every outbound client timeout sits at or above the budget
- **Each step of a multi-dependency operation is marked required or enhancement** — [patterns/go-errors-logging.md](../patterns/go-errors-logging.md):
  - [ ] Every step carries one label or the other, decided when it was written
  - [ ] The irreplaceable result is persisted before any enhancement runs
  - [ ] Enhancement failures log at `Warn` and still answer
  - [ ] A test proves each one degrades instead of failing
- [ ] Nothing calls a remote system at boot — lookups are lazy and cached, so a dependency being down is a broken feature, not a crash loop ([patterns/go-http-client.md](../patterns/go-http-client.md))
- **Any periodic worker** — [patterns/go-http-server.md](../patterns/go-http-server.md):
  - [ ] It runs once before entering its ticker loop
  - [ ] It treats `context.Canceled` at shutdown as normal, not an error
- [ ] Errors wrapped with `%w`
- [ ] Internal error text never rendered to the browser
- [ ] `log/slog` structured logging
- [ ] No secrets in logs — `Config.LogValue` allowlists the safe fields
- **Config** — [patterns/go-config.md](../patterns/go-config.md):
  - [ ] Parsed and validated in `main` before the DB opens or the listener binds
  - [ ] `internal/` never calls `os.Getenv`
  - [ ] Settings that are only valid together are checked as a pair (rule 7)
- **If the repo has a `.env`** — [stack/makefile.md](../stack/makefile.md) rule 6:
  - [ ] It is gitignored
  - [ ] Only `make run` reads it
  - [ ] Production takes its secrets from credential files instead
- **If a developer reaches the app over local HTTPS** — [patterns/local-https.md](../patterns/local-https.md):
  - [ ] `Caddyfile.lan` is its own file, never an edited copy of `baseline-ops/templates/Caddyfile`
  - [ ] Nothing that ships reads it — the image does not build it in, the deployment never names it
  - [ ] The root certificate and its key were never committed
  - [ ] The authority stays on the machine that made it — nothing a user visits is served with a certificate it signed
  - [ ] The README says the project opts in, next to how to run it
- **Any outbound HTTP** — [patterns/go-http-client.md](../patterns/go-http-client.md):
  - [ ] Uses an injected client with a timeout, never `http.DefaultClient`
  - [ ] Checks `resp.StatusCode`
  - [ ] Caps the body it reads
- **Any adapter for someone else's system** — [patterns/go-ports-adapters.md](../patterns/go-ports-adapters.md):
  - [ ] It sits in its own package
  - [ ] It defines no port of its own
  - [ ] It exposes domain methods instead of `*http.Response`
  - [ ] It imports `internal/domain` and nothing else of yours — `go list -deps` proves it
- **Any AI capability** — [patterns/go-llm-adapter.md](../patterns/go-llm-adapter.md):
  - [ ] The `claude-api` skill was loaded before the request was written — no model ID, header, or field from memory
  - [ ] The prompt and the conversation shape live in `domain`
  - [ ] A refusal is a domain sentinel, checked **before** the response text is read
  - [ ] The thinking/effort setting is explicit
  - [ ] The token ceiling covers thinking plus answer
  - [ ] The app still starts with an empty environment — a degenerate adapter shipped as a product mode
  - [ ] Boot never calls the model
- **Any AI adapter's tests** — [patterns/go-llm-adapter.md](../patterns/go-llm-adapter.md):
  - [ ] The **request** is pinned against `httptest` — model, thinking setting, effort, token ceiling, headers
  - [ ] The refusal translation is pinned
  - [ ] No test asserts on model output
  - [ ] No test calls the live API
- **Prose passes [STYLE.md](../STYLE.md)**:
  - [ ] Comments say *why*, not what
  - [ ] The README leads with the point
  - [ ] Commits are semantic (`type(scope): subject`)
  - [ ] Every startup and config error names the fix, and the flag or file to change
  - [ ] Any LLM prompts follow [patterns/go-llm-adapter.md](../patterns/go-llm-adapter.md) *Writing the prompt*
- **If the project keeps a `GLOSSARY.md`** — [patterns/glossary.md](../patterns/glossary.md):
  - [ ] The README links it
  - [ ] Every term is the word the code, the UI, and the URLs use
  - [ ] A `git grep` for each *Avoid* word finds no use of it for that concept, except where its entry says so
  - [ ] No term restates baseline or general-programming vocabulary

## Tests

- [ ] `go test -race -shuffle=on ./...` passes
- [ ] Domain logic covered exhaustively (all rules/edge cases)
- [ ] Each handler: happy path + error paths, via `httptest` against real routes
- [ ] Dual-mode handlers tested with and without `HX-Request: true`
- [ ] Every port has a hand-written fake, never a mock — [patterns/go-ports-adapters.md](../patterns/go-ports-adapters.md)
- [ ] Tests assert the outcome, not call counts or call order

## Hypermedia & progressive enhancement

- [ ] Every feature works with htmx disabled (plain forms/links, full-page renders)
- [ ] Navigation-like htmx GETs use `hx-push-url`; back button behaves
- [ ] Requests >100ms show an indicator — except a background poll, which shows none ([patterns/htmx-live-updates.md](../patterns/htmx-live-updates.md))
- [ ] Destructive actions have `hx-confirm`
- [ ] Dual-mode responses send `Vary: HX-Request, HX-Boosted`
- [ ] The fragment-or-full-page test is one named function both `render` and the handlers call, never two copies of the header check ([patterns/htmx-server-rendering.md](../patterns/htmx-server-rendering.md))
- [ ] Invalid form POSTs return 422 with values + errors re-rendered
- [ ] Boosted POSTs re-render with `HX-Push-Url: false`
- **Any live-updating region** — [patterns/htmx-live-updates.md](../patterns/htmx-live-updates.md):
  - [ ] The cursor is a row id the server advances inside the swapped sentinel
  - [ ] An empty poll answers 204
  - [ ] The route 303s a non-htmx request
  - [ ] The poll carries no indicator and no rate limit

## Security

- [ ] `secureHeaders` sends the full policy from [patterns/security-headers.md](../patterns/security-headers.md) — CSP, HSTS, nosniff, referrer
- [ ] The test pinning all four is green
- [ ] CSP carries `img-src 'self' data:`
- [ ] A page with icons loads with **zero** CSP violations in the browser console
- [ ] `http.CrossOriginProtection` wraps the mux (CSRF)
- [ ] Request bodies capped at 1 MiB — `http.MaxBytesHandler`, or the route-aware limit chooser when upload routes need more (see [patterns/go-http-server.md](../patterns/go-http-server.md))
- **Session cookies** — [patterns/go-auth-sessions.md](../patterns/go-auth-sessions.md):
  - [ ] `HttpOnly` and `SameSite=Lax` always
  - [ ] `Secure` tied to `ENV`, so production sets it and dev does not
  - [ ] `RenewToken` on login and on password change
  - [ ] `Destroy` on logout
- [ ] Auth endpoints rate limited
- [ ] Login timing identical for unknown user vs wrong password
- **Any machine token** — [patterns/go-auth-sessions.md](../patterns/go-auth-sessions.md) §Machine tokens:
  - [ ] 32 random bytes
  - [ ] Only its SHA-256 stored
  - [ ] Shown once
  - [ ] Read from `Authorization: Bearer`, never from the query string
  - [ ] Revoked by DELETE
- [ ] All user input escaped via `html/template` (no `template.HTML` on user data)
- [ ] SQL only via parameterized queries
- [ ] Passwords (if any) hashed with argon2id (OWASP params, PHC-encoded)
- [ ] `/debug/pprof` and `/healthz` on the localhost-only ops listener
- [ ] The ops listener is never proxied

## Database (SQLite)

- [ ] Pragmas per [patterns/go-sqlite.md](../patterns/go-sqlite.md): WAL, `busy_timeout`, `synchronous(NORMAL)`, `foreign_keys(1)`
- **Two pools** — [patterns/go-sqlite.md](../patterns/go-sqlite.md):
  - [ ] Reads pooled
  - [ ] Writes on a single connection: `SetMaxOpenConns(1)` + `_txlock=immediate`
- [ ] Migrations embedded and forward-only
- [ ] Migrations applied at boot inside a transaction
- [ ] Backups: the off-box question is answered and its mechanism runs — the Ship section below is where it gets verified

## HTML/CSS/A11y

- [ ] Valid HTML, spot-checked with the Nu validator (`hx-*` "attribute not allowed" errors are the only expected ones)
- [ ] Landmarks + heading hierarchy correct
- [ ] Every form control labeled
- [ ] Each field error tied to its control (`aria-describedby` + `aria-invalid`)
- [ ] Keyboard-only walkthrough succeeds
- [ ] Focus visible
- [ ] Contrast ≥ 4.5:1
- [ ] `prefers-reduced-motion` respected
- [ ] `lang` set
- [ ] CSS in cascade layers
- [ ] No `!important` outside `utilities`
- **`DESIGN.md`** — [patterns/design-system.md](../patterns/design-system.md):
  - [ ] It sits at the repo root
  - [ ] Every CSS value in it is character-identical to `app.css`
  - [ ] Measured contrast recorded
- **Motion** — [patterns/css-motion.md](../patterns/css-motion.md):
  - [ ] Transition properties listed explicitly, never `all`
  - [ ] Paint and compositor properties only
  - [ ] One-shot durations from the two motion tokens
  - [ ] Rapid-fire swaps opt out (`transition:false`)
  - [ ] The view-transition kill switch is in `utilities`
- **Layout is mobile-first** — [patterns/css-layout.md](../patterns/css-layout.md):
  - [ ] Layout media queries are `min-width` only, and page-level only
  - [ ] Components adapt via container queries
  - [ ] Every list that drops its markers carries `role="list"`
- **Any bottom navigation** — [patterns/css-layout.md](../patterns/css-layout.md):
  - [ ] Every destination keeps its word under the icon
  - [ ] At most five of them
  - [ ] Targets ≥ 3.5rem
  - [ ] The current one marked by color *and* weight, plus `aria-current="page"`
  - [ ] The bar opaque and clear of `env(safe-area-inset-bottom)`
- **Surfaces** — [patterns/css-surfaces.md](../patterns/css-surfaces.md):
  - [ ] One surface style, named in `DESIGN.md`
  - [ ] Form controls keep a ≥ 3:1 `--color-border` boundary in every style
  - [ ] Glass panels sit on the page ground only, alpha at the measured 80% floor
- **Type** — [patterns/css-typography.md](../patterns/css-typography.md):
  - [ ] No root `font-size` override
  - [ ] Sizes in `rem`/`em`, with a `rem` term in every `clamp()`
  - [ ] `font: inherit` on form controls
- **Any web font** — [patterns/css-typography.md](../patterns/css-typography.md):
  - [ ] Self-hosted WOFF2, variable, one file per style
  - [ ] `font-display: optional`
  - [ ] Versioned by filename
  - [ ] Preloaded with `crossorigin`, and no `?v=` on either URL
  - [ ] `.woff2` MIME registered at boot
- **Icons** — [patterns/css-icons.md](../patterns/css-icons.md):
  - [ ] CSS masks painted with `currentColor`
  - [ ] `aria-hidden` on every icon
  - [ ] Accessible name on the control
  - [ ] No icon font, and no meaning carried by icon alone
- [ ] Works at 320 px width
- [ ] Works at 200% zoom

## Ship

- [ ] README links to this baseline
- [ ] Any waived rule recorded in the format [README.md](../README.md) *Which rules can be waived* defines (rule, document, date, who, why, what contains it)
- **The binary satisfies every line of [operations/web-application.md](../operations/web-application.md)**:
  - [ ] Two listeners
  - [ ] stdout logs
  - [ ] SIGTERM shutdown
  - [ ] State under `DATABASE_URL`
  - [ ] Secrets from `CREDENTIALS_DIRECTORY`
- [ ] It starts with an empty environment on `127.0.0.1:8080` — no deployment needed to try it
- [ ] `GOMEMLIMIT` set by the deployment
- **The version is visible in `/healthz` and the boot log** (`debug.ReadBuildInfo`) — [operations/web-application.md](../operations/web-application.md) *Version stamping*:
  - [ ] It appears in both places
  - [ ] It is the git tag — not the commit id or the per-boot id the reader answers for an untagged or edited build, which mean you did not release from a clean tagged checkout
  - [ ] It is not a pseudo-version off an older major — past v1 the module path carries the `/vN` suffix
- **In front of the app**:
  - [ ] TLS terminates in front of the app
  - [ ] The app is reachable from nothing else
  - [ ] The proxy writes its own `X-Forwarded-For`
- [ ] The off-box question is answered on purpose — "if this server disappears right now, what have you lost?" — with the matching row from [patterns/go-sqlite.md](../patterns/go-sqlite.md) running
- [ ] **The restore rehearsed once**
- [ ] Static assets served with `immutable` cache headers + version-busting query string
- [ ] The buster is the three-case reader from [patterns/go-performance.md](../patterns/go-performance.md) — a released version, the commit for a clean checkout, a per-boot id for an edited tree, never a constant like `unknown` or a repeated `+dirty`
- **If installable (PWA)** — [patterns/pwa.md](../patterns/pwa.md):
  - [ ] Manifest, all four icons, and head lines in place
  - [ ] `.webmanifest` MIME registered at boot
  - [ ] No service worker
  - [ ] Manifest colors and `theme-color` metas are the current `--color-bg`, converted
- [ ] Deployed and rolled back at least once by following the operations repository's runbook, not by improvising
