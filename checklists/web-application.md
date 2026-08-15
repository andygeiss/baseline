# Checklist: Web Application — Definition of Done

**Last verified: 2026-08-15**

Walk this before declaring any milestone complete. Every unchecked box is either fixed
or waived on the record — the waiver format lives in [README.md](../README.md) under
*Which rules can be waived*. **Nothing under Security below is waivable**, and neither
are the SQLite pragmas and the single-writer pool: those are the safety tier, so an
unchecked box there means the work is not done.

This checklist stands on its own. Every box names the document behind it, so you can
walk it without holding the whole corpus in your head.

## Stack compliance

- [ ] Versions match [VERSIONS.md](../VERSIONS.md) (`go.mod` says `go 1.26`; vendored htmx is 2.0.10)
- [ ] No dependencies outside the approved list in [stack/go.md](../stack/go.md), or each extra one is justified in the README
- [ ] Zero hand-written JavaScript; htmx is the only `<script>`; no service worker registered
- [ ] No CSS, font, icon, or script loaded from a third-party origin
- [ ] Single static binary builds: `CGO_ENABLED=0 go build ./cmd/server` (assets embedded)

## Code quality

- [ ] CI workflow from [operations/ci.md](../operations/ci.md) is in place and green
      (covers gofmt, vet, staticcheck, **govulncheck**, tidy, race tests, static build)
- [ ] `Makefile` from [stack/makefile.md](../stack/makefile.md) at the repo root; `make check` green and gate-for-gate identical to ci.yml
- [ ] Routes registered in one file; every mutation is a POST route (never GET; no PUT/DELETE — they break the plain-form fallback)
- [ ] Server has read/write/idle timeouts and graceful shutdown
- [ ] Errors wrapped with `%w`; internal error text never rendered to the browser
- [ ] `log/slog` structured logging; no secrets in logs (`Config.LogValue` allowlists the safe fields)
- [ ] Config parsed and validated in `main` before the DB opens or the listener binds; `internal/` never calls `os.Getenv`
- [ ] If the repo has a `.env`: it is gitignored, only `make run` reads it, and production takes its secrets from credential files instead — [stack/makefile.md](../stack/makefile.md) rule 6
- [ ] Any outbound HTTP uses an injected client with a timeout (never `http.DefaultClient`), checks `resp.StatusCode`, and caps the body it reads — [patterns/go-http-client.md](../patterns/go-http-client.md)
- [ ] Prose passes [STYLE.md](../STYLE.md): comments say *why* (not what), README leads with the point, commits are semantic (`type(scope): subject`), any LLM prompts follow its prompt rules

## Tests

- [ ] `go test -race -shuffle=on ./...` passes
- [ ] Domain logic covered exhaustively (all rules/edge cases)
- [ ] Each handler: happy path + error paths, via `httptest` against real routes
- [ ] Dual-mode handlers tested with and without `HX-Request: true`

## Hypermedia & progressive enhancement

- [ ] Every feature works with htmx disabled (plain forms/links, full-page renders)
- [ ] Navigation-like htmx GETs use `hx-push-url`; back button behaves
- [ ] Requests >100ms show an indicator; destructive actions have `hx-confirm`
- [ ] Dual-mode responses send `Vary: HX-Request, HX-Boosted`
- [ ] Invalid form POSTs return 422 with values + errors re-rendered (boosted POSTs: with `HX-Push-Url: false`)

## Security

- [ ] `secureHeaders` sends the full policy from [patterns/security-headers.md](../patterns/security-headers.md) — CSP, HSTS, nosniff, referrer — and the test pinning all four is green
- [ ] CSP carries `img-src 'self' data:`; a page with icons loads with **zero** CSP violations in the browser console
- [ ] `http.CrossOriginProtection` wraps the mux (CSRF)
- [ ] Request bodies capped at 1 MiB — `http.MaxBytesHandler`, or the route-aware limit chooser when upload routes need more (see [patterns/go-http-server.md](../patterns/go-http-server.md))
- [ ] Session cookies: `Secure`, `HttpOnly`, `SameSite=Lax`; `RenewToken` on login/password change, `Destroy` on logout
- [ ] Auth endpoints rate limited; login timing identical for unknown user vs wrong password
- [ ] All user input escaped via `html/template` (no `template.HTML` on user data)
- [ ] SQL only via parameterized queries
- [ ] Passwords (if any) hashed with argon2id (OWASP params, PHC-encoded)
- [ ] `/debug/pprof` and `/healthz` on the localhost-only ops listener, never proxied

## Database (SQLite)

- [ ] Pragmas per [patterns/go-sqlite.md](../patterns/go-sqlite.md): WAL, `busy_timeout`, `synchronous(NORMAL)`, `foreign_keys(1)`
- [ ] Two pools: reads pooled, writes `SetMaxOpenConns(1)` + `_txlock=immediate`
- [ ] Migrations embedded, forward-only, applied at boot inside a transaction
- [ ] Backups: the off-box question is answered and its mechanism runs — the Ship section below is where it gets verified

## HTML/CSS/A11y

- [ ] Valid HTML (spot-checked with the Nu validator; `hx-*` "attribute not allowed" errors are the only expected ones); landmarks + heading hierarchy correct
- [ ] Every form control labeled, and each field error tied to its control (`aria-describedby` + `aria-invalid`); keyboard-only walkthrough succeeds; focus visible
- [ ] Contrast ≥ 4.5:1; `prefers-reduced-motion` respected; `lang` set
- [ ] CSS in cascade layers, no `!important` outside `utilities`
- [ ] `DESIGN.md` at the repo root per [patterns/design-system.md](../patterns/design-system.md); every CSS value in it character-identical to `app.css`, measured contrast recorded
- [ ] Motion follows [patterns/css-motion.md](../patterns/css-motion.md): transition properties listed explicitly (never `all`); paint/compositor properties only; one-shot durations from the two motion tokens; rapid-fire swaps opt out (`transition:false`); view-transition kill switch in `utilities`
- [ ] Layout is mobile-first per [patterns/css-layout.md](../patterns/css-layout.md): layout media queries are `min-width` only and page-level only; components adapt via container queries; every list that drops its markers carries `role="list"`
- [ ] Any bottom navigation per [patterns/css-layout.md](../patterns/css-layout.md): every destination keeps its word under the icon, at most five of them, targets ≥ 3.5rem, the current one marked by color *and* weight plus `aria-current="page"`, the bar opaque and clear of `env(safe-area-inset-bottom)`
- [ ] One surface style per [patterns/css-surfaces.md](../patterns/css-surfaces.md), named in `DESIGN.md`; form controls keep a ≥ 3:1 `--color-border` boundary in every style; glass panels sit on the page ground only, alpha at the measured 80% floor
- [ ] Type per [patterns/css-typography.md](../patterns/css-typography.md): no root `font-size` override, sizes in `rem`/`em` with a `rem` term in every `clamp()`, `font: inherit` on form controls
- [ ] Any web font is self-hosted WOFF2, variable, one file per style, `font-display: optional`, versioned by filename, preloaded with `crossorigin` and no `?v=` on either URL; `.woff2` MIME registered at boot
- [ ] Icons per [patterns/css-icons.md](../patterns/css-icons.md): CSS masks painted with `currentColor`, `aria-hidden` on every icon, accessible name on the control, no icon font and no meaning carried by icon alone
- [ ] Works at 320 px width and at 200% zoom

## Ship

- [ ] README links to this baseline; any waived rule recorded in the format [README.md](../README.md) *Which rules can be waived* defines (rule, document, date, who, why, what contains it)
- [ ] The binary satisfies every line of [operations/web-application.md](../operations/web-application.md): two listeners, stdout logs, SIGTERM shutdown, state under `DATABASE_URL`, secrets from `CREDENTIALS_DIRECTORY`
- [ ] It starts with an empty environment on `127.0.0.1:8080` — no deployment needed to try it
- [ ] `GOMEMLIMIT` set by the deployment; version visible in `/healthz` and the boot log (`debug.ReadBuildInfo`) — and it is the git tag, not `unknown` and not a pseudo-version off an older major (past v1 the module path carries the `/vN` suffix — [operations/web-application.md](../operations/web-application.md) *Version stamping*)
- [ ] TLS terminates in front of the app, the app is reachable from nothing else, and the proxy writes its own `X-Forwarded-For`
- [ ] The off-box question is answered on purpose — "if this server disappears right now, what have you lost?" — with the matching row from [patterns/go-sqlite.md](../patterns/go-sqlite.md) running, and **the restore rehearsed once**
- [ ] Static assets served with `immutable` cache headers + version-busting query string
- [ ] If installable (PWA): manifest, all four icons, and head lines per [patterns/pwa.md](../patterns/pwa.md); `.webmanifest` MIME registered at boot; no service worker; manifest colors and `theme-color` metas are the current `--color-bg`, converted
- [ ] Deployed and rolled back at least once by following the operations repository's runbook, not by improvising
