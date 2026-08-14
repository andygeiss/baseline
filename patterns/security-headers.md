# Pattern: Security Headers

**Last verified: 2026-08-14**

This document owns every security header the app sends. One middleware sets
them, one policy string defines the CSP, and no other document restates either
— when a feature needs a policy change, it changes here and links back.

That single-owner rule exists because the policy is a whole-app fact. A CSP
copied into the CSS, htmx, and PWA documents drifts: one of the copies is
always the stale one, and a stale CSP either blocks a working feature or
advertises protection the app no longer has.

## The middleware

`secureHeaders` in `internal/app/middleware.go`, third in the chain from the
outside ([go-http-server.md](go-http-server.md) owns the composition):

```go
// csp is the whole policy, built once. It is a constant: a policy assembled
// per request is a policy that can differ per request, which is a bug.
const csp = "default-src 'self'; " +
	"img-src 'self' data:; " +
	"frame-ancestors 'none'; " +
	"base-uri 'none'; " +
	"form-action 'self'"

func (a *App) secureHeaders(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		h := w.Header()
		h.Set("Content-Security-Policy", csp)
		h.Set("Strict-Transport-Security", "max-age=31536000")
		h.Set("X-Content-Type-Options", "nosniff")
		h.Set("Referrer-Policy", "same-origin")
		next.ServeHTTP(w, r)
	})
}
```

Headers are set **before** `next.ServeHTTP`. A header written after the handler
has called `WriteHeader` is silently dropped — the status line is already on
the wire.

## The policy, directive by directive

| Directive | Value | Why |
|---|---|---|
| `default-src` | `'self'` | The fallback for every fetch directive that has one — `script-src`, `style-src`, `font-src`, `connect-src`, `manifest-src`. Same-origin only, so htmx, `app.css`, a self-hosted font, and the manifest all load, and nothing third-party does. |
| `img-src` | `'self' data:` | `data:` is **required**: mask icons are `data:image/svg+xml` URLs ([css-icons.md](css-icons.md)), and CSS image loads are checked against `img-src`. Without it every icon in the app disappears. |
| `frame-ancestors` | `'none'` | Clickjacking. Has no `default-src` fallback, so it MUST be written out. |
| `base-uri` | `'none'` | Has no fallback either. An injected `<base href="https://evil.example/">` re-points every root-relative URL on the page — including `/static/js/htmx.min.js`. The app never uses `<base>`, so `'none'` costs nothing. |
| `form-action` | `'self'` | No fallback. Stops an injected form from posting credentials off-origin. Every form in the app targets its own origin. |

MUST NOT add `'unsafe-inline'` or `'unsafe-eval'` to any directive. Both undo
the reason the policy exists, and no baseline pattern needs either — see the
feature map below.

## What each feature needs from the policy

The policy above already covers every pattern in this baseline. This table is
the record of *why* it is sufficient, so a future feature can be checked
against it:

| Feature | Needs | Covered by |
|---|---|---|
| htmx | `script-src 'self'` | `default-src`. htmx is self-hosted and there is no inline JS ([stack/htmx.md](../stack/htmx.md)). |
| htmx indicators | nothing | htmx would inject an inline `<style>`, which `default-src 'self'` blocks. The canonical layout sets `"includeIndicatorStyles":false` and `app.css` owns those rules instead ([stack/css.md](../stack/css.md)). |
| Mask icons | `img-src data:` | The one directive the default policy would get wrong. |
| Self-hosted font | nothing | Same-origin `.woff2` ([css-typography.md](css-typography.md)). A third-party font host would need a `font-src` hole — which is one reason there isn't one. |
| Web app manifest | nothing | `manifest-src` falls back to `default-src`, and the manifest is same-origin ([pwa.md](pwa.md)). |
| View transitions, CSS motion | nothing | Pure CSS ([css-motion.md](css-motion.md)). |
| Forms | `form-action 'self'` | Already in the policy. |

## The other three headers

- **`Strict-Transport-Security: max-age=31536000`** — one year. Browsers ignore
  it over plain HTTP, so it is harmless in dev and needs no environment fork.
  Add `; includeSubDomains` only when you control every subdomain, including
  ones that don't exist yet; a plain-HTTP subdomain stops working the moment you
  do. MUST NOT add `preload` casually — it hands the domain to a browser-shipped
  list, and removal takes months.
- **`X-Content-Type-Options: nosniff`** — the browser trusts the declared
  `Content-Type` instead of guessing. Cheap, and it closes the "SVG treated as
  HTML" class of bug.
- **`Referrer-Policy: same-origin`** — outbound requests carry no referrer at
  all; same-origin ones carry the full URL. Paths in this app can name a
  resource (`/games/{id}`), and that is nobody else's business.

## What is deliberately not here

- **`X-Frame-Options`** — superseded by `frame-ancestors`, which every browser
  in the CSS Baseline support window honors. Two headers saying the same thing
  is one more to keep in sync.
- **`Permissions-Policy`** — it disables browser APIs that only JavaScript can
  call, and this baseline ships no JavaScript ([stack/html.md](../stack/html.md)).
  A header defending against code that cannot exist is ceremony.
- **`object-src 'none'`** — `default-src 'self'` already denies cross-origin
  plugin content, and the app embeds no plugin content at all.
- **CSP reporting (`report-to`)** — needs an endpoint to receive reports and
  somebody to read them. Add it when a real policy question needs real data,
  not by default.
- **Cookie attributes.** `Secure`, `HttpOnly`, and `SameSite=Lax` are security
  settings, but this middleware does not set them — the session manager does.
  [go-auth-sessions.md](go-auth-sessions.md) owns them, and the `SameSite=Lax`
  cookie is the independent second layer behind the stdlib CSRF protection in
  [go-http-server.md](go-http-server.md).

## Static assets carry none of this

`/static/` sits outside the middleware chain by design
([go-http-server.md](go-http-server.md) routing), so asset responses get no CSP
and no `nosniff`. That is safe here for one reason: **nothing under `/static/`
is user-supplied.** Every asset is compiled into the binary through `embed.FS`
and reviewed like code, and `FileServerFS` sets the `Content-Type` from the
extension. CSP does its work on the HTML documents that reference the assets,
which is where an injection would have to land.

The day the app serves user-uploaded files, they MUST NOT be served from this
path or this handler — that is a different route with its own `Content-Type`
and `Content-Disposition` rules.

## Testing

One table test pins the whole contract, so a future edit to the middleware
cannot quietly drop a header:

```go
func TestSecureHeaders(t *testing.T) {
	want := map[string]string{
		"Content-Security-Policy":   csp,
		"Strict-Transport-Security": "max-age=31536000",
		"X-Content-Type-Options":    "nosniff",
		"Referrer-Policy":           "same-origin",
	}

	rec := httptest.NewRecorder()
	h := (&App{}).secureHeaders(http.HandlerFunc(func(http.ResponseWriter, *http.Request) {}))
	h.ServeHTTP(rec, httptest.NewRequest("GET", "/", nil))

	for name, value := range want {
		if got := rec.Header().Get(name); got != value {
			t.Errorf("%s = %q, want %q", name, got, value)
		}
	}

	// Not a tautology, unlike the line above: this one fails if somebody
	// "tidies" the policy and takes the mask icons down with it.
	if !strings.Contains(csp, "img-src 'self' data:") {
		t.Error("CSP lost img-src 'self' data: — every mask icon is now blocked")
	}
}
```

Checking the CSP against the `csp` constant only proves the header is *sent* — a
string compared with itself says nothing about its content. The explicit
`img-src` check is the part that has teeth, because that directive is the one a
future tightening pass would remove without knowing what it costs. The rest of
the policy is reviewed against the feature map above, and the end-to-end proof
is the reference implementation rendering its icons.

## Anti-patterns

- ❌ A security-headers middleware package (unrolled/secure, gorilla/handlers) —
  the whole thing is nine lines of stdlib.
- ❌ Building the CSP per request from config. A policy that varies is a policy
  nobody can review; if dev genuinely needs a different one, that is a second
  constant chosen at startup, not string concatenation in the request path.
- ❌ `'unsafe-inline'` to make one inline `<style>` or `onclick` work. Move the
  rule into `app.css`; the attribute was already banned by
  [stack/html.md](../stack/html.md).
- ❌ Loosening `img-src` to `*` or `https:` for one avatar host. Proxy the image
  through the app instead — it keeps the policy tight and stops the third party
  from seeing your users' IP addresses.
