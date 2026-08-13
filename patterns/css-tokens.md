# Pattern: CSS Tokens (Colors, Spacing, Dark Mode)

**Last verified: 2026-08-13**

The concrete `tokens` layer that [stack/css.md](../stack/css.md) mandates but
leaves open. Copy it as the starting set, then change **values**, never the
role names or the structure — a project inventing its own token vocabulary is
the repeated decision this document exists to stop.

## The tokens layer

Part of the single `web/static/css/app.css`, in the layer order
[stack/css.md](../stack/css.md) prescribes. `--space` and `--measure` are the
same tokens the page shell in [css-layout.md](css-layout.md) consumes:

```css
@layer tokens {
  :root {
    color-scheme: light dark; /* UA widgets (form controls, scrollbars) follow the scheme */

    /* Colors — light scheme. Roles, not values. */
    --color-bg: oklch(99% 0.002 260);
    --color-surface: oklch(96% 0.005 260);   /* cards, table stripes, wells */
    --color-text: oklch(22% 0.02 260);
    --color-text-muted: oklch(45% 0.02 260); /* captions, timestamps, help text */
    --color-accent: oklch(45% 0.17 260);     /* links, primary buttons */
    --color-error: oklch(45% 0.17 25);       /* validation errors */
    --color-border: oklch(62% 0.02 260);     /* form controls, dividers */

    /* Spacing — one fluid gutter, three derived steps. */
    --space: clamp(1rem, 0.5rem + 2vw, 2rem);
    --space-xs: calc(var(--space) / 4);
    --space-sm: calc(var(--space) / 2);
    --space-lg: calc(var(--space) * 2);

    /* Widths — consumed by the page shell (css-layout.md). */
    --measure: 65ch;   /* readable line length for prose */
    --page-max: 80rem; /* page cap for card and sidebar pages */

    /* Type and shape. */
    --font-body: system-ui, sans-serif;
    --font-mono: ui-monospace, monospace;
    --radius: 0.375rem;
  }

  /* Dark scheme = color tokens redefined. Nothing else forks. */
  @media (prefers-color-scheme: dark) {
    :root {
      --color-bg: oklch(18% 0.01 260);
      --color-surface: oklch(24% 0.01 260);
      --color-text: oklch(93% 0.01 260);
      --color-text-muted: oklch(72% 0.02 260);
      --color-accent: oklch(75% 0.12 260);
      --color-error: oklch(75% 0.12 25);
      --color-border: oklch(56% 0.02 260);
    }
  }
}
```

Motion adds two duration tokens (`--motion-fast`, `--motion-slow`) to this
layer — [css-motion.md](css-motion.md) defines them.

A surface style may change ground values and the radius and, in the
neumorphic style, add two shadow roles — [css-surfaces.md](css-surfaces.md)
defines the three sanctioned styles. Minimal (the default) is exactly the
set above.

## Rules

1. **Roles, not values.** A token names the job (`--color-accent`), never the
   color (`--blue-500`) — a value-named token cannot be rethemed without
   renaming every use. To retheme, edit the hue channel in this one layer;
   `layout` and `components` never change.
2. **Components never see a raw color.** A literal `oklch()` or hex value
   outside the `tokens` layer is the tell that a role is missing — add the
   role or reuse one, don't inline the value.
3. **Only color tokens fork for dark mode.** Spacing, widths, fonts, and radii
   are identical in both schemes; a layout that shifts when the scheme changes
   is a bug.
4. **The OS setting is the only switch.** `prefers-color-scheme` +
   `color-scheme: light dark` gives dark mode with zero markup and zero
   script. A manual toggle adds a stored preference and a second theming
   mechanism duplicating `prefers-color-scheme` — machinery the OS setting
   already covers. `light-dark()` MAY later collapse the
   two blocks into one — only inside the `@supports` guard
   [stack/css.md](../stack/css.md) requires.
5. **Derive states, don't multiply tokens.** Hover and active shades come from
   `color-mix()` at the use site
   (`color-mix(in oklch, var(--color-accent), var(--color-text) 15%)`), not
   from new tokens. The set above is 16 tokens, plus the two motion durations;
   treat ~20 as the ceiling — the neumorphic style's two shadow roles
   ([css-surfaces.md](css-surfaces.md)) land exactly on it.
6. **A breakpoint cannot be a token** — media queries cannot read custom
   properties ([css-layout.md](css-layout.md) mobile-first rule 3).
7. **`DESIGN.md` mirrors this layer.** Every CSS value the project's root
   `DESIGN.md` quotes is character-identical to `app.css`, and both files
   change in the same commit; after a color change, re-measure the contrast
   floors `DESIGN.md` records.
   [design-system.md](design-system.md) defines the file. An installable
   project's manifest colors and `theme-color` metas move with `--color-bg`
   in the same commit as well ([pwa.md](pwa.md) rule 3).

## Measured contrast (2026-08-12)

A throwaway script converted the values above oklch → linear sRGB → WCAG
relative luminance and checked every pair:

- Every text role (`text`, `text-muted`, `accent`, `error`) on both
  backgrounds: **≥ 6.6:1** in both schemes — above the 4.5:1 text bar in
  [stack/html.md](../stack/html.md).
- `--color-border` on both backgrounds: **≥ 3.2:1** in both schemes — above
  the 3:1 non-text bar (WCAG 1.4.11) for form-control boundaries.
- The primary-button recipe `background: var(--color-accent);
  color: var(--color-bg)`: **≥ 7.4:1** in both schemes.

After changing any color value, re-check the pairs it participates in — the
margins above are what make small hue adjustments safe, not a license to
darken a background or lighten a text role unchecked.

## Anti-patterns

- ❌ Value-named ladders (`--gray-100` … `--gray-900`) — a palette without
  roles just moves the color decision to every use site.
- ❌ Per-component color tokens (`--card-title-color`) — token explosion;
  components compose the role tokens.
- ❌ Dark mode via `filter: invert()` or per-component `@media` overrides —
  the scheme forks exactly once, in this layer.
- ❌ Opacity for muted text (`opacity: 0.6`) — it dilutes against whatever is
  behind it and breaks the measured pairs; use `--color-text-muted`.
