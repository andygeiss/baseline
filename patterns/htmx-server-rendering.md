# Pattern: htmx Server Rendering (Go html/template)

**Last verified: 2026-08-10**

The one mechanic that makes Go + htmx work: **every dynamic view is a named template
block; a handler renders either the full page or just the block, depending on
`HX-Request`.**

## Template structure

`layout.html` defines the shell; page templates fill slots and define their fragments:

```html
{{/* web/templates/game.html */}}
{{define "title"}}Game {{.ID}}{{end}}

{{define "main"}}
  <h1>Tic-Tac-Toe</h1>
  {{template "board" .}}
{{end}}

{{define "board"}}
<div id="board" class="board">
  {{range $i, $cell := .Cells}}
    <form method="post" action="/games/{{$.ID}}/moves"
          hx-post="/games/{{$.ID}}/moves" hx-target="#board" hx-swap="outerHTML">
      <input type="hidden" name="cell" value="{{$i}}">
      <button class="board-cell" {{if $cell.Taken}}disabled{{end}}>{{$cell.Mark}}</button>
    </form>
  {{end}}
</div>
{{end}}
```

- **Every interactive element is a real `<form>` or `<a>`** — with htmx absent, the
  form POSTs, the handler answers `303 See Other`, the browser re-renders the full
  page. htmx enhances that into a fragment swap; it never replaces it. A bare
  `<button hx-post=…>` outside a form does nothing without htmx and violates the
  progressive-enhancement MUST in [stack/htmx.md](../stack/htmx.md).
- Fragment root carries the `id` that `hx-target` points at; `hx-swap="outerHTML"`
  makes the fragment self-replacing.
- The layout (`layout.html`, canonical version in [stack/html.md](../stack/html.md))
  invokes `{{template "title" .}}` and `{{template "main" .}}` — every page template
  MUST define both blocks.
- Parse once at startup from `embed.FS`, one template set per page
  (`layout.html` + page file, so `ExecuteTemplate(w, "layout.html", …)` is the full
  page), stored in a map keyed by page file name. Register the `version` func
  ([go-performance.md](go-performance.md)) via `.Funcs()` before parsing. Fail fast
  at boot on parse errors.

## The dual-mode render helper

```go
// render writes page as a full document, or only its named block when the request
// came from an htmx interaction. block == "" always renders the full page.
func (a *App) render(w http.ResponseWriter, r *http.Request, status int, page, block string, data any) {
	name := "layout.html" // full page: the layout shell that invokes the page's "main"
	if block != "" &&
		r.Header.Get("HX-Request") == "true" &&
		r.Header.Get("HX-Boosted") != "true" {
		name = block // fragment only
	}
	var buf bytes.Buffer
	if err := a.templates[page].ExecuteTemplate(&buf, name, data); err != nil {
		a.serverError(w, r, err)
		return
	}
	w.Header().Add("Vary", "HX-Request, HX-Boosted") // Add, not Set — sessions.LoadAndSave already added "Vary: Cookie"
	w.WriteHeader(status)
	buf.WriteTo(w)
}
```

Four details are load-bearing:

- **`HX-Boosted` check:** boosted links/forms send `HX-Request: true` but swap the
  whole `<body>` — they need the full page. Without this check, `hx-boost` navigation
  renders bare fragments into empty pages.
- **Buffer first** — a template error after `WriteHeader` corrupts the response.
- **No `HX-History-Restore-Request` handling needed** — the layout's `htmx-config`
  disables the history cache (`historyCacheSize: 0`, `refreshOnHistoryMiss: true`,
  see [stack/htmx.md](../stack/htmx.md)), so back/forward are plain browser loads
  and never reach this helper with htmx headers. Do not re-enable the cache without
  extending the discriminator.
- **`Vary: HX-Request, HX-Boosted`** added here, once, so no dual-mode handler can
  forget it. Both headers participate in choosing the body (boosted requests send
  `HX-Request: true` but get the full page), so both must be cache keys — `Vary` on
  `HX-Request` alone lets a cache serve a bare fragment to a boosted navigation.
  It is `Add`, never `Set`: `Set` would clobber the `Vary: Cookie` that
  `sessions.LoadAndSave` has already put on the response, letting caches serve one
  user's page to another.

This helper is why progressive enhancement is free: the same handler serves the
no-htmx full page and the htmx fragment.

## Standard flows

- **Mutations follow POST-redirect-GET — except for fragment swaps.** The
  discriminator is the same one the render helper uses:
  `HX-Request: true` **and not** `HX-Boosted: true` → render the updated fragment
  directly with 200. Everything else — plain forms *and boosted forms* — answers
  `303 See Other` back to the page. Boosted POSTs need the 303 too: a direct 200
  pushes the POST's URL into history, so refresh/back re-issues a GET against a
  POST-only route → 405. And never 303 a fragment POST: the XHR follows the redirect
  transparently and the full page it lands on gets swapped into the fragment target.
  When the whole page must change after a fragment action, send `HX-Redirect` (below).
- **Form validation:** invalid POST re-renders the form fragment with errors and
  status **422**. Fields keep their submitted values.
  ⚠️ htmx 2 does **not** swap 4xx responses by default — the 422 flow requires the
  `htmx-config` responseHandling meta tag, already part of the canonical layout
  `<head>` in [stack/html.md](../stack/html.md). Do not remove it.
  ⚠️ When the invalid POST is *boosted* (`HX-Boosted: true`), also set
  `HX-Push-Url: false` on the 422 response: a boosted swap otherwise pushes the
  POST's URL into history — the exact refresh/back → GET-on-a-POST-route → 405
  failure the 303 rule above exists to prevent (a 422 is not a redirect, so
  nothing else stops the push).

  Only true *input* validation gets a 422. A stale-state action (clicking an already-
  taken cell on an outdated board) is not invalid input — respond 200 with the current
  fragment and a message, letting the swap heal the staleness.
- **Post-action navigation from a fragment:** set `HX-Redirect: /games/42` header
  instead of rendering, when the whole page must change.
- **Cross-component updates:** render extra fragments with `hx-swap-oob="true"` in the
  same response (e.g. update the score header when the board changes) — sparingly;
  if a response carries 3+ OOB fragments, swap a larger target instead.
- **Server-driven events:** `HX-Trigger: gameOver` response header when a decoupled
  element must react.
- **Caching:** dual-mode responses MUST set `Vary: HX-Request, HX-Boosted`
  (the render helper does).

## Anti-patterns

- ❌ Separate `_partial.html` files duplicating page markup — fragments are `define`
  blocks inside the page template, one source of truth.
- ❌ Returning JSON to htmx.
- ❌ Fragment responses for non-htmx requests (breaks the no-JS fallback, bookmarks,
  and crawlers).
