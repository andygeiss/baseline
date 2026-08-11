# Checklist: Web Application — Definition of Done

**Last verified: 2026-08-11**

Walk this before declaring any milestone complete. Every unchecked box is either fixed
or explicitly waived by the user in writing.

## Stack compliance

- [ ] Versions match [VERSIONS.md](../VERSIONS.md) (`go.mod` says `go 1.26`; vendored htmx is 2.0.10)
- [ ] No dependencies outside the approved list in [stack/go.md](../stack/go.md), or each extra one is justified in the README
- [ ] Zero hand-written JavaScript; htmx is the only `<script>`
- [ ] No CSS/font/script loaded from a third-party origin
- [ ] Single static binary builds: `CGO_ENABLED=0 go build ./cmd/server` (assets embedded)

## Code quality

- [ ] CI workflow from [operations/ci.md](../operations/ci.md) is in place and green
      (covers gofmt, vet, staticcheck, **govulncheck**, tidy, race tests, static build)
- [ ] `Makefile` from [stack/makefile.md](../stack/makefile.md) at the repo root; `make check` green and gate-for-gate identical to ci.yml
- [ ] Routes registered in one file; every mutation is a POST route (never GET; no PUT/DELETE — they break the plain-form fallback)
- [ ] Server has read/write/idle timeouts and graceful shutdown
- [ ] Errors wrapped with `%w`; internal error text never rendered to the browser
- [ ] `log/slog` structured logging; no secrets in logs
- [ ] Prose passes [STYLE.md](../STYLE.md): comments say *why* (not what), README leads with the point, any LLM prompts follow its prompt rules

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

- [ ] CSP `default-src 'self'; frame-ancestors 'none'` active; headers middleware in place (HSTS, nosniff, referrer)
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
- [ ] Backups running (Litestream or `VACUUM INTO`) **and the restore was rehearsed once**

## HTML/CSS/A11y

- [ ] Valid HTML (spot-checked with the Nu validator; `hx-*` "attribute not allowed" errors are the only expected ones); landmarks + heading hierarchy correct
- [ ] Every form control labelled; keyboard-only walkthrough succeeds; focus visible
- [ ] Contrast ≥ 4.5:1; `prefers-reduced-motion` respected; `lang` set
- [ ] CSS in cascade layers, no `!important` outside utilities
- [ ] Works at 320px width and at 200% zoom

## Ship

- [ ] README links to this baseline and records any waived rules
- [ ] Binary runs with only the env contract from [operations/web-application.md](../operations/web-application.md)
- [ ] Deployed per the ops doc: Caddy in front (auto-HTTPS + compression), app on localhost, hardened systemd unit
- [ ] `GOMEMLIMIT` set; version visible in `/healthz` and boot log (`debug.ReadBuildInfo`)
- [ ] Static assets served with `immutable` cache headers + version-busting query string
- [ ] Previous binary kept as instant rollback
