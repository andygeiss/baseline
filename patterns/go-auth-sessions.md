# Pattern: Authentication & Sessions (Go)

**Tier 1** (safety — never waived) · Last verified: 2026-09-08 · Sessions: `alexedwards/scs/v2` (v2.9.0) · Hashing: argon2id

Tier 1: the cookie flags, the token hashed in the store, the store's two MUSTs,
`RenewToken` and `Destroy`, what a password change asks for, ends and writes, the
no-enumeration rule, the argon2id parameters, the rate limits, the
reset token, every machine-token rule, and re-resolving a long-lived connection. The
rest of the scs wiring and the redirect mechanics are tier 2.

Server-side sessions: the cookie carries only a random token; all session data lives in
SQLite. Nothing is decrypted client-side, nothing to key-rotate, revocation is one statement.

This document answers *who is signed in*, and stops there. *May that actor touch this
row* is the next question and a separate tier-1 document:
[go-authorization.md](go-authorization.md).

## Session manager

Constructed in `main.go`, injected like every other dependency:

```go
sessions := scs.New()
sessions.Lifetime = 12 * time.Hour
sessions.IdleTimeout = 2 * time.Hour
sessions.HashTokenInStore = true                // the database holds a SHA-256, never a usable token
sessions.Cookie.Secure = cfg.Env == "prod"      // TLS is in front only in production — see below
sessions.Cookie.HttpOnly = true                 // set both explicitly: scs defaults HttpOnly=true
sessions.Cookie.SameSite = http.SameSiteLaxMode // and SameSite=Lax — don't "simplify" these away
sessions.Store = store.NewSessionStore(readDB, writeDB, sessions.Lifetime)
```

`sessions.ErrorFunc` MUST be set where the app is built, to the app's own `serverError`:
scs's default writes a store error to the standard logger, unstructured.

**`Secure` follows `ENV`, and that is not a weakened rule.** The binary only ever
speaks plain HTTP; a proxy adds TLS in front of it
([project-types/web-application.md](../project-types/web-application.md)). A
client returns a `Secure` cookie only over a connection it counts as secure, and
clients make exactly one exception for plain HTTP: **loopback**, in `curl` and in
any browser following the secure-contexts rule. A flat `Secure = true` therefore
survives on a laptop and hides the problem.

Nothing past loopback gets that exception. On a LAN address or a container's hostname
the cookie is not even stored: nobody signs in. `ENV` is the one setting that knows whether TLS is in front, because
the deployment sets it ([go-config.md](go-config.md)) — so `Secure` in production,
off in dev. `HttpOnly` and `SameSite=Lax` never fork.

`sessions.LoadAndSave` wraps the mux (see [go-http-server.md](go-http-server.md)
middleware chain).

⚠️ `scs.New()` ships a default in-memory store and has already started its
cleanup goroutine by the time the `Store` assignment above orphans it. Accepted
as-is — the one sanctioned exception to the goroutine-ownership rule in
[stack/go.md](../stack/go.md): the tick is a no-op on the empty memstore, scs offers
no store-injecting constructor, and `StopCleanup()` at construction time is racy.

⚠️ **Do not use the bundled `sqlite3store`** — it takes a single `*sql.DB`, and this
baseline's SQLite setup requires two ([go-sqlite.md](go-sqlite.md)): `LoadAndSave`
calls `Find` on every request, so a single-pool store either serializes the whole app
behind the one-connection write pool or writes through the read pool and brings
`SQLITE_BUSY` back. Implement `scs.CtxStore` against the app's existing pools — **`FindCtx` on the read pool,
`CommitCtx`/`DeleteCtx` on the write pool**, with the embedded plain
`Find`/`Commit`/`Delete` methods delegating via `context.Background()`
(`CtxStore` embeds `Store`, so both sets are required). Two MUSTs make it a session
store:

- **`FindCtx` treats expired rows as not found** (`WHERE token = ? AND expiry > ?`) —
  scs performs no expiry check of its own, so a store that returns expired rows keeps
  those sessions alive and every request refreshes their idle deadline, silently
  disabling `IdleTimeout`. `expiry` is an INTEGER holding Unix time on both sides of that
  comparison: a bound `time.Time` is stored as text in the local zone, and compares
  wrong everywhere but UTC.
- **`DeleteCtx` empties the row — `data = NULL`, a nullable column — and keeps it.
  `CommitCtx` changes neither an emptied row
  nor an expired one, in the statement that writes** (`… ON CONFLICT (token) DO UPDATE …
  WHERE sessions.data IS NOT NULL AND sessions.expiry > ?`)**, and `FindCtx` finds no
  emptied row.** A request still in flight when a logout or `RenewToken` lands commits
  the session it loaded, and against a row that is gone that commit is an insert: the
  logged-out cookie is signed in again, for whoever kept one slow request open. A check
  in a statement of its own loses the same race, and a logout that finds its row expired
  empties nothing. The emptied row's `expiry` is now plus `Lifetime`; nothing loaded
  under the token is valid after that. And the janitor deletes a row an hour past its
  expiry, never sooner ([go-background-work.md](go-background-work.md)): before that a
  late commit would insert it again.

## Login / logout flow

```
GET  /login          → form (plain HTML form; works without htmx)
POST /login          → verify → sessions.RenewToken(ctx) → put user ID → 303 to /
POST /logout         → sessions.Destroy(ctx) → 303 to /login
```

MUST rules:

1. **`RenewToken` on login and password change** — prevents session fixation.
   Logout calls `Destroy` (the flow above), which ends the session. **A password change
   asks for the current password** — a route that checks a password, so rate limited
   below — **and it ends the user's other sessions, as a reset ends all of them:** the
   user row carries a counter, a session stores its value at login and at its own password
   change, and *Machine tokens* rule 6's lookup finds no user under a session whose value
   differs: the middleware signs it out, and a socket's re-check closes it. **Every
   statement that sets a new password moves the counter, and every statement a password or a
   reset link allowed names the value its request loaded** (`… WHERE id = ? AND
   password_version = ?`): no row changed is a refusal.
2. **No user enumeration.** Unknown email and wrong password return the identical
   message and take the same time: on unknown user, verify against a precomputed dummy
   hash anyway. Registration by email address answers a taken and a free address the
   same, in the same time, and the mail says which; a public name cannot be hidden, and the rate limit
   bounds the probing.
3. **Redirects are `303 See Other`.** For htmx-initiated logins from a fragment, send
   `HX-Redirect` instead (full page must change after auth transitions — never swap a
   logged-in fragment into a logged-out page).
4. **`requireAuth` middleware** on protected routes: no user ID in session → a
   fragment request (`isFragment`, [htmx-server-rendering.md](htmx-server-rendering.md))
   gets a **200 with `HX-Redirect: /login` instead of the 303** — `fetch` would
   follow a 303 transparently and swap the login page *into* the fragment target
   (rule 3). Every other request gets the 303: a boosted one swaps the whole
   `<body>`, so the login page lands whole, under its own URL.
   Handlers read the user with `userFrom(r.Context())`; the middleware put it there.
   The rule-3 and rule-4 responses differ by `HX-Request-Type` but bypass the render
   helper, so they MUST `Add` the same `Vary: HX-Request-Type` header themselves —
   an un-`Vary`'d variant is cacheable against the wrong mode.

## Password hashing: argon2id (`golang.org/x/crypto/argon2`)

OWASP-recommended parameters:

```go
argon2.IDKey(password, salt, 2, 19*1024, 1, 32) // t=2, m=19 MiB, p=1, 32-byte key
```

- 16-byte random salt from `crypto/rand` per password.
- Store as a PHC string (`$argon2id$v=19$m=19456,t=2,p=1$<salt>$<hash>`) so parameters
  can be upgraded later; rehash-on-login when stored params are below current baseline.
- Compare with `subtle.ConstantTimeCompare`.

## Rate limiting auth endpoints (`golang.org/x/time/rate`)

Login, registration, password-reset, and any other route that checks a password MUST be
rate limited per client IP: a
`map[string]*rate.Limiter` guarded by a mutex, e.g. `rate.NewLimiter(rate.Every(3*time.Second), 5)`,
with a janitor evicting idle entries. Over limit → `429` with `Retry-After`.

The map key is the client IP — an IPv6 address, after `Unmap`, cut to its /64
(`netip.PrefixFrom(addr, 64).Masked()`), because one subscriber holds all of it and is
otherwise a new client on every guess. Getting the IP is one short function, because the
deployment contract already did the hard part:

```go
// clientIP trusts X-Forwarded-For because nothing but the proxy can reach this
// app, and the proxy overwrote whatever the client sent
// (operations/web-application.md). The header holds one address, not a chain —
// nothing to split, no last-hop rule to get wrong.
func clientIP(r *http.Request) string {
	if ip := r.Header.Get("X-Forwarded-For"); ip != "" {
		return ip
	}
	host, _, err := net.SplitHostPort(r.RemoteAddr) // no proxy in front: dev
	if err != nil {
		return r.RemoteAddr
	}
	return host
}
```

## Password reset (when needed)

Single-use token from `rand.Text()`, **store only its SHA-256 hash**, 1-hour expiry,
deleted with the user's other reset tokens in the transaction that writes the new hash,
a password change's too; the plaintext token goes in the emailed link once. A known and an
unknown address get the same answer to the request, and a used, an expired and a
never-issued link the same answer to the link (no enumeration). A successful reset ends
that user's sessions (rule 1).

**How that link leaves the building is [go-email.md](go-email.md)**: the base URL it is
built from, the outbox it waits in, and why nothing is sent inside the handler.

**Deleting the account is the case no session store can answer**, because the session row
names no user: [go-data-deletion.md](go-data-deletion.md) puts the check in the middleware
that resolves the credential.

## Machine tokens (when a program is the user)

A CLI or a script cannot hold a session cookie: sessions idle out, renew on login, and
ride on a cookie the browser attaches by itself. Give a program its own credential.

```go
// NewToken returns the secret to show the caller once, and the hash to store.
// rand.Text cannot fail: crypto/rand crashes the program rather than return an error.
func NewToken() (secret, hash string) {
	secret = rand.Text() // 26 base32 chars, 130 bits, nothing to escape
	sum := sha256.Sum256([]byte(secret))
	return secret, hex.EncodeToString(sum[:])
}
```

MUST rules:

1. **The token is `rand.Text()`, and only its SHA-256 is stored** — the same rule as a
   reset token above, for the same reason: a leaked database then leaks nothing usable.
2. **SHA-256 is the right hash here, and argon2id is not.** This token is 130 bits of
   randomness; nothing brute-forces that, and argon2id would spend 19 MiB of memory on
   every API request.
3. **Creating one asks for the password, on a rate-limited route, and shows the secret
   once,** in the answer to that request: a flash would store it.
4. **The token travels in `Authorization: Bearer <secret>`.** MUST NOT accept it
   in a query string: URLs land in access logs, in `Referer` headers, and in
   shell history.
5. **Look it up by hash** (`WHERE token_hash = ?`, indexed and unique), and let
   the row carry a human label and a `last_used_at` the handler touches. Both
   exist so a person can tell which token to revoke. **Revocation is a DELETE.**
6. **One function resolves either credential** — a bearer token or a session —
   and puts the same user *row* in the request context, never just the id it came
   from. Everything downstream stops
   caring which one arrived. A long-lived connection's re-check makes the same lookup
   but only reads (*Re-resolving a long-lived connection* below).

   What it MUST NOT do is decide the answer when there is no user, because the
   two surfaces disagree. A browser is sent to the sign-in page; a program gets
   `401` and a body it can read, since a `303` to a login form is `200` of HTML
   that reads as success to anything checking only the status. Split the
   middleware, not the lookup. And tell the two failures apart: **nothing
   presented** is a signed-out reader, while **a token presented and refused** is
   `401` on both surfaces: a login form would hide the revocation.

**A machine token needs no CSRF defense, and gets none.** `http.CrossOriginProtection`
allows requests that carry no `Sec-Fetch-Site` and no `Origin`, which is every
non-browser client. That is no loophole: CSRF is an attack on
*ambient* authority, and a browser never attaches a bearer token by itself.

## Re-resolving a long-lived connection

A WebSocket made its one request at the handshake, so a logout, a password change or
reset, a revoked token or a deleted account never reaches it. It keeps the credential its
handshake presented and re-resolves it; [wasm-client.md](wasm-client.md) rule 6 says
what it may do and when it closes. This is tier 1, as that rule is:

1. **At least every 10 seconds, unprompted, under a deadline inside the interval,** it
   re-runs *Machine tokens* rule 6's lookup, to the user's row (a token by its hash), and
   [go-authorization.md](go-authorization.md)'s access check for everything the socket
   still holds, admitted at the handshake or since, the read made as that user, wherever
   the membership is held.
2. **It only reads.** No `last_used_at` touch, no `Destroy`.
3. **A session's lookup is scs `Load` of the kept token into the app's own context**,
   where a deleted session comes back empty. Never `context.WithoutCancel(r.Context())`:
   it keeps the request's values, and `Load` returns the session data a context already
   holds, unchanged — the handshake's copy, alive after a logout deleted it.
4. **A cookie the server keeps no record of**, naming no user and reaching none, has
   nothing to revoke: its lookup checks only an expiry the cookie carries, if any. Its
   access check is rule 1's all the same: everything the socket still holds. Any
   other cookie is re-resolved like a session.
5. **Only an HTTP request commits the session**, so under `IdleTimeout` a user who only
   uses the socket is closed at the idle window: `Load` finds the row expired.

## CSRF

[go-http-server.md](go-http-server.md) owns it: `http.CrossOriginProtection`, no per-form
tokens. `SameSite=Lax` on the session cookie is the second, independent layer.

## Facts verified (2026-10-31)

- scs v2.9.0: `Load` returns a context that already holds session data unchanged
  (`data.go` line 55). Executed: after `Store.Delete`,
  `Load(context.WithoutCancel(r.Context()), token)` still found the user and
  `Load(context.Background(), token)` did not; a session re-`Load`ed every 100 ms and
  never committed was gone at the 200 ms `IdleTimeout`, Go 1.27.3
