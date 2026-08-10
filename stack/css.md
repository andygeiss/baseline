# Stack: CSS

**Last verified: 2026-08-10 · Target: CSS Baseline "Widely available"**

Pure CSS. No preprocessor (Sass/Less), no framework (Tailwind/Bootstrap), no build
step. The platform has caught up — use it.

## Allowed feature set (Baseline, safe as of 2026)

Use these freely; they replace what preprocessors and JS used to do:

| Feature | Replaces |
|---|---|
| Native nesting | Sass nesting |
| Custom properties (`--token`) + `@property` | Sass variables |
| `color-mix()` and `oklch()` colors | Color functions, manual palettes |
| Container queries (`@container`) | JS resize observers; use over media queries for components |
| `:has()` | JS state classes ("parent selector") |
| Cascade layers (`@layer`) | Specificity wars, `!important` |
| CSS Grid + Subgrid, Flexbox, `gap` | Layout frameworks |
| Logical properties (`margin-inline`, `inset-block`) | Physical LTR-only properties |
| `clamp()`, `min()`, `max()` | JS-computed fluid sizing |
| View Transitions (same-document) | JS animation libraries — pairs with htmx swaps |
| `prefers-color-scheme`, `prefers-reduced-motion`, `light-dark()` | JS theme toggles |
| `<dialog>`, `popover`, `<details>` styling | JS modal/dropdown libraries |
| `scroll-behavior`, scroll snap | JS scroll libraries |

Check anything newer at https://web.dev/baseline before use: **"Widely available" MAY
be used; "Newly available" only with a graceful fallback; otherwise MUST NOT.**

## File architecture

One embedded stylesheet, organized by cascade layers — the layer order *is* the architecture:

```
web/static/css/app.css

@layer reset, tokens, base, layout, components, utilities;
```

- **reset** — minimal modern reset (box-sizing, margin trim).
- **tokens** — all custom properties on `:root`: colors (oklch), spacing scale,
  font stacks, radii. Dark mode via `light-dark()` + `color-scheme: light dark`.
- **base** — element defaults: typography, links, forms.
- **layout** — page scaffolding: grid shells, headers, content widths.
- **components** — one nested block per component, class-named (`.card`, `.board`).
- **utilities** — the few single-purpose helpers (`.visually-hidden`). Keep under ~10.

Rules:

1. **System font stack by default** (`font-family: system-ui, sans-serif`). Self-host
   any web font; MUST NOT load fonts from third-party origins.
2. **Class naming:** simple, semantic, component-scoped (`.board-cell`, not BEM
   ceremony, not utility soup). Nesting keeps scope; `@scope` when bleed is a real risk.
3. **Specificity:** selectors stay at one class deep where possible; layers resolve
   conflicts. `!important` is banned outside `utilities`.
4. **Every interactive state in CSS:** `:hover`, `:focus-visible`, `:active`,
   `:disabled`, plus htmx's `.htmx-request` for loading states.
5. **Motion:** transitions/animations MUST be wrapped in
   `@media (prefers-reduced-motion: no-preference)`.
6. **Responsive:** container queries for components, media queries only for page-level
   layout. Fluid type/spacing with `clamp()` — avoid breakpoint ladders.
