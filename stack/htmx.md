# Stack: htmx

**Tier 2** (shape — waived only on the record) · Last verified: 2026-10-27 · Pinned:
htmx 4.0.0 ([VERSIONS.md](../VERSIONS.md))

htmx is the *only* script on the page. It turns HTML into the application protocol:
any element can issue HTTP requests, the server answers with HTML, htmx swaps it in.

## Setup

- **Self-host.** Vendor `htmx.min.js` into the project (`web/static/js/htmx.min.js`)
  and serve via `embed.FS`. MUST NOT load from a CDN in production (availability,
  privacy, CSP, supply chain).
- **One tag, last in `<head>`, deferred:**
  `<script src="/static/js/htmx.min.js?v={{version}}" defer></script>`
  (version-busted like all static assets — see [patterns/go-performance.md](../patterns/go-performance.md)).
  MUST NOT sit in `<body>`. htmx runs every script in the content it swaps, and a
  boosted click swaps the whole body, so each navigation would start a second htmx
  beside the first. Nothing swaps `<head>`.
- No extensions unless a pattern document mandates one. `hx-boost:inherited="true"` on
  `<body>` is the default starting point for smooth navigation.

## Inheritance is explicit

htmx 4 reads an attribute from an ancestor only when the ancestor writes `:inherited`:
`hx-boost:inherited="true"`, `hx-target:inherited="#list"`. A bare attribute on a
container governs that element alone, and htmx ignores the rest without a warning —
`<body hx-boost="true">` boosts no link at all. Put `:inherited` on the one container
whose children share the value. MUST NOT turn on `implicitInheritance`: it brings back
2.x's rule, where every attribute leaks into everything below it.

## Core attribute set (prefer these, in this order)

| Attribute | Use |
|---|---|
| `hx-get` / `hx-post` | Issue request. GET reads, POST mutates — the only two verbs with a plain-form fallback. |
| `hx-target` | CSS selector to swap into. Default is the triggering element — usually set this explicitly. |
| `hx-swap` | `innerHTML` (default), `outerHTML` for self-replacing fragments. `transition:false` opts a rapid-fire swap out of view transitions ([patterns/css-motion.md](../patterns/css-motion.md)). |
| `hx-trigger` | Only when the default event is wrong (e.g. `input changed delay:300ms` for search). Polling (`every 3s`) keeps a page current and has its own rules — [patterns/htmx-live-updates.md](../patterns/htmx-live-updates.md). |
| `hx-push-url` | `true` on navigation-like GETs so the URL bar and back button stay honest. |
| `hx-indicator` | Always give requests >100ms a visible indicator (CSS `.htmx-request`) — except a background poll, which shows none ([patterns/htmx-live-updates.md](../patterns/htmx-live-updates.md)). |
| `hx-boost` | On `<body>`, as `hx-boost:inherited="true"`: upgrades plain links/forms to AJAX with graceful fallback. |
| `hx-confirm` | For destructive actions. |

Attributes not listed here (e.g. `hx-on`, `hx-vals` with JS expressions) SHOULD be
avoided — if you need them, the design is probably drifting toward client-side logic.
The `hx-status` lines on the canonical `<body>` are not one to add per element; they
are part of the layout ([stack/html.md](html.md)).

## Rules

1. **Progressive enhancement is mandatory.** Every htmx interaction MUST degrade to a
   working plain `<a>`/`<form>`. Build the no-htmx version first, then enhance.
2. **Server returns HTML, never JSON.** There is no client-side templating.
3. **GET never mutates; every mutation is a POST.** htmx *can* send PUT/DELETE, but
   plain HTML forms cannot — a PUT/DELETE route has no no-JS fallback (405). Name the
   action in the route instead: `"POST /items/{id}/delete"`.
4. **Fragments are template blocks,** not separate files — see
   [patterns/htmx-server-rendering.md](../patterns/htmx-server-rendering.md) for the
   full-page-vs-fragment mechanic, which statuses swap, response headers
   (`HX-Redirect`, `HX-Trigger`), and out-of-band swaps.
5. **`app.css` owns the indicator styles.** By default htmx 4 adds its own indicator CSS
   as a constructed stylesheet. The CSP does not block that one, but the sheet sits
   outside every cascade layer, so it beats each rule `app.css` writes, and its 200 ms
   fade ignores `prefers-reduced-motion`. The canonical layout's `htmx-config` meta sets
   `"includeIndicatorCSS":false`; `app.css` defines `.htmx-indicator` and
   `.htmx-request` itself (see [css.md](css.md)).
6. **Security:**
   - CSP: htmx needs no policy change — it is self-hosted and writes no inline
     JS ([patterns/security-headers.md](../patterns/security-headers.md) owns
     the policy).
   - CSRF: no tokens — the server uses stdlib `http.CrossOriginProtection`
     (`Sec-Fetch-Site` based, Go 1.25+), which covers htmx requests automatically
     because htmx sends real same-origin requests. See
     [patterns/go-http-server.md](../patterns/go-http-server.md).
   - All dynamic HTML goes through `html/template` (contextual auto-escaping). Never
     concatenate user input into HTML.
   - **History: reload.** htmx 4 keeps no history cache. On back/forward it either
     re-fetches the page itself and swaps the body, or reloads. The canonical
     `htmx-config` sets `"history":"reload"`, so back/forward are real page loads, as
     they were under 2.x with its cache off. No handler ever answers a restore request.
     The server is the source of truth — there is nothing client-side worth restoring.

## Litmus test

If you are about to write `<script>` or reach for an htmx extension to do client-side
state, stop: move the state to the server and re-render the fragment. That is the
architecture, not a limitation.
