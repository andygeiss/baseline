# Stack: HTML

**Last verified: 2026-08-10 · Target: WHATWG Living Standard**

HTML is the application. Links and forms are the API; the DOM is the client-side state.

## The no-JavaScript rule

**MUST NOT ship hand-written JavaScript.** The single permitted script is the vendored
htmx file. Consequences of this rule:

- Interactivity beyond htmx swaps comes from native elements:
  `<details>`/`<summary>` (disclosure), `<dialog>` (modals, via `command`/`commandfor`
  invoker attributes where Baseline, otherwise a full-page fallback), `popover`
  (menus, tooltips), `<datalist>` (autocomplete), form `required`/`pattern`/`min`/`max`
  (first-line validation).
- If a feature genuinely cannot be built with HTML + CSS + htmx, the feature is
  redesigned or rejected — escalate to the user, do not quietly add a script tag.

## Semantics

1. **One `<h1>` per page;** heading levels never skip.
2. **Landmarks:** `<header>`, `<nav>`, `<main>` (exactly one), `<footer>`.
   `<div>` is for styling hooks only, never where a semantic element exists.
3. **Buttons vs links:** `<a href>` navigates (GET), `<button>` acts (POST/PUT/DELETE
   or htmx mutation). Never a styled `<a>` performing a mutation.
4. **Forms always have:** `<label for>` on every control, a submit `<button>`,
   `method` + `action` that work without htmx (progressive enhancement),
   server-side validation regardless of client attributes.
5. **Tables for tabular data** only — and always with `<th scope>`.

## Accessibility (non-negotiable)

- **First rule of ARIA: don't.** Native elements before `role=` attributes; ARIA only
  to patch gaps, never to rebuild native behavior.
- Every image has `alt` (empty `alt=""` if decorative).
- Focus is always visible (`:focus-visible` styling, see [css.md](css.md)); DOM order
  = tab order; no positive `tabindex`.
- Color contrast ≥ 4.5:1 for text (WCAG 2.2 AA is the bar).
- After an htmx swap, ensure focus and announcements still make sense — swap the
  smallest fragment that changed, and use `aria-live="polite"` regions for
  out-of-band status updates.

## Document skeleton

```html
<!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>{{.Title}} · AppName</title>
  <link rel="stylesheet" href="/static/css/app.css">
  <link rel="icon" href="/static/favicon.svg" type="image/svg+xml">
</head>
<body hx-boost="true">
  <header>…</header>
  <main>…</main>
  <footer>…</footer>
  <script src="/static/js/htmx.min.js"></script>
</body>
</html>
```

Validate markup in CI or spot-check with https://validator.w3.org/nu/.
