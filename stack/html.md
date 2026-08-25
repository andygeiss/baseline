# Stack: HTML

**Tier 2** (shape — waived only on the record) · Last verified: 2026-08-13 · Target: WHATWG Living Standard

The no-JavaScript rule is the one the README's waiver example is written about, so read
that example before waiving it.

HTML is the application. Links and forms are the API; the DOM is the client-side state.

## The no-JavaScript rule

**MUST NOT ship hand-written JavaScript.** The single permitted script is the vendored
htmx file. Consequences of this rule:

- Interactivity beyond htmx swaps comes from native elements:
  `<details>`/`<summary>` (disclosure), `<dialog>` (modals, via `command`/`commandfor`
  invoker attributes where Baseline, otherwise a full-page fallback), `popover`
  (menus, tooltips — Baseline Newly as of 2026: unsupported browsers render the
  content inline instead of hidden, so use it only where that degrades acceptably,
  otherwise `<details>`), `<datalist>` (autocomplete), form `required`/`pattern`/`min`/`max`
  (first-line validation).
- If a feature genuinely cannot be built with HTML + CSS + htmx, the feature is
  redesigned or rejected — escalate to the user, do not quietly add a script tag.

## Semantics

1. **One `<h1>` per page;** heading levels never skip.
2. **Landmarks:** `<header>`, `<nav>`, `<main>` (exactly one), `<footer>`.
   `<div>` is for styling hooks only, never where a semantic element exists.
3. **Buttons vs links:** `<a href>` navigates (GET), `<button>` acts (a POST form,
   optionally htmx-enhanced). Never a styled `<a>` performing a mutation.
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

This *is* `web/templates/layout.html` — the shell every page renders into. Every page
template MUST define `title` and `main` (see
[patterns/htmx-server-rendering.md](../patterns/htmx-server-rendering.md)); `version`
is a template function from build info, not a data field (see
[patterns/go-performance.md](../patterns/go-performance.md)).

```html
<!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <meta name="htmx-config" content='{"includeIndicatorStyles":false,
    "globalViewTransitions":true,
    "historyCacheSize":0,"refreshOnHistoryMiss":true,"responseHandling":[
    {"code":"204","swap":false},
    {"code":"[23]..","swap":true},
    {"code":"422","swap":true},
    {"code":"[45]..","swap":false,"error":true}]}'>
  <title>{{template "title" .}} · AppName</title>
  <link rel="stylesheet" href="/static/css/app.css?v={{version}}">
  <link rel="icon" href="/static/favicon.svg?v={{version}}" type="image/svg+xml">
</head>
<body hx-boost="true">
  <header>…</header>
  <main>{{template "main" .}}</main>
  <footer>…</footer>
  <script src="/static/js/htmx.min.js?v={{version}}"></script>
</body>
</html>
```

(The `htmx-config` meta is required for the 422 validation flow — explained in
[patterns/htmx-server-rendering.md](../patterns/htmx-server-rendering.md).
It also turns on view-transition swaps:
[patterns/css-motion.md](../patterns/css-motion.md).)

An installable project adds four head lines after the favicon link;
[patterns/pwa.md](../patterns/pwa.md) defines them. Nothing else in the shell
changes, and the no-JavaScript rule holds: install needs no service worker.

A project with a self-hosted font adds one `preload` line after the stylesheet
link; [patterns/css-typography.md](../patterns/css-typography.md) defines it,
including why that one URL carries no `?v={{version}}`.

Spot-check markup with https://validator.w3.org/nu/ —
`Attribute "hx-…" not allowed` errors are expected (htmx attributes are not part
of the HTML standard; htmx also accepts the `data-hx-*` spelling if a project
needs a clean report, but the ecosystem-standard `hx-*` wins on maintainability).
Any *other* error gets fixed.
