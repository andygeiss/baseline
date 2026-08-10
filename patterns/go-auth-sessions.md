# Pattern: Authentication & Sessions (Go)

**Last verified: 2026-08-10 · Sessions: `alexedwards/scs/v2` (v2.9.0) · Hashing: argon2id**

Server-side sessions: the cookie carries only a random token; all session data lives in
SQLite. Nothing is decrypted client-side, nothing to key-rotate, revocation is a DELETE.

## Session manager

Constructed in `main.go`, injected like every other dependency:

```go
sessions := scs.New()
sessions.Lifetime = 12 * time.Hour
sessions.IdleTimeout = 2 * time.Hour
sessions.Cookie.Secure = true      // Secure + HttpOnly + SameSite=Lax defaults verified below
sessions.Cookie.HttpOnly = true
sessions.Cookie.SameSite = http.SameSiteLaxMode
sessions.Store = store.NewSessionStore(readDB, writeDB) // see below
```

`sessions.LoadAndSave` wraps the mux (see [go-http-server.md](go-http-server.md)
middleware chain).

⚠️ **Do not use the bundled `sqlite3store`** — it takes a single `*sql.DB`, and this
baseline's SQLite setup requires two ([go-sqlite.md](go-sqlite.md)): `LoadAndSave`
calls `Find` on every request, so a single-pool store either routes all reads through
the one-connection write pool (serializing the entire app) or writes through the
uncapped read pool (reintroducing `SQLITE_BUSY`). `scs.Store` is a three-method
interface (`Find`, `Commit`, `Delete`); implement it (~40 lines) against the app's
existing pools — **`Find` on the read pool, `Commit`/`Delete` on the write pool**.
**`Find` MUST treat expired rows as not found** (`WHERE token = ? AND expiry > ?`) —
scs performs no expiry check of its own, so a store that returns expired rows keeps
those sessions alive and every request refreshes their idle deadline, silently
disabling `IdleTimeout`. The janitor only reclaims disk; `Find` enforces expiry. A ticker goroutine deletes
expired rows every few minutes (owned lifecycle: stopped on shutdown — see the
background-work pattern in [go-http-server.md](go-http-server.md)).

## Login / logout flow

```
GET  /login          → form (plain HTML form; works without htmx)
POST /login          → verify → sessions.RenewToken(ctx) → put user ID → 303 to /
POST /logout         → sessions.Destroy(ctx) → 303 to /login
```

MUST rules:

1. **`RenewToken` on every privilege change** (login, logout, password change) —
   prevents session fixation.
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
with a janitor evicting idle entries. Over limit → `429` with `Retry-After`. Behind the
reverse proxy, the client IP comes from the proxy-set header — trust it only from the
proxy's address (see [operations/web-application.md](../operations/web-application.md)).

## Password reset (when needed)

Single-use token: 32 random bytes, **store only its SHA-256 hash**, 1-hour expiry,
deleted on use; the plaintext token goes in the emailed link once. A used or expired
token and an unknown email produce the same response (no enumeration). Consider
sessions of that user revoked on successful reset.

## CSRF

Handled globally by `http.CrossOriginProtection`, not per-form tokens — see
[go-http-server.md](go-http-server.md). Session cookies with `SameSite=Lax` are the
second, independent layer.
