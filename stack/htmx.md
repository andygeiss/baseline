# Stack: htmx

**Last verified: 2026-08-10 · Pinned: htmx 2.0.9** (see [VERSIONS.md](../VERSIONS.md))

htmx is the *only* script on the page. It turns HTML into the application protocol:
any element can issue HTTP requests, the server answers with HTML, htmx swaps it in.

⚠️ **htmx 4.x is in beta (fetch-based rewrite, breaking changes). MUST NOT be used.**
Stay on 2.x until this baseline says otherwise.

## Setup

- **Self-host.** Vendor `htmx.min.js` into the project (`web/static/js/htmx.min.js`)
  and serve via `embed.FS`. MUST NOT load from a CDN in production (availability,
  privacy, CSP, supply chain).
- Single tag before `</body>`: `<script src="/static/js/htmx.min.js"></script>`.
- No extensions unless a pattern document mandates one. `hx-boost` on `<body>` is the
  default starting point for smooth navigation.

## Core attribute set (prefer these, in this order)

| Attribute | Use |
|---|---|
| `hx-get` / `hx-post` / `hx-put` / `hx-delete` | Issue request. Use real HTTP verbs matching the route. |
| `hx-target` | CSS selector to swap into. Default is the triggering element — usually set this explicitly. |
| `hx-swap` | `innerHTML` (default), `outerHTML` for self-replacing fragments. |
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
3. **GET is idempotent, mutations use POST/PUT/DELETE.** htmx sends real verbs; route
   them as such (`"DELETE /items/{id}"`).
4. **Fragments are template blocks,** not separate files — see
   [patterns/htmx-server-rendering.md](../patterns/htmx-server-rendering.md) for the
   full-page-vs-fragment mechanic, response headers (`HX-Redirect`, `HX-Trigger`),
   and out-of-band swaps.
5. **Security:**
   - CSP: `script-src 'self'` works because htmx is self-hosted and there's no inline JS.
   - CSRF: mutations carry a token — hidden input in forms; `hx-headers` on the body
     tag for non-form elements.
   - All dynamic HTML goes through `html/template` (contextual auto-escaping). Never
     concatenate user input into HTML.

## Litmus test

If you are about to write `<script>` or reach for an htmx extension to do client-side
state, stop: move the state to the server and re-render the fragment. That is the
architecture, not a limitation.
