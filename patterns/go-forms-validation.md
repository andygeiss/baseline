# Pattern: Forms & Validation (Go)

**Tier 2** (shape — waived only on the record) · Last verified: 2026-08-15

The `html/template` escaping the 422 re-render depends on is tier 1, and the checklists'
*Security* section is where it is stated.

Every form is the same loop: GET renders the form, POST parses and validates,
an invalid POST re-renders the same form with errors and submitted values at
422, a valid POST mutates and redirects with a flash message.
[htmx-server-rendering.md](htmx-server-rendering.md) defines the response side
of that loop (422, `HX-Push-Url`, PRG); [stack/html.md](../stack/html.md)
rule 4 owns the markup. This document is the request side: the validator, the
handler loop, and flash messages.

## The validator

Lives in `internal/app/forms.go` — request-shape checks (present, length,
format) are an HTTP-edge concern. Domain invariants stay in `domain` and hold
no matter which handler calls them: the form check is UX, the domain rule is
truth. These ~15 lines are the whole framework; validation libraries are not
on the approved list ([stack/go.md](../stack/go.md)):

```go
// Validator accumulates field errors; embed it in every form struct.
type Validator struct {
	FieldErrors map[string]string
}

// Valid reports whether every Check passed.
func (v *Validator) Valid() bool { return len(v.FieldErrors) == 0 }

// Check records msg under field when ok is false. The first failed check per
// field wins — order checks from most to least fundamental.
func (v *Validator) Check(ok bool, field, msg string) {
	if ok {
		return
	}
	if v.FieldErrors == nil {
		v.FieldErrors = make(map[string]string)
	}
	if _, taken := v.FieldErrors[field]; !taken {
		v.FieldErrors[field] = msg
	}
}
```

One struct per form, holding the submitted values and the embedded validator:

```go
type gameForm struct {
	Name string
	Validator
}
```

## The handler loop

```go
func (a *App) handleGameCreate(w http.ResponseWriter, r *http.Request) {
	if err := r.ParseForm(); err != nil {
		status := http.StatusBadRequest // malformed body — not a validation failure
		var tooLarge *http.MaxBytesError
		if errors.As(err, &tooLarge) {
			status = http.StatusRequestEntityTooLarge // the 1 MiB cap — go-http-server.md
		}
		a.clientError(w, r, status)
		return
	}

	form := gameForm{Name: strings.TrimSpace(r.PostFormValue("name"))}
	form.Check(form.Name != "", "name", "Enter a name.")
	form.Check(utf8.RuneCountInString(form.Name) <= 60, "name", "Use at most 60 characters.")
	if !form.Valid() {
		a.renderForm(w, r, "game_new.html", "game-form", form)
		return
	}

	game, err := a.games.Create(r.Context(), form.Name)
	if errors.Is(err, domain.ErrNameTaken) {
		form.Check(false, "name", "That name is already taken.")
		a.renderForm(w, r, "game_new.html", "game-form", form)
		return
	}
	if err != nil {
		a.serverError(w, r, err)
		return
	}

	a.sessions.Put(r.Context(), "flash", "Game created.")
	w.Header().Add("Vary", "HX-Request, HX-Boosted") // this response differs by both and bypasses a.render
	if r.Header.Get("HX-Request") == "true" && r.Header.Get("HX-Boosted") != "true" {
		// The XHR would follow a 303 and swap the full page into the fragment target.
		w.Header().Set("HX-Redirect", "/games/"+game.ID)
		return // 200, empty body
	}
	http.Redirect(w, r, "/games/"+game.ID, http.StatusSeeOther)
}

// renderForm re-renders a form with its errors and values at 422.
func (a *App) renderForm(w http.ResponseWriter, r *http.Request, page, block string, form gameForm) {
	if r.Header.Get("HX-Boosted") == "true" {
		w.Header().Set("HX-Push-Url", "false") // a boosted swap otherwise pushes the POST URL — htmx-server-rendering.md
	}
	a.render(w, r, http.StatusUnprocessableEntity, page, block,
		gameNewPage{view: a.view(r), gameForm: form}) // view: see Flash messages below
}
```

- **Trim before validating** and count runes, not bytes —
  `utf8.RuneCountInString`, because `len("ö") == 2` fails users typing
  non-ASCII names at the advertised limit.
- **A domain conflict joins `FieldErrors`** and takes the same 422 path: a
  taken name is input the user must change, so it is input validation. A
  stale-state action is not — that flow answers 200 with the current fragment
  ([htmx-server-rendering.md](htmx-server-rendering.md)).
- **The success redirect is the auth-flow trio** from
  [go-auth-sessions.md](go-auth-sessions.md): 303 for plain and boosted
  requests, `HX-Redirect` for fragment requests, `Vary` added manually because
  this response bypasses `a.render`.
- A `ParseForm` error is a malformed or oversized body — `clientError`, never
  a 422 re-render: there are no submitted values to keep.

## The template

The form is a named block, so the 422 response re-renders it whole-page or as
a fragment through the same `a.render` dual-mode split:

```html
{{define "game-form"}}
<form id="game-form" method="post" action="/games"
      hx-post="/games" hx-target="#game-form" hx-swap="outerHTML">
  <label for="name">Name</label>
  <input id="name" name="name" value="{{.Name}}" required maxlength="60"
         {{with .FieldErrors.name}}aria-invalid="true" aria-describedby="name-error"{{end}}>
  {{with .FieldErrors.name}}<p id="name-error" class="field-error">{{.}}</p>{{end}}
  <button>Create game</button>
</form>
{{end}}
```

- **Submitted values are echoed** (`value="{{.Name}}"`) so nothing is retyped;
  `html/template` escaping makes hostile input inert.
- `required` and `maxlength` are the first line only — the server decides
  ([stack/html.md](../stack/html.md) rule 4). Use the same number on both
  sides, knowing the units differ at the edge: `maxlength` counts UTF-16 code
  units, the server counts runes, so an emoji (two code units, one rune)
  reaches the client cap early — stricter than advertised, never looser.
- The error sits adjacent to its control, so a fragment swap keeps the
  message in reading order next to the field it names. Adjacent is enough for
  the eye and nothing for a screen reader, so the failing control also points
  at the message: `aria-describedby` reads it out when focus lands there, and
  `aria-invalid` says the field is the one that failed. Both appear only when
  the error does — the ARIA patch for a gap with no native mechanism
  ([stack/html.md](../stack/html.md)).
- The fragment root's `id` is the form's own `hx-target` — self-replacing, per
  [htmx-server-rendering.md](htmx-server-rendering.md).

## Flash messages

The one-time message shown on the page after a PRG redirect ("Game created.").
It rides the session (requires the [go-auth-sessions.md](go-auth-sessions.md)
middleware; an app without sessions shows the result on the target page
instead):

```go
// internal/app/views.go

// view is embedded in every page's data: the cross-page fields the layout reads.
type view struct {
	Flash string
}

func (a *App) view(r *http.Request) view {
	return view{Flash: a.sessions.PopString(r.Context(), "flash")}
}
```

Each page's data embeds `view` plus its form or feature data — field promotion
keeps templates unchanged (`.Name` and `.Flash` both resolve):

```go
type gameNewPage struct {
	view
	gameForm
}
```

The layout shows it — **inside `<main>`**, because `header`, `main`, and
`footer` must stay the only in-flow children of `body`
([css-layout.md](css-layout.md) page shell):

```html
<main>
  {{with .Flash}}<p class="flash" role="alert">{{.}}</p>{{end}}
  {{template "main" .}}
</main>
```

(`layout.html` in [stack/html.md](../stack/html.md) shows the base shell; a
project that adopts flash adds exactly this one line to the layout — rule 2
below covers the data side. The role is `alert`, not
`status`: a boosted swap inserts the region already populated, and screen
readers announce an already-populated live region only for the alert role — a
status region must exist empty before its content changes.)

Three rules keep it honest:

1. **`Put` only before a redirect** (303 or `HX-Redirect`). On the fragment
   path the swapped fragment *is* the feedback — a flash put there is popped
   by some later page where it no longer makes sense.
2. **Once the layout reads `.Flash`, every page's data embeds `view`** —
   including pages built before flash: the plain `handleGameShow` in
   [go-http-server.md](go-http-server.md) renders bare `domain.Game` and 500s
   the moment the layout reads `.Flash`, so adopting flash means wrapping it
   (`gamePage{view: a.view(r), Game: game}`) too. `html/template` fails on a
   missing field at execute time; the buffer-first render turns that into a
   500 instead of a torn page, but it is still a bug.
3. **One string, not a queue.** Needing two flash messages in one request is a
   design smell — say the one thing that changed.

## Anti-patterns

- ❌ A validation library (`go-playground/validator` tags, ozzo) — not on the
  approved list; the 15-line validator is the framework.
- ❌ Redirecting on validation failure — it discards the submitted values and
  errors, then needs the session to smuggle them back. Re-render at 422.
- ❌ Success feedback in the query string (`?created=1`) — bookmarkable and
  cacheable, so the message repeats on every visit. Flash pops exactly once.
- ❌ 200 for an invalid POST — tests and htmx can no longer tell success from
  failure; 422 is the contract.
