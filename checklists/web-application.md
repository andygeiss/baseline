# Web Application — Triggers and Definition of Done

**Last verified: 2026-08-17**

One topic per section: **the moment it fires, the document that rules it, and what done
looks like.** Read a section before you write the thing it covers; walk its boxes before
you call the work complete. Paths are from the repository root.

Every unchecked box is either fixed or waived on the record — the format is in
`README.md` *Which rules can be waived*. **Tier 1 is decided by what a rule
protects, not by which section it landed in**, so a wholly tier-1 section says so in its
heading. Six sections are only partly tier 1: `Config.LogValue` and the three `.env`
boxes under *Reading a flag…*; the pragmas, both pools, and parameterized SQL under
*Storing anything*; the zero-CSP-violations check under *Adding an icon*; every box under
*Reading or writing a row somebody owns* except the one naming the shared rows; the
base-URL and the header box under *Sending an email*; every box under *Deleting a
person* except the one naming where each table's answer is written. No waiver for any of
those; there is a fix.

## Every web application

No trigger: these fire for every project of this type.

- [ ] `go.mod` says `go 1.26`, matching `VERSIONS.md`
- [ ] The vendored htmx is 2.0.10, matching `VERSIONS.md`
- [ ] No dependency outside `stack/go.md`'s approved list, or the README justifies it
- [ ] Zero hand-written JavaScript
- [ ] htmx is the only `<script>`
- [ ] No service worker registered
- [ ] No CSS, font, icon, or script loaded from a third-party origin
- [ ] Single static binary builds: `CGO_ENABLED=0 go build ./cmd/server`
- [ ] The binary never serves TLS, in development or anywhere else (`patterns/local-https.md`)
- [ ] Routes registered in one file
- [ ] Every mutation is a POST route — never GET, and no PUT/DELETE
- [ ] Server sets read, write, and idle timeouts
- [ ] Server shuts down gracefully
- [ ] Valid HTML, spot-checked with the Nu validator
- [ ] Landmarks + heading hierarchy correct
- [ ] Every form control labeled
- [ ] Keyboard-only walkthrough succeeds
- [ ] Focus visible
- [ ] `lang` set
- [ ] README links to this baseline
- [ ] Any waived rule recorded in `README.md`'s six-field waiver format

### Security — tier 1, not waivable

Required reading, not a trigger: the policy is tier 1. `patterns/security-headers.md` owns
the CSP and every other header.

- [ ] `secureHeaders` sends the full policy — CSP, HSTS, nosniff, referrer
- [ ] The test pinning all four is green
- [ ] CSP carries `img-src 'self' data:`
- [ ] `http.CrossOriginProtection` wraps the mux (CSRF)
- [ ] Request bodies capped at 1 MiB by `http.MaxBytesHandler` (`patterns/go-http-server.md`)
- [ ] All user input escaped via `html/template` (no `template.HTML` on user data)
- [ ] `/debug/pprof` and `/healthz` on the localhost-only ops listener
- [ ] The ops listener is never proxied

## Naming a concept this project owns — a domain type, a route word, a UI label

`patterns/glossary.md` — the optional root `GLOSSARY.md`: one word per concept.

- **If the project keeps a `GLOSSARY.md`:**
  - [ ] The README links it
  - [ ] Every term is the word the code, the UI, and the URLs use
  - [ ] A `git grep` for each *Avoid* word finds no use for that concept
  - [ ] No term restates baseline or general-programming vocabulary

## Reading a flag, an environment variable, or a secret

`patterns/go-config.md` — the `Config` struct: flags over env over defaults.

- [ ] Parsed and validated in `main` before the DB opens or the listener binds
- [ ] `internal/` never calls `os.Getenv`
- [ ] Settings that are only valid together are checked as a pair (rule 7)
- [ ] No secrets in logs — `Config.LogValue` allowlists the safe fields
- **If the repo has a `.env`** — `stack/makefile.md` rule 6:
  - [ ] It is gitignored
  - [ ] Only `make run` reads it
  - [ ] Production takes its secrets from credential files instead

## Returning an error, or logging anything

`patterns/go-errors-logging.md` — wrapping, sentinels, and slog.

- [ ] Errors wrapped with `%w`
- [ ] Internal error text never rendered to the browser
- [ ] `log/slog` structured logging
- [ ] Every startup and config error names the fix
- **Each step of a multi-dependency operation is marked required or enhancement:**
  - [ ] Every step carries one label or the other
  - [ ] The irreplaceable result is persisted before any enhancement runs
  - [ ] Enhancement failures log at `Warn` and still answer
  - [ ] A test proves each one degrades instead of failing

## Writing a comment, a README, a commit message, an error message, or a prompt

`STYLE.md` — point first, short sentences, plain words.

- [ ] Comments say *why*, not what
- [ ] The README leads with the point
- [ ] Commits are semantic (`type(scope): subject`)
- [ ] Any LLM prompts follow `patterns/llm-prompting.md`

## Rendering a response — a full page or a fragment

`patterns/htmx-server-rendering.md` — which one to send, and how the shell composes.

- [ ] Every feature works with htmx disabled (plain forms/links, full-page renders)
- [ ] Navigation-like htmx GETs use `hx-push-url`; back button behaves
- [ ] Requests >100 ms show an indicator, except a background poll (`patterns/htmx-live-updates.md`)
- [ ] Destructive actions have `hx-confirm`
- [ ] Dual-mode responses send `Vary: HX-Request, HX-Boosted`
- [ ] The fragment-or-full-page test is one named function
- [ ] Boosted POSTs re-render with `HX-Push-Url: false`
- [ ] Dual-mode handlers tested with and without `HX-Request: true`

## Showing a time or a date

`patterns/time-and-dates.md` — the zone the server picks, and formatting in the handler.

- [ ] The project's zone answer is named in the README
- [ ] Formatting happens in the handler, never in a template
- [ ] Every `Format` call names a zone — `time.Local` appears nowhere
- [ ] `time/tzdata` is imported, and every configured zone loads at boot
- [ ] Every rendered moment carries `<time datetime>` with the UTC value

## Writing any CSS at all

`patterns/css-tokens.md` — the tokens layer and dark mode.

- [ ] CSS in cascade layers
- [ ] No `!important` outside `utilities`
- [ ] Contrast ≥ 4.5:1

## Laying out a page or a component

`patterns/css-layout.md` — mobile-first grid, container queries, bottom nav.

- [ ] Layout media queries are `min-width` only, and page-level only
- [ ] Components adapt via container queries
- [ ] Every list that drops its markers carries `role="list"`
- [ ] Works at 320 px width
- [ ] Works at 200% zoom
- **Any bottom navigation:**
  - [ ] Every destination keeps its word under the icon
  - [ ] At most five of them
  - [ ] Targets ≥ 3.5rem
  - [ ] The current one marked by color *and* weight, plus `aria-current="page"`
  - [ ] The bar opaque and clear of `env(safe-area-inset-bottom)`

## Writing the first line of `app.css`

`patterns/design-system.md` — the root `DESIGN.md`, lockstep with the stylesheet.

- [ ] It sits at the repo root
- [ ] Every CSS value in it is character-identical to `app.css`
- [ ] Measured contrast recorded

## Choosing how surfaces look

`patterns/css-surfaces.md` — minimal (the default), neumorphic, or glass.

- [ ] One surface style, named in `DESIGN.md`
- [ ] Form controls keep a ≥ 3:1 `--color-border` boundary in every style
- [ ] Glass panels sit on the page ground only, alpha at the measured 80% floor

## Sizing text, or adding a web font

`patterns/css-typography.md` — the type scale, and how to self-host a font.

- [ ] No root `font-size` override
- [ ] Sizes in `rem`/`em`, with a `rem` term in every `clamp()`
- [ ] `font: inherit` on form controls
- **Any web font:**
  - [ ] Self-hosted WOFF2, variable, one file per style
  - [ ] `font-display: optional`
  - [ ] Versioned by filename
  - [ ] Preloaded with `crossorigin`, and no `?v=` on either URL
  - [ ] `.woff2` MIME registered at boot

## Adding an icon

`patterns/css-icons.md` — CSS masks tinted by `currentColor`.

- [ ] CSS masks painted with `currentColor`
- [ ] `aria-hidden` on every icon
- [ ] Accessible name on the control
- [ ] No icon font, and no meaning carried by icon alone
- [ ] A page with icons loads with **zero** CSP violations in the browser console

## Animating or transitioning anything

`patterns/css-motion.md` — motion as feedback, and reduced motion.

- [ ] Transition properties listed explicitly, never `all`
- [ ] Paint and compositor properties only
- [ ] One-shot durations from the two motion tokens
- [ ] Rapid-fire swaps opt out (`transition:false`)
- [ ] The view-transition kill switch is in `utilities`
- [ ] `prefers-reduced-motion` respected

## Storing anything

`patterns/go-sqlite.md` — pragmas, the two pools, migrations, backups.

- [ ] Pragmas: WAL, `busy_timeout`, `synchronous(NORMAL)`, `foreign_keys(1)`
- [ ] SQL only via parameterized queries
- **Two pools:**
  - [ ] Reads pooled
  - [ ] Writes on a single connection: `SetMaxOpenConns(1)` + `_txlock=immediate`
- [ ] Migrations embedded and forward-only
- [ ] Migrations applied at boot inside a transaction
- [ ] The off-box question is answered on purpose, with the matching row running
- [ ] **The restore rehearsed once**

## Adding users, login, or passwords — tier 1, not waivable

`patterns/go-auth-sessions.md` — sessions, hashing, renewal.

- **Session cookies:**
  - [ ] `HttpOnly` and `SameSite=Lax` always
  - [ ] `Secure` tied to `ENV`, so production sets it and dev does not
  - [ ] `RenewToken` on login and on password change
  - [ ] `Destroy` on logout
- [ ] Auth endpoints rate limited
- [ ] Login timing identical for unknown user vs wrong password
- [ ] Passwords (if any) hashed with argon2id (OWASP params, PHC-encoded)

## Letting a program sign in — a CLI, a script — tier 1, not waivable

`patterns/go-auth-sessions.md` §Machine tokens — a bearer token, hashed at rest.

- [ ] 32 random bytes
- [ ] Only its SHA-256 stored
- [ ] Shown once
- [ ] Read from `Authorization: Bearer`, never from the query string
- [ ] Revoked by DELETE

## Reading or writing a row somebody owns

`patterns/go-authorization.md` — the actor in the signature, the predicate in the SQL.

- [ ] Every store method touching an owned row takes the actor as a parameter
- [ ] Ownership is a predicate in the SQL, never a comparison in Go
- [ ] The actor comes from the session, never the request
- [ ] Somebody else's row and a row that never existed answer identically
- [ ] No route answers 403 for a row, only for a route the actor may never use
- [ ] Lists, counts, and aggregates carry the same predicate
- [ ] Writes prove ownership in their own statement and check `RowsAffected`
- [ ] A route's protection is not optional where it is registered
- [ ] The rows nobody owns are named in `README.md` or `DESIGN.md`
- [ ] The two-user test covers every handler that touches an owned row

## Accepting a form POST

`patterns/go-forms-validation.md` — validator, 422 re-render, flash messages.

- [ ] Invalid form POSTs return 422 with values + errors re-rendered
- [ ] Each field error tied to its control (`aria-describedby` + `aria-invalid`)

## Taking a file from a user — an upload, an attachment, an avatar — tier 1, not waivable

`patterns/go-file-uploads.md` — the generated name, the sniffed type, and serving it back.

- [ ] The route's cap is raised at the cap site, never on the blanket wrapper
- [ ] The stored name is generated; the client's filename is data, never a path
- [ ] The type is `http.DetectContentType`'s answer, checked against an exact allowlist
- [ ] Downloads go through a handler, never a file server
- [ ] Anything not rendered inline is sent `Content-Disposition: attachment`
- [ ] The upload-that-lies test pins what those bytes are never served as

## Sending an email — a reset link, a verification, any notification

`patterns/go-email.md` — the port, the outbox, and the link that comes from `Config`.

- [ ] Every link is built from `cfg.BaseURL`, never from `r.Host`
- [ ] Any header value holding CR or LF is refused
- [ ] The message is queued in the causing transaction; a ticker sends it
- [ ] The response never changes with the send's outcome
- [ ] The `Host: evil.example` test is green

## Deleting a person, or anything they own

`patterns/go-data-deletion.md` — what the delete reaches, and what stops authenticating.

- [ ] Every table holding the person's rows declares an `ON DELETE` action
- [ ] Each table's answer — erase, anonymize, refuse — is written where the shared rows are
- [ ] The credential middleware loads the user row, so a deleted account is signed out
- [ ] Outbox rows carrying their address go with the account
- [ ] Bytes on disk are unlinked after the commit, from names collected inside it
- [ ] The all-tables test reads the schema at runtime and finds the id in no table

## Keeping a page current while the reader watches it

`patterns/htmx-live-updates.md` — polling with a cursor, the 204, and why not SSE.

- [ ] The cursor is a row id the server advances inside the swapped sentinel
- [ ] An empty poll answers 204
- [ ] The route 303s a non-htmx request
- [ ] The poll carries no indicator and no rate limit

## Showing a list longer than one page

`patterns/htmx-lists.md` — keyset over `OFFSET`, and the control that carries the cursor.

- [ ] The query is keyset, and its last sort term is unique
- [ ] An index covers the sort key
- [ ] The cursor rides in the query string, on an `<a href>` that works without htmx
- [ ] A filter or sort change drops the cursor
- [ ] Where the list also polls, the two cursors have different names

## Running anything on a schedule — a janitor, a backup, any ticker loop

`patterns/go-background-work.md` — the errgroup and the run-before-the-first-tick rule.

- [ ] It runs under the `errgroup` tied to the signal context, never a bare `go func()`
- [ ] It runs once before entering its ticker loop
- [ ] It treats `context.Canceled` at shutdown as normal

## Depending on someone else's system

`patterns/go-ports-adapters.md` — the port, and the hand-written fake.

- [ ] The adapter sits in its own package
- [ ] It defines no port of its own
- [ ] It exposes domain methods instead of `*http.Response`
- [ ] It imports `internal/domain` and nothing else of yours — `go list -deps` proves it
- [ ] Every port has a hand-written fake, never a mock
- [ ] Tests assert the outcome, not call counts or call order

## Calling an external API over HTTP

`patterns/go-http-client.md` — timeouts, retries, body limits.

- [ ] Uses an injected client with a timeout, never `http.DefaultClient`
- [ ] Checks `resp.StatusCode`
- [ ] Caps the body it reads
- [ ] Nothing calls a remote system at boot
- **The timeout ladder holds:**
  - [ ] Any handler that waits on another system sets its own `context.WithTimeout` — the budget
  - [ ] `WriteTimeout` sits above the budget
  - [ ] Every outbound client timeout sits at or above the budget

## Adding an AI capability — a model that answers, summarises, extracts, or classifies

`patterns/go-llm-adapter.md` — the port, the prompt in `domain`, refusals as sentinels.
Load the `claude-api` skill for anything on the wire.

- [ ] The `claude-api` skill was loaded before the request was written
- [ ] The prompt and the conversation shape live in `domain`
- [ ] A refusal is a domain sentinel, checked **before** the response text is read
- [ ] The app still starts with an empty environment
- [ ] Boot never calls the model
- **Its tests:**
  - [ ] The **request** is pinned against `httptest` — model, thinking setting, effort, token ceiling, headers
  - [ ] The refusal translation is pinned
  - [ ] No test asserts on model output
  - [ ] No test calls the live API

## Writing or tuning a prompt, or reading what a model wrote back

`patterns/llm-prompting.md` — the thinking and effort settings, and leaked reasoning.

- [ ] The thinking/effort setting is explicit
- [ ] The token ceiling covers thinking plus answer
- [ ] No "do not think" instruction anywhere in the prompt
- [ ] The visible answer was read: no reasoning leaked into it

## Writing a test

`patterns/go-testing.md` — what to test, and what never to fake.

- [ ] `go test -race -shuffle=on ./...` passes
- [ ] Domain logic covered exhaustively (all rules/edge cases)
- [ ] Each handler: happy path + error paths, via `httptest` against real routes

## Making the app installable

`patterns/pwa.md` — manifest, icons, and no service worker.

- [ ] Manifest, all four icons, and head lines in place
- [ ] `.webmanifest` MIME registered at boot
- [ ] Manifest colors and `theme-color` metas are the current `--color-bg`, converted

## Building anything a browser allows only over HTTPS — camera, microphone, geolocation, notifications, passkeys, install — or trying the app on a phone

`patterns/local-https.md` — `Caddyfile.lan` in front, and trusting its root on the device.

- [ ] `Caddyfile.lan` is its own file, not an edited copy of the deployment's
- [ ] Nothing that ships reads it
- [ ] The root certificate and its key were never committed
- [ ] The authority stays on the machine that made it
- [ ] The README says the project opts in, next to how to run it

## Setting up the repo's commands or CI

`stack/makefile.md`, then `operations/ci.md` — `make check` is CI locally.

- [ ] CI workflow is in place and green, with every gate that document lists
- [ ] `Makefile` at the repo root
- [ ] `make check` is green
- [ ] `make check` is gate-for-gate identical to ci.yml

## Configuring the build, or serving a static asset

`patterns/go-performance.md` — GOMEMLIMIT, cache headers, version busting.

- [ ] `GOMEMLIMIT` set by the deployment
- [ ] Static assets served `immutable`, with a version-busting query string
- [ ] The buster is that document's three-case reader, never a constant

## Shipping it

`operations/web-application.md` — the deployment contract.

- **The binary satisfies every line of the contract:**
  - [ ] Two listeners
  - [ ] stdout logs
  - [ ] SIGTERM shutdown
  - [ ] State under `DATABASE_URL`
  - [ ] Secrets from `CREDENTIALS_DIRECTORY`
- [ ] It starts with an empty environment on `127.0.0.1:8080`
- **The version is visible in `/healthz` and the boot log** (`debug.ReadBuildInfo`):
  - [ ] It appears in both places
  - [ ] It is the git tag, not the commit id or the per-boot id
  - [ ] Not a pseudo-version off an older major — past v1 the module path carries `/vN`
- **In front of the app:**
  - [ ] TLS terminates in front of the app
  - [ ] The app is reachable from nothing else
  - [ ] The proxy writes its own `X-Forwarded-For`
- [ ] Deployed and rolled back at least once by the operations runbook
