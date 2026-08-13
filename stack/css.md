# Stack: CSS

**Last verified: 2026-08-13 · Target: CSS Baseline "Widely available"**

Pure CSS. No preprocessor (Sass/Less), no framework (Tailwind/Bootstrap), no build
step. The platform has caught up — use it.

## Allowed feature set (safe as of 2026)

Baseline **Widely available** — use freely; they replace what preprocessors and JS
used to do:

| Feature | Replaces |
|---|---|
| Native nesting | Sass nesting |
| Custom properties (`--token`) | Sass variables |
| `color-mix()` and `oklch()` colors | Color functions, manual palettes |
| Container queries (`@container`) | JS resize observers; use over media queries for components |
| `:has()` | JS state classes ("parent selector") |
| Cascade layers (`@layer`) | Specificity wars, `!important` |
| CSS Grid + Subgrid, Flexbox, `gap` | Layout frameworks |
| Logical properties (`margin-inline`, `inset-block`) | Physical LTR-only properties |
| `clamp()`, `min()`, `max()` | JS-computed fluid sizing |
| `prefers-color-scheme`, `prefers-reduced-motion` | JS theme toggles |
| `<dialog>`, `<details>` styling | JS modal/disclosure libraries |
| `scroll-behavior`, scroll snap | JS scroll libraries |

Baseline **Newly available** as of 2026 — usable only with the stated graceful
fallback, per the rule below:

| Feature | Required fallback |
|---|---|
| `light-dark()` | Dark-mode tokens defined under `@media (prefers-color-scheme: dark)` stay the working mechanism; a `light-dark()` token enhancement MUST sit inside `@supports (color: light-dark(red, red))` — unguarded it wins the cascade even in browsers that can't evaluate it, because custom properties fail at `var()` substitution time (→ `unset`), not at parse time |
| `@property` | The plain `--token` declaration exists regardless; `@property` adds typing/animation only |
| View Transitions (same-document) | Inherently graceful — unsupported browsers swap without animating; no extra work |
| `@starting-style` | Inherently graceful — unsupported browsers show the element fully formed without the entry animation; no extra work |
| `@scope` | Nesting + component class scoping (rule 2) |
| `backdrop-filter` | The glass surface style's panels stay translucent without the blur — its contrast floors are measured on the unblurred composite, so the fallback is the measured state ([patterns/css-surfaces.md](../patterns/css-surfaces.md)); Safari before 18 needs the `-webkit-` prefix alongside |

Check anything newer at https://web.dev/baseline before use: **"Widely available" MAY
be used; "Newly available" only with a graceful fallback; otherwise MUST NOT.**

## File architecture

One embedded stylesheet, organized by cascade layers — the layer order *is* the architecture:

```
web/static/css/app.css

@layer reset, tokens, base, layout, components, utilities;
```

- **reset** — minimal modern reset (box-sizing, margin trim). Trim margins
  with an element list, never `* { margin: 0 }` — the universal trim strips the
  UA's `dialog { margin: auto }` centering.
- **tokens** — all custom properties on `:root`: colors (oklch), spacing
  scale, widths, font stacks, radii, motion durations. Dark mode via
  `color-scheme: light dark` + token redefinition under
  `@media (prefers-color-scheme: dark)`; `light-dark()` only
  inside an `@supports (color: light-dark(red, red))` guard (Baseline Newly —
  the table above explains why the guard is not optional). The concrete
  starting set, with measured contrast:
  [patterns/css-tokens.md](../patterns/css-tokens.md).
- **base** — element defaults: typography, links, forms.
- **layout** — page scaffolding: grid shells, headers, content widths.
- **components** — one nested block per component, class-named (`.card`, `.board`).
- **utilities** — the few single-purpose helpers (`.visually-hidden`) and the
  view-transition kill switch ([patterns/css-motion.md](../patterns/css-motion.md)).
  Keep under ~10.

Rules:

1. **System font stack by default** (`font-family: system-ui, sans-serif`). Self-host
   any web font; MUST NOT load fonts from third-party origins.
2. **Class naming:** simple, semantic, component-scoped (`.board-cell`, not BEM
   ceremony, not utility soup). Nesting keeps scope; `@scope` (Baseline Newly —
   see the table above) only when bleed is a real, demonstrated risk.
3. **Specificity:** selectors stay at one class deep where possible; layers resolve
   conflicts. `!important` is banned outside `utilities`.
4. **Every interactive state in CSS:** `:hover`, `:focus-visible`, `:active`,
   `:disabled`, plus htmx's loading states — `app.css` MUST define them itself
   (`.htmx-indicator { opacity: 0 }`, shown while `.htmx-request` is active), because
   htmx's built-in inline indicator styles are disabled for CSP
   (see [htmx.md](htmx.md)).
5. **Motion:** transitions/animations MUST be wrapped in
   `@media (prefers-reduced-motion: no-preference)`. The one exception is the
   view-transition kill switch, which sits under `(prefers-reduced-motion:
   reduce)` because it cancels animations the browser declares, not ones
   `app.css` does. Durations, the indicator fade, view-transition swaps,
   dialog entry: [patterns/css-motion.md](../patterns/css-motion.md).
6. **Responsive:** mobile-first — base styles are the 320 px layout, `min-width`
   media queries only widen it. Container queries for components, media queries
   only for page-level layout. Fluid type/spacing with `clamp()` — avoid
   breakpoint ladders. Copyable layouts (page shell, card grid, sidebar):
   [patterns/css-layout.md](../patterns/css-layout.md).
7. **The theme lives in `DESIGN.md`.** Every project records its token values,
   measured contrast, and component inventory in a `DESIGN.md` at the repo
   root, lockstep with this stylesheet — value changed in one, same commit
   changes the other: [patterns/design-system.md](../patterns/design-system.md).
8. **Surfaces come from one sanctioned style.** Cards, dialogs, buttons, and
   controls sit on the page in the project's one surface style — minimal (the
   default), neumorphic, or glass. The recipes and their accessibility
   guardrails: [patterns/css-surfaces.md](../patterns/css-surfaces.md).
