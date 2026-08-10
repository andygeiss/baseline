# Checklist: Web Application — Definition of Done

**Last verified: 2026-08-10**

Walk this before declaring any milestone complete. Every unchecked box is either fixed
or explicitly waived by the user in writing.

## Stack compliance

- [ ] Versions match [VERSIONS.md](../VERSIONS.md) (`go.mod` says `go 1.26`; vendored htmx is 2.0.9)
- [ ] No dependencies outside the approved list in [stack/go.md](../stack/go.md), or each extra one is justified in the README
- [ ] Zero hand-written JavaScript; htmx is the only `<script>`
- [ ] No CSS/font/script loaded from a third-party origin
- [ ] Single static binary builds: `CGO_ENABLED=0 go build ./cmd/server` (assets embedded)

## Code quality

- [ ] `gofmt`/`goimports` clean, `go vet ./...` clean, `staticcheck ./...` clean
- [ ] `go mod tidy` leaves no diff
- [ ] Routes registered in one file; mutations are POST/PUT/DELETE only
- [ ] Server has read/write/idle timeouts and graceful shutdown
- [ ] Errors wrapped with `%w`; internal error text never rendered to the browser
- [ ] `log/slog` structured logging; no secrets in logs

## Tests

- [ ] `go test -race ./...` passes
- [ ] Domain logic covered exhaustively (all rules/edge cases)
- [ ] Each handler: happy path + error paths, via `httptest` against real routes
- [ ] Dual-mode handlers tested with and without `HX-Request: true`

## Hypermedia & progressive enhancement

- [ ] Every feature works with htmx disabled (plain forms/links, full-page renders)
- [ ] Navigation-like htmx GETs use `hx-push-url`; back button behaves
- [ ] Requests >100ms show an indicator; destructive actions have `hx-confirm`
- [ ] Dual-mode responses send `Vary: HX-Request`
- [ ] Invalid form POSTs return 422 with values + errors re-rendered

## Security

- [ ] CSP `default-src 'self'` active; headers middleware in place (nosniff, frame DENY, referrer)
- [ ] CSRF token on every mutation; verified server-side
- [ ] Session cookies: `Secure`, `HttpOnly`, `SameSite=Lax`
- [ ] All user input escaped via `html/template` (no `template.HTML` on user data)
- [ ] SQL only via parameterized queries
- [ ] Passwords (if any) hashed with argon2id or bcrypt

## HTML/CSS/A11y

- [ ] Valid HTML (spot-checked with the Nu validator); landmarks + heading hierarchy correct
- [ ] Every form control labelled; keyboard-only walkthrough succeeds; focus visible
- [ ] Contrast ≥ 4.5:1; `prefers-reduced-motion` respected; `lang` set
- [ ] CSS in cascade layers, no `!important` outside utilities
- [ ] Works at 320px width and at 200% zoom

## Ship

- [ ] README links to this baseline and records any waived rules
- [ ] Binary runs with only env vars/flags (`PORT`, `DATABASE_URL`, `LOG_LEVEL`)
- [ ] HTTPS-only in production; HTTP redirects
