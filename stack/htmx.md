# Stack: htmx

**Tier 2** (shape — waived only on the record) · Last verified: 2026-10-27 · Pinned:
htmx 4.0.0 ([VERSIONS.md](../VERSIONS.md))

**Rule 8, Security, is tier 1 and never waived:** the policy, CSRF, escaping, and *Boost
only pages*. Each one stops a stranger's markup or request from acting as the reader.

htmx is the *only* script on the page, but for a WebAssembly client's two
([patterns/wasm-client.md](../patterns/wasm-client.md)). It turns HTML into the application protocol:
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
- No extensions unless a pattern document mandates one. `hx-boost:inherited="transition:true"`
  on `<body>` is part of the canonical layout ([html.md](html.md)).

## Inheritance is explicit

htmx 4 reads an attribute from an ancestor only when the ancestor writes `:inherited`:
`hx-boost:inherited="transition:true"`, `hx-target:inherited="#list"`. A bare attribute on
a container governs that element alone, and htmx ignores the rest without a warning —
`<body hx-boost="true">` boosts no link at all. Put `:inherited` on the one container
whose children share the value. MUST NOT turn on `implicitInheritance`: it brings back
2.x's rule, where every attribute leaks into everything below it.

Under the layout's boost, a link or form without `hx-get` or `hx-post` is boosted unless it
opts out, and an `hx-target` that reaches it — set on it or inherited — retargets the boost.
The answer goes to that target as a fragment, and a boosted request still pushes its URL, so
a boosted POST leaves its own address in the history. Put `hx-target` only on an element
that carries `hx-get` or `hx-post`, and `hx-target:inherited` only on a container whose every
link and form does too.

## Core attribute set (prefer these, in this order)

| Attribute | Use |
|---|---|
| `hx-get` / `hx-post` | Issue request. GET reads, POST mutates — the only two verbs with a plain-form fallback. |
| `hx-target` | CSS selector to swap into. Default is the triggering element — usually set this explicitly. |
| `hx-swap` | `innerHTML` (default), `outerHTML` for self-replacing fragments. `transition:true` opts a fragment swap into a view transition, which only a boosted swap runs by default ([patterns/css-motion.md](../patterns/css-motion.md)). |
| `hx-trigger` | Only when the default event is wrong (e.g. `input changed delay:300ms` for search). Polling (`every 3s`) keeps a page current and has its own rules — [patterns/htmx-live-updates.md](../patterns/htmx-live-updates.md). |
| `hx-push-url` | `true` on navigation-like GETs so the URL bar and back button stay honest. |
| `hx-indicator` | Always give requests >100ms a visible indicator (CSS `.htmx-request`) — except a background poll, which shows none ([patterns/htmx-live-updates.md](../patterns/htmx-live-updates.md)). |
| `hx-boost` | On `<body>`, as `hx-boost:inherited="transition:true"`: upgrades plain links/forms to AJAX with graceful fallback, and cross-fades them. `hx-boost="false"` opts out a link or form whose answer is not a page (rule 8). |
| `hx-confirm` | For destructive actions. |

Attributes not listed here (e.g. `hx-on`, `hx-vals` with JS expressions) SHOULD be
avoided — if you need them, the design is probably drifting toward client-side logic.
`hx-status` lives only on the layout's `<body>` ([html.md](html.md)). MUST NOT add it to
another element. For each code htmx tries the exact code, then its first two digits
(`42x` for a 422), then its first (`4xx`), on the sending element and its ancestors, so
the element's own line, or an `:inherited` one above it, wins wherever it matches at
least as closely as the layout's. An error such a line matches then swaps, takes its
title, and pushes a URL wherever the element would — boosted, or carrying `hx-push-url`
— unless the line says otherwise. `hx-config` appears only for rule 7's timeout.

## Rules

1. **Progressive enhancement is mandatory.** Every htmx interaction MUST degrade to a
   working plain `<a>`/`<form>`. Build the no-htmx version first, then enhance.
2. **Server returns HTML, never JSON.** There is no client-side templating.
3. **GET never mutates; every mutation is a POST** — but a WebAssembly client's socket
   ([patterns/wasm-client.md](../patterns/wasm-client.md)). htmx *can* send PUT/DELETE, but
   plain HTML forms cannot — a PUT/DELETE route has no no-JS fallback (405). Name the
   action in the route instead: `"POST /items/{id}/delete"`.
4. **Fragments are template blocks,** not separate files — see
   [patterns/htmx-server-rendering.md](../patterns/htmx-server-rendering.md) for the
   full-page-vs-fragment mechanic, which statuses swap, response headers
   (`HX-Redirect`, `HX-Trigger`), and out-of-band swaps.
5. **`app.css` owns the indicator styles.** By default htmx 4 adds its own indicator CSS
   as a constructed stylesheet. The CSP does not block it, but the sheet sits
   outside every cascade layer, so it beats each rule `app.css` writes, and its 200 ms
   fade ignores `prefers-reduced-motion`. The canonical layout's `htmx-config` meta sets
   `"includeIndicatorCSS":false`; `app.css` defines `.htmx-indicator` and
   `.htmx-request` itself (see [css.md](css.md)).
6. **Back and forward reload the page.** htmx 4 keeps no history cache. On back/forward
   it either re-fetches the page itself and swaps the body, or reloads. The canonical
   `htmx-config` sets `"history":"reload"`, so back/forward are real page loads and no
   handler ever answers a restore request. The server is the source of truth — there is
   nothing client-side worth restoring.
7. **htmx gives up at 60 s.** htmx 4 aborts any request still running after its
   `defaultTimeout`, 60 s, and an aborted request swaps nothing. The canonical server
   answers inside 30 s (`WriteTimeout`,
   [patterns/go-http-server.md](../patterns/go-http-server.md)). htmx's clock starts
   before the server's, which waits for the request's headers, and stops only once the
   answer is read, so htmx can give up first on a route widened past 50 s — an upload, a
   waived `WriteTimeout`. The element that sends that request carries a timeout at least
   10 s above `WriteTimeout`: `hx-config="timeout:100s"` for a 90 s `WriteTimeout`.
8. **Security:**
   - CSP: htmx needs no policy change — it is self-hosted and writes no inline
     JS ([patterns/security-headers.md](../patterns/security-headers.md) owns
     the policy).
   - CSRF: no tokens — the server uses stdlib `http.CrossOriginProtection`
     (`Sec-Fetch-Site` based, Go 1.25+), which covers htmx requests automatically
     because htmx sends real same-origin requests. See
     [patterns/go-http-server.md](../patterns/go-http-server.md).
   - All dynamic HTML goes through `html/template` (contextual auto-escaping). Never
     concatenate user input into HTML.
   - **Boost only pages.** htmx parses a boosted answer as HTML whatever its type, and
     acts on every htmx attribute in it. A link or form whose answer is not a page — a
     file, an export — carries `hx-boost="false"`, and so does any link whose href a
     user supplied ([patterns/go-file-uploads.md](../patterns/go-file-uploads.md)).

## Litmus test

If you are about to write `<script>` or reach for an htmx extension to do client-side
state, stop: move the state to the server and re-render the fragment. That is the
architecture, not a limitation.
