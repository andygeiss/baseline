# Pattern: Security Headers

**Tier 1** (safety — never waived) · Last verified: 2026-08-14

The four headers, every directive in the policy, and the ban on `'unsafe-inline'` and
`'unsafe-eval'` are tier 1 wherever a checklist files them. The single-owner rule and
the anti-patterns below are tier 2.

This document owns every security header the app sends. One middleware sets them, one
policy string defines the CSP, and no other document restates either — a CSP copied into
the CSS, htmx, and PWA documents drifts, and the stale copy either blocks a working
feature or advertises protection the app no longer has. When a feature needs a policy
change, it changes here and links back.

## The middleware

`secureHeaders` in `internal/app/middleware.go`, third in the chain from the outside
([go-http-server.md](go-http-server.md) owns the composition):

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

Headers are set **before** `next.ServeHTTP`. A header written after the handler has
called `WriteHeader` is silently dropped — the status line is already on the wire.

## The policy, directive by directive

| Directive | Value | Why |
|---|---|---|
| `default-src` | `'self'` | The fallback for every fetch directive that has one — `script-src`, `style-src`, `font-src`, `connect-src`, `manifest-src`. Same-origin only, so htmx, `app.css`, a self-hosted font, and the manifest all load, and nothing third-party does. |
| `img-src` | `'self' data:` | `data:` is **required**: mask icons are `data:image/svg+xml` URLs ([css-icons.md](css-icons.md)), and CSS image loads are checked against `img-src`. Without it every icon in the app disappears. |
| `frame-ancestors` | `'none'` | Clickjacking. Has no `default-src` fallback, so it MUST be written out. |
| `base-uri` | `'none'` | No fallback either. An injected `<base href="https://evil.example/">` re-points every root-relative URL on the page, including `/static/js/htmx.min.js`. The app never uses `<base>`. |
| `form-action` | `'self'` | No fallback. Stops an injected form from posting credentials off-origin. |

MUST NOT add `'unsafe-inline'` or `'unsafe-eval'` to any directive. Both undo the reason
the policy exists, and no baseline pattern needs either.

**Every feature in this baseline is already covered.** htmx, its indicators, self-hosted
fonts, the web app manifest, view transitions, and forms all need nothing beyond the five
directives above; mask icons need `img-src data:`, and that is the only directive a
default policy would get wrong. The feature-by-feature record is in
[VERIFICATION.md](../VERIFICATION.md) *Why the CSP is what it is* — read it when adding a
feature that loads something new, and add a row when the policy changes.

## The other three headers

- **`Strict-Transport-Security: max-age=31536000`** — one year. Browsers ignore it over
  plain HTTP, so it needs no environment fork. Add `; includeSubDomains` only when you
  control every subdomain including ones that don't exist yet, since a plain-HTTP
  subdomain stops working the moment you do. MUST NOT add `preload` casually — it hands
  the domain to a browser-shipped list, and removal takes months.
- **`X-Content-Type-Options: nosniff`** — the browser trusts the declared `Content-Type`
  instead of guessing, closing the "SVG treated as HTML" class of bug.
- **`Referrer-Policy: same-origin`** — outbound requests carry no referrer; same-origin
  ones carry the full URL. Paths here name resources (`/games/{id}`), which is nobody
  else's business.

## What is deliberately not here

**MUST NOT add `X-Frame-Options`, `Permissions-Policy`, `object-src`, or CSP reporting.**
Each is superseded, unreachable without JavaScript, already covered by `default-src`, or
needs an endpoint nobody reads. The reasoning per header is in
[VERIFICATION.md](../VERIFICATION.md) *Why the CSP is what it is*.

**Cookie attributes are not here either.** `Secure`, `HttpOnly`, and `SameSite=Lax` are
set by the session manager — [go-auth-sessions.md](go-auth-sessions.md) owns them, and
that `SameSite=Lax` cookie is the independent second layer behind the stdlib CSRF
protection in [go-http-server.md](go-http-server.md).

## Static assets carry none of this

`/static/` sits outside the middleware chain by design
([go-http-server.md](go-http-server.md) routing), so asset responses get no CSP and no
`nosniff`. That is safe for one reason: **nothing under `/static/` is user-supplied.**
Every asset is compiled into the binary through `embed.FS` and reviewed like code,
`FileServerFS` sets the `Content-Type` from the extension, and CSP does its work on the
HTML documents that reference the assets — which is where an injection would land.

The day the app serves user-uploaded files, they MUST NOT be served from this path or
this handler: that is a different route, and its `Content-Type` and `Content-Disposition`
rules are [go-file-uploads.md](go-file-uploads.md).

## Testing

One table test pins the whole contract, so a future edit cannot quietly drop a header:

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

Comparing the CSP against the `csp` constant only proves the header is *sent*. The
explicit `img-src` check is the part with teeth, because that directive is the one a
future tightening pass would remove without knowing its cost. The rest of the policy is
reviewed against the feature map above, and the end-to-end proof is the reference
implementation rendering its icons.

## Anti-patterns

- ❌ A security-headers middleware package (unrolled/secure, gorilla/handlers) — the
  whole thing is nine lines of stdlib.
- ❌ Building the CSP per request from config. A policy that varies is a policy nobody
  can review; if dev genuinely needs a different one, that is a second constant chosen
  at startup, not string concatenation in the request path.
- ❌ `'unsafe-inline'` to make one inline `<style>` or `onclick` work. Move the rule into
  `app.css`; the attribute was already banned by [stack/html.md](../stack/html.md).
- ❌ Loosening `img-src` to `*` or `https:` for one avatar host. Proxy the image through
  the app — it keeps the policy tight and stops the third party from seeing your users'
  IP addresses.
