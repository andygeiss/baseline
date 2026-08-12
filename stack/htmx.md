# Stack: htmx

**Last verified: 2026-08-12 · Pinned: htmx 2.0.10** (see [VERSIONS.md](../VERSIONS.md))

htmx is the *only* script on the page. It turns HTML into the application protocol:
any element can issue HTTP requests, the server answers with HTML, htmx swaps it in.

⚠️ **htmx 4.x is in beta (fetch-based rewrite, breaking changes). MUST NOT be used.**
Stay on 2.x until this baseline says otherwise.

## Setup

- **Self-host.** Vendor `htmx.min.js` into the project (`web/static/js/htmx.min.js`)
  and serve via `embed.FS`. MUST NOT load from a CDN in production (availability,
  privacy, CSP, supply chain).
- Single tag before `</body>`: `<script src="/static/js/htmx.min.js?v={{version}}"></script>`
  (version-busted like all static assets — see [patterns/go-performance.md](../patterns/go-performance.md)).
- No extensions unless a pattern document mandates one. `hx-boost` on `<body>` is the
  default starting point for smooth navigation.

## Core attribute set (prefer these, in this order)

| Attribute | Use |
|---|---|
| `hx-get` / `hx-post` | Issue request. GET reads, POST mutates — the only two verbs with a plain-form fallback. |
| `hx-target` | CSS selector to swap into. Default is the triggering element — usually set this explicitly. |
| `hx-swap` | `innerHTML` (default), `outerHTML` for self-replacing fragments. `transition:false` opts a rapid-fire swap out of view transitions ([patterns/css-motion.md](../patterns/css-motion.md)). |
| `hx-trigger` | Only when the default event is wrong (e.g. `input changed delay:300ms` for search). |
| `hx-push-url` | `true` on navigation-like GETs so the URL bar and back button stay honest. |
| `hx-indicator` | Always give requests >100ms a visible indicator (CSS `.htmx-request`). |
| `hx-boost` | On `<body>`: upgrades plain links/forms to AJAX with graceful fallback. |
| `hx-confirm` | For destructive actions. |

Attributes not listed here (e.g. `hx-on`, `hx-vals` with JS expressions) SHOULD be
avoided — if you need them, the design is probably drifting toward client-side logic.

## Rules

1. **Progressive enhancement is mandatory.** Every htmx interaction MUST degrade to a
   working plain `<a>`/`<form>`. Build the no-htmx version first, then enhance.
2. **Server returns HTML, never JSON.** There is no client-side templating.
3. **GET never mutates; every mutation is a POST.** htmx *can* send PUT/DELETE, but
   plain HTML forms cannot — a PUT/DELETE route has no no-JS fallback (405). Name the
   action in the route instead: `"POST /items/{id}/delete"`.
4. **Fragments are template blocks,** not separate files — see
   [patterns/htmx-server-rendering.md](../patterns/htmx-server-rendering.md) for the
   full-page-vs-fragment mechanic, response headers (`HX-Redirect`, `HX-Trigger`),
   and out-of-band swaps.
5. **Security:**
   - CSP: `script-src 'self'` works because htmx is self-hosted and there's no
     inline JS — with one wrinkle: by default htmx injects an inline `<style>` for
     its indicator CSS, which the policy blocks. The canonical layout's `htmx-config`
     meta sets `"includeIndicatorStyles":false`; `app.css` owns the
     `.htmx-indicator`/`.htmx-request` rules instead (see [css.md](css.md)).
   - CSRF: no tokens — the server uses stdlib `http.CrossOriginProtection`
     (`Sec-Fetch-Site` based, Go 1.25+), which covers htmx requests automatically
     because htmx sends real same-origin requests. See
     [patterns/go-http-server.md](../patterns/go-http-server.md).
   - All dynamic HTML goes through `html/template` (contextual auto-escaping). Never
     concatenate user input into HTML.
   - **History cache: off.** By default htmx snapshots the full `<body>` of visited
     pages into `sessionStorage` for back-button restores — authenticated HTML that
     outlives logout and server-side session revocation as long as the tab stays open, and its
     cache-miss restore requests send `HX-Request: true` while expecting a full page
     (a known dual-mode footgun). The canonical layout's `htmx-config` sets
     `"historyCacheSize":0` and `"refreshOnHistoryMiss":true`: back/forward are real
     page loads. The server is the source of truth — there is nothing client-side
     worth restoring.

## Litmus test

If you are about to write `<script>` or reach for an htmx extension to do client-side
state, stop: move the state to the server and re-render the fragment. That is the
architecture, not a limitation.
