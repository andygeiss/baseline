# Pattern: htmx Server Rendering (Go html/template)

**Tier 2** (shape — waived only on the record) · Last verified: 2026-10-27

One exception: never handing user data to `template.HTML` is tier 1, wherever a checklist
files it.

The one mechanic that makes Go + htmx work: **every dynamic view is a named template
block; a handler renders either the full page or just the block, depending on
`HX-Request-Type`.**

## Template structure

`layout.html` defines the shell; page templates fill slots and define their fragments:

```html
{{/* web/templates/tasks.html */}}
{{define "title"}}Your tasks{{end}}

{{define "main"}}
  <h1>Your tasks</h1>
  {{template "task-list" .}}
{{end}}

{{define "task-list"}}
<ul id="task-list" class="task-list">
  {{range .Tasks}}
    <li>
      <form method="post" action="/tasks/{{.ID}}/toggle"
            hx-post="/tasks/{{.ID}}/toggle" hx-target="#task-list" hx-swap="outerHTML">
        <button class="task-toggle" aria-pressed="{{.Done}}">{{.Title}}</button>
      </form>
    </li>
  {{end}}
</ul>
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
// render writes page as a full document, or only its named block when isFragment
// reports a fragment request. block == "" always renders the full page.
func (a *App) render(w http.ResponseWriter, r *http.Request, status int, page, block string, data any) {
	name := "layout.html" // full page: the layout shell that invokes the page's "main"
	if block != "" && isFragment(r) {
		name = block // fragment only
	}
	var buf bytes.Buffer
	if err := a.templates[page].ExecuteTemplate(&buf, name, data); err != nil {
		a.serverError(w, r, err)
		return
	}
	w.Header().Add("Vary", "HX-Request-Type") // Add, not Set — sessions.LoadAndSave already added "Vary: Cookie"
	w.WriteHeader(status)
	buf.WriteTo(w)
}

// isFragment reports whether this request wants a fragment back rather than a
// whole page. Every handler that chooses between a fragment and a 303 calls it
// too, so there is one copy of the rule and a handler can never disagree with
// its own rendering.
func isFragment(r *http.Request) bool {
	return r.Header.Get("HX-Request-Type") == "partial"
}
```

Three details are load-bearing:

- **The discriminator has one name and one definition.** htmx sends
  `HX-Request-Type: full` when it will swap the answer into `<body>` or pick from it
  with `hx-select`, and `partial` for every other target, boosted or not. A boosted link
  or form targets `<body>` unless an `hx-target`, its own or an inherited one, says
  otherwise ([stack/htmx.md](../stack/htmx.md)). A plain browser request sends neither. Only
  `partial` gets a fragment; a fragment sent to any other request lands where a page
  belongs. Handlers need the same test to choose between a fragment and a 303
  (*Standard flows* below), so it is a function both call, never the header test
  written out twice. Two copies is two chances for a handler to 303 a request that
  `render` would have answered with a fragment.
- **Buffer first** — a template error after `WriteHeader` corrupts the response.
- **`Vary: HX-Request-Type`** added here, once, so no dual-mode handler can
  forget it. The header chooses the body, so it must be a cache key — without it a
  cache can serve a bare fragment to a navigation.
  It is `Add`, never `Set`: `Set` would clobber the `Vary: Cookie` that
  `sessions.LoadAndSave` has already put on the response, letting caches serve one
  user's page to another.

This helper is why progressive enhancement is free: the same handler serves the
no-htmx full page and the htmx fragment.

## Standard flows

- **Mutations follow POST-redirect-GET — except for fragment swaps.** The
  discriminator is `isFragment` above — the same function the render helper
  calls, never a second copy of the header test. `isFragment(r)` → render the
  updated fragment
  directly with 200. Everything else — plain forms *and boosted forms* — answers
  `303 See Other` back to the page. Boosted POSTs need the 303 too: a direct 200
  pushes the POST's URL into history, so refresh/back re-issues a GET against a
  POST-only route → 405. And never 303 a fragment POST: `fetch` follows the redirect
  transparently, carrying the same htmx headers, and the redirected route's answer,
  whatever it is, lands in the fragment target.
  When the whole page must change after a fragment action, send `HX-Redirect` (below).
- **Form validation:** invalid POST re-renders the form fragment with errors and
  status **422**. Fields keep their submitted values. The request side of this
  flow — validator, handler loop, flash messages — is
  [go-forms-validation.md](go-forms-validation.md). The 422 swaps because the
  canonical `<body>` ([stack/html.md](../stack/html.md)) carries
  `hx-status:422:inherited="push:false"`. Its `push:false` matters as much as the
  swap: a boosted swap otherwise pushes the POST's URL into history — the exact
  refresh/back → GET-on-a-POST-route → 405 failure the 303 rule above exists to
  prevent, and a 422 is not a redirect, so nothing else stops the push.

  Only true *input* validation gets a 422. A stale-state action (ticking off a task
  another tab already deleted) is not invalid input — respond 200 with the current
  fragment and a message, letting the swap heal the staleness.
- **Every other error swaps nothing.** A 4xx or 5xx that is not a 422 leaves the page
  as it was — content, URL, and tab title. The `hx-status:4xx` and `hx-status:5xx`
  lines on `<body>` swap nothing, run no transition, ignore the title an error page
  would bring, and push nothing. Without them htmx 4 swaps every response but 204 and 304, so
  an error page lands inside whatever asked — a failed poll replaces its own poller, and
  live updates stop. htmx tries the most specific code first (`422`, then `42x`, then
  `4xx`), so the three lines work in any order. `htmx-config` MUST NOT list `"4xx"` or
  `"5xx"` under `noSwap`: at each of those steps htmx reads that list before any
  `hx-status` line, so a `"4xx"` there swallows the `4xx` line and a boosted error
  pushes its URL with nothing swapped. An `hx-status` line also outranks `HX-Reswap`, so
  no header makes an error swap. A refusal the reader has to read — an upload over its
  cap, a sign-in past the rate limit — shows nothing on the htmx path; to show it, answer
  422 with the message in the form.
- **Post-action navigation from a fragment:** set `HX-Redirect: /tasks/42` header
  instead of rendering, when the whole page must change.
- **Cross-component updates:** render extra fragments with `hx-swap-oob="true"` in the
  same response (e.g. update the open-task count when the list changes) — sparingly;
  if a response carries 3+ OOB fragments, swap a larger target instead.
- **Server-driven events:** `HX-Trigger: taskDeleted` response header when a decoupled
  element must react.
- **Caching:** dual-mode responses MUST set `Vary: HX-Request-Type`
  (the render helper does).

## Anti-patterns

- ❌ Separate `_partial.html` files duplicating page markup — fragments are `define`
  blocks inside the page template, one source of truth.
- ❌ Returning JSON to htmx.
