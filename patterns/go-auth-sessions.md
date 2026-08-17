# Pattern: Authentication & Sessions (Go)

**Tier 1** (safety — never waived) · Last verified: 2026-08-15 · Sessions: `alexedwards/scs/v2` (v2.9.0) · Hashing: argon2id

The cookie flags, `RenewToken` and `Destroy`, the argon2id parameters, the
no-enumeration rule, the rate limits, `FindCtx` treating expired rows as not found, and
every machine-token rule are what the checklists file under *Security*. The scs wiring,
the store implementation, and the redirect mechanics are tier 2 — shape, waived only on
the record.

Server-side sessions: the cookie carries only a random token; all session data lives in
SQLite. Nothing is decrypted client-side, nothing to key-rotate, revocation is a DELETE.

## Session manager

Constructed in `main.go`, injected like every other dependency:

```go
sessions := scs.New()
sessions.Lifetime = 12 * time.Hour
sessions.IdleTimeout = 2 * time.Hour
sessions.Cookie.Secure = cfg.Env == "prod" // TLS is in front only in production — see below
sessions.Cookie.HttpOnly = true            // set both explicitly: scs defaults HttpOnly=true
sessions.Cookie.SameSite = http.SameSiteLaxMode // and SameSite=Lax — don't "simplify" these away
sessions.Store = store.NewSessionStore(readDB, writeDB) // see below
```

**`Secure` follows `ENV`, and that is not a weakened rule.** The binary only ever
speaks plain HTTP; a proxy adds TLS in front of it
([project-types/web-application.md](../project-types/web-application.md)). A
client returns a `Secure` cookie only over a connection it counts as secure, and
clients make exactly one exception for plain HTTP: **loopback**. `curl` returns
the cookie over `http://localhost` and `http://127.0.0.1`, and so does any
browser following the secure-contexts rule, where loopback counts as trustworthy
by definition. A flat `Secure = true` therefore survives on a laptop and hides
the problem.

Nothing past loopback gets that exception. Point a phone at the LAN address to
check the mobile-first layout this baseline mandates
([css-layout.md](css-layout.md)), reach the app in a container by its
hostname, or put a staging box on plain HTTP, and the cookie is not even stored
— nobody signs in, and no page behind the sign-in form can be reached at all.
`ENV` is the one setting that knows whether TLS is in front, because the
deployment sets it ([go-config.md](go-config.md)) — so `Secure` in production,
off in dev. `HttpOnly` and `SameSite=Lax` never fork: they cost nothing anywhere.

`sessions.LoadAndSave` wraps the mux (see [go-http-server.md](go-http-server.md)
middleware chain).

⚠️ `scs.New()` ships a default in-memory store and has already started its
cleanup goroutine (one tick per minute, forever) by the time the `Store`
assignment above orphans it. Accepted as-is — the one sanctioned exception to
the goroutine-ownership rule in [stack/go.md](../stack/go.md): the tick is a
no-op on the empty memstore, scs offers no store-injecting constructor, and
`StopCleanup()` at construction time is racy (the stop channel is created
inside the goroutine itself). Do not "fix" this with a `StopCleanup` call.

⚠️ **Do not use the bundled `sqlite3store`** — it takes a single `*sql.DB`, and this
baseline's SQLite setup requires two ([go-sqlite.md](go-sqlite.md)): `LoadAndSave`
calls `Find` on every request, so a single-pool store either routes all reads through
the one-connection write pool (serializing the entire app) or writes through the
multi-connection read pool (reintroducing `SQLITE_BUSY`). Implement `scs.CtxStore`
(~50 lines) against the app's existing pools — **`FindCtx` on the read pool,
`CommitCtx`/`DeleteCtx` on the write pool**, with the embedded plain
`Find`/`Commit`/`Delete` methods delegating via `context.Background()`
(`CtxStore` embeds `Store`, so both sets are required). scs passes the request
context through to the `Ctx` variants automatically, so the per-request session
queries honor cancellation — the context rule in [go-sqlite.md](go-sqlite.md).
**`FindCtx` MUST treat expired rows as not found** (`WHERE token = ? AND expiry > ?`) —
scs performs no expiry check of its own, so a store that returns expired rows keeps
those sessions alive and every request refreshes their idle deadline, silently
disabling `IdleTimeout`. The janitor only reclaims disk; `Find` enforces expiry. A ticker goroutine deletes
expired rows every few minutes (owned lifecycle: stopped on shutdown — see
[go-background-work.md](go-background-work.md)).

## Login / logout flow

```
GET  /login          → form (plain HTML form; works without htmx)
POST /login          → verify → sessions.RenewToken(ctx) → put user ID → 303 to /
POST /logout         → sessions.Destroy(ctx) → 303 to /login
```

MUST rules:

1. **`RenewToken` on login and password change** — prevents session fixation.
   Logout calls `Destroy` (the flow above), which removes the session entirely.
2. **No user enumeration.** Unknown email and wrong password return the identical
   message and take the same time: on unknown user, verify against a precomputed dummy
   hash anyway.
3. **Redirects are `303 See Other`.** For htmx-initiated logins from a fragment, send
   `HX-Redirect` instead (full page must change after auth transitions — never swap a
   logged-in fragment into a logged-out page).
4. **`requireAuth` middleware** on protected routes: no user ID in session → plain
   requests get a 303 to `/login`; htmx requests get a **200 with
   `HX-Redirect: /login` instead of the 303** — the XHR would follow a 303
   transparently and swap the login page *into* the fragment target (rule 3).
   Handlers read the user from the request context, placed there by the middleware.
   The rule-3 and rule-4 responses differ by `HX-Request` but bypass the render
   helper, so they MUST `Add` the same `Vary: HX-Request, HX-Boosted` headers
   themselves ([htmx-server-rendering.md](htmx-server-rendering.md)) — an
   un-`Vary`'d variant is cacheable against the wrong mode.

## Password hashing: argon2id (`golang.org/x/crypto/argon2`)

OWASP-recommended parameters (re-check when re-verifying this document):

```go
argon2.IDKey(password, salt, 2, 19*1024, 1, 32)  // t=2, m=19 MiB, p=1, 32-byte key
```

- 16-byte random salt from `crypto/rand` per password.
- Store as a PHC string (`$argon2id$v=19$m=19456,t=2,p=1$<salt>$<hash>`) so parameters
  can be upgraded later; rehash-on-login when stored params are below current baseline.
- Compare with `subtle.ConstantTimeCompare`.
- bcrypt (cost ≥ 12) is the acceptable fallback; nothing weaker, ever.

## Rate limiting auth endpoints (`golang.org/x/time/rate`)

Login, registration, and password-reset MUST be rate limited per client IP: a
`map[string]*rate.Limiter` guarded by a mutex, e.g. `rate.NewLimiter(rate.Every(3*time.Second), 5)`,
with a janitor evicting idle entries. Over limit → `429` with `Retry-After`.

The map key is the client IP, and getting it is one short function because the
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

The `RemoteAddr` fallback is not decoration: with no proxy the header is empty,
and a limiter keyed on `""` throttles every visitor as if they were one.

## Password reset (when needed)

Single-use token: 32 random bytes, **store only its SHA-256 hash**, 1-hour expiry,
deleted on use; the plaintext token goes in the emailed link once. A used or expired
token and an unknown email produce the same response (no enumeration). Consider
sessions of that user revoked on successful reset.

## Machine tokens (when a program is the user)

A CLI or a script cannot hold a session cookie. Sessions are built for a browser:
they idle out in two hours, they renew on login, and the cookie is ambient
authority the browser attaches by itself. Give a program its own credential
instead.

```go
// NewToken returns the secret to show the caller once, and the hash to store.
func NewToken() (secret, hash string, err error) {
	b := make([]byte, 32)
	if _, err := rand.Read(b); err != nil { // crypto/rand
		return "", "", fmt.Errorf("token: %w", err)
	}
	secret = base64.RawURLEncoding.EncodeToString(b)
	sum := sha256.Sum256([]byte(secret))
	return secret, hex.EncodeToString(sum[:]), nil
}
```

MUST rules:

1. **Store the SHA-256, never the token** — the same rule as a reset token
   above, for the same reason: a leaked database then leaks nothing usable.
2. **SHA-256 is the right hash here, and argon2id is not.** A password is short
   and guessable, so the slow hash buys the time to notice a breach. This token
   is 32 random bytes; nothing brute-forces that, and argon2id would spend 19 MiB
   of memory on every single API request to protect a secret that needs no
   protecting.
3. **Show the secret once,** at creation, and never again. There is nothing to
   show later — the server kept only the hash. Replacing a lost token is
   creating a new one and deleting the old.
4. **The token travels in `Authorization: Bearer <secret>`.** MUST NOT accept it
   in a query string: URLs land in access logs, in `Referer` headers, and in
   shell history.
5. **Look it up by hash** (`WHERE token_hash = ?`, indexed and unique), and let
   the row carry a human label and a `last_used_at` the handler touches. Both
   exist so a person can tell which token to revoke. **Revocation is a DELETE.**
6. **One function resolves either credential** — a bearer token or a session —
   and puts the same user in the request context. Everything downstream stops
   caring which one arrived.

   What it MUST NOT do is decide the answer when there is no user, because the
   two surfaces disagree. A browser is sent to the sign-in page; a program gets
   `401` and a body it can read, since a `303` to a login form is `200` of HTML
   that reads as success to anything checking only the status. Split the
   middleware, not the lookup. And tell the two failures apart: **nothing
   presented** is a signed-out reader, while **a token presented and refused** is
   `401` on both surfaces — quietly treating a revoked token as "signed out"
   hides the revocation behind a login form.

**A machine token needs no CSRF defense, and gets none.** `http.CrossOriginProtection`
allows requests that carry no `Sec-Fetch-Site` and no `Origin`, which is every
non-browser client, so the CLI is not blocked. That is correct rather than a
loophole: CSRF is an attack on *ambient* authority, and a browser never attaches
a bearer token by itself. The cookie half of the app is still covered.

## CSRF

Handled globally by `http.CrossOriginProtection`, not per-form tokens — see
[go-http-server.md](go-http-server.md). Session cookies with `SameSite=Lax` are the
second, independent layer.
