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
    <button class="board-cell"
            hx-post="/games/{{$.ID}}/moves"
            hx-vals='{"cell": {{$i}}}'
            hx-target="#board" hx-swap="outerHTML"
            {{if $cell.Taken}}disabled{{end}}>
      {{$cell.Mark}}
    </button>
  {{end}}
</div>
{{end}}
```

- Fragment root carries the `id` that `hx-target` points at; `hx-swap="outerHTML"`
  makes the fragment self-replacing.
- Parse once at startup from `embed.FS`, one template set per page
  (`layout.html` + page file), stored in a map. Fail fast at boot on parse errors.

## The dual-mode render helper

```go
func (a *App) render(w http.ResponseWriter, r *http.Request, status int, page, block string, data any) {
	ts := a.templates[page]
	if r.Header.Get("HX-Request") == "true" && block != "" {
		name = block          // fragment only
	} else {
		name = "layout"       // full page
	}
	var buf bytes.Buffer
	if err := ts.ExecuteTemplate(&buf, name, data); err != nil {
		a.serverError(w, r, err)
		return
	}
	w.WriteHeader(status)
	buf.WriteTo(w)
}
```

Render to a buffer first — a template error after `WriteHeader` corrupts the response.
This helper is why progressive enhancement is free: the same handler serves the
no-htmx full page and the htmx fragment.

## Standard flows

- **Form validation:** invalid POST re-renders the form fragment with errors and
  status **422**. Fields keep their submitted values. Valid POST → `303 See Other`
  redirect (plain) — htmx follows redirects transparently.
- **Post-action navigation from a fragment:** set `HX-Redirect: /games/42` header
  instead of rendering, when the whole page must change.
- **Cross-component updates:** render extra fragments with `hx-swap-oob="true"` in the
  same response (e.g. update the score header when the board changes) — sparingly;
  if a response carries 3+ OOB fragments, swap a larger target instead.
- **Server-driven events:** `HX-Trigger: gameOver` response header when a decoupled
  element must react.
- **Caching:** dual-mode responses MUST set `Vary: HX-Request`.

## Anti-patterns

- ❌ Separate `_partial.html` files duplicating page markup — fragments are `define`
  blocks inside the page template, one source of truth.
- ❌ Returning JSON to htmx.
- ❌ Fragment responses for non-htmx requests (breaks the no-JS fallback, bookmarks,
  and crawlers).
