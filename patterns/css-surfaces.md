# Pattern: CSS Surfaces (Minimal, Neumorphic, Glass)

**Last verified: 2026-08-13**

The one decision this document owns: **how surfaces sit on the page** — cards,
dialogs, buttons, form controls. Three styles are sanctioned: **minimal** (the
default), **neumorphic** (soft raised surfaces — "neumorphism", sometimes
spelled "neomorphism"), and **glass** (translucent panels — "glassmorphism").
A style is a set of token values on the unchanged system, never new machinery:
the roles from [css-tokens.md](css-tokens.md), the layers from
[stack/css.md](../stack/css.md), the components the project already ships.
Layout and motion are style-independent: every style is mobile-first per
[css-layout.md](css-layout.md) and moves per [css-motion.md](css-motion.md).
"Responsive" is not a style — it is mandatory.

## Picking a style

- **One style per project**, chosen at the start, recorded in `DESIGN.md` —
  its Elevation & Depth section names it
  ([design-system.md](design-system.md)). Never a user setting, never per page.
- **Choosing nothing is choosing minimal.** The canonical `DESIGN.md` already
  names minimal, so copying it unchanged records the default.
- **A style composes with a theme.** Theme the hue per
  [design-system.md](design-system.md) rule 4; style the surfaces here. Every
  value a style or theme changes carries the re-measure duty from
  [css-tokens.md](css-tokens.md) — the floors below hold for the starting-set
  hue `260`; a themed project re-measures its own.

## Minimal — the default

Exactly the starting set of [css-tokens.md](css-tokens.md), described by the
canonical `DESIGN.md` in [design-system.md](design-system.md): flat `surface`
panels on the `bg` ground, `border` lines for separation, no shadows,
`0.375rem` radius. Zero extra tokens, zero recipes to copy — the other
patterns already define everything this style needs.

## Neumorphic — raised from the page material

The signature: **surfaces are the page material.** `surface` converges with
`bg` — the role stays, components keep referencing it — and depth comes from a
pair of soft shadows: dark toward the bottom-right, light toward the top-left.

Token deltas against the starting set (every token not shown keeps its
[css-tokens.md](css-tokens.md) value):

```css
@layer tokens {
  :root {
    --color-bg: oklch(94% 0.01 260);      /* near-white leaves no room for the highlight — the ground darkens */
    --color-surface: oklch(94% 0.01 260); /* the signature: same material as the ground */
    --color-border: oklch(60% 0.02 260);  /* darker ground → border darkens to keep its 3:1 */
    --color-shadow: oklch(80% 0.02 260);
    --color-highlight: oklch(100% 0 260);
    --radius: 1rem;                       /* soft depth needs soft corners */
  }

  @media (prefers-color-scheme: dark) {
    :root {
      --color-bg: oklch(20% 0.01 260);      /* two points above minimal's 18% — room below for the shadow */
      --color-surface: oklch(20% 0.01 260);
      --color-shadow: oklch(12% 0.01 260);
      --color-highlight: oklch(28% 0.01 260);
      /* border keeps the starting set's 56% — it clears 3:1 on the 20% ground */
    }
  }
}
```

`--color-shadow` and `--color-highlight` are two new color roles: they fork
for dark mode like every color token, they land in `DESIGN.md`'s frontmatter
in the same commit ([design-system.md](design-system.md) rule 2), and they
take the token count to the ~20 ceiling — which is why there is no third.

The surface recipe — raised at rest, pressed while active. Elements (`dialog`,
`button`) are styled in `base`, class-named components in `components`:

```css
@layer base {
  dialog {
    box-shadow: 0.5rem 0.5rem 1rem var(--color-shadow),
                -0.5rem -0.5rem 1rem var(--color-highlight);
  }

  button {
    box-shadow: 0.25rem 0.25rem 0.5rem var(--color-shadow),
                -0.25rem -0.25rem 0.5rem var(--color-highlight);
  }

  button:active {
    box-shadow: inset 0.25rem 0.25rem 0.5rem var(--color-shadow),
                inset -0.25rem -0.25rem 0.5rem var(--color-highlight);
  }
}

@layer components {
  .card {
    box-shadow: 0.5rem 0.5rem 1rem var(--color-shadow),
                -0.5rem -0.5rem 1rem var(--color-highlight);
  }
}
```

The press needs no motion rules of its own — and gains none from the base
transition list ([css-motion.md](css-motion.md)) either: a shadow list that
flips `inset` is not interpolable (CSS Backgrounds 3), so the pressed state
snaps for every user, motion enabled or not. For an `:active` press, instant
is the right feedback.

Guardrails:

- **Shadows are decoration; boundaries stay.** The shadow colors sit nowhere
  near 3:1 against the ground — they are soft by design. A control identified
  only by the shadow pair fails WCAG 1.4.11, and even a labeled one hides its
  hit area. Form controls and unfilled buttons keep their `--color-border`
  line; primary buttons keep the accent fill. The shadows only add depth.
- **Rows separate by border, not stripes.** With `surface` equal to `bg` the
  table-stripe tint vanishes; tables use `--color-border` lines between rows.
- **The focus ring stays `outline`** ([css-motion.md](css-motion.md)
  transition rule 3) — never an inset-shadow imitation.

## Glass — translucent panels over a tinted ground

The signature: **panels are translucent and blur what is behind them**, and
the page ground carries a soft accent tint so the glass has something to show.

Token deltas (every token not shown keeps the starting set):

```css
@layer tokens {
  :root {
    --color-surface: oklch(96% 0.005 260 / 80%); /* the starting value plus alpha — 80% is a measured floor, not taste */
    --color-border: oklch(60% 0.02 260);         /* 62% reads 2.92 against the fully tinted spot; 60% reads 3.17 */
    --radius: 0.75rem;
  }

  @media (prefers-color-scheme: dark) {
    :root {
      --color-surface: oklch(24% 0.01 260 / 80%);
      /* border keeps the starting set's 56% — it clears 3:1 on every measured ground */
    }
  }
}
```

The ground (`layout` layer). The tint comes from `color-mix()` at its one
use site, never from a token — the same derive-at-use-site discipline as
[css-tokens.md](css-tokens.md) rule 5. The 12% is measured, not taste: the
fully tinted spot is this style's worst ground, and every floor below
includes it:

```css
@layer layout {
  body {
    background:
      radial-gradient(45rem 45rem at 15% 10%,
        color-mix(in oklch, var(--color-bg), var(--color-accent) 12%), transparent),
      radial-gradient(50rem 50rem at 85% 90%,
        color-mix(in oklch, var(--color-bg), var(--color-accent) 12%), transparent),
      var(--color-bg); /* gradient interpolation is premultiplied — 'transparent' does not gray the midpoints */
  }
}
```

The panel recipe (`components` layer):

```css
@layer components {
  .card {
    background: var(--color-surface);
    -webkit-backdrop-filter: blur(1rem); /* Safari before 18 knows only the prefixed name */
    backdrop-filter: blur(1rem);
    border: 1px solid color-mix(in oklch, var(--color-border), var(--color-surface) 50%);
  }
}
```

- `backdrop-filter` is Baseline **Newly available** (September 2024) — usable
  with the graceful fallback [stack/css.md](../stack/css.md) records: the
  floors below are measured on the *unblurred* composite, so a browser
  without the property renders exactly the panel the numbers cover, minus the
  frost.
- The softened `color-mix` edge is decorative and allowed on **cards only** —
  a card boundary carries no information WCAG 1.4.11 protects. Form controls
  keep the full `--color-border`.
- **Glass sits on the page ground only.** Content MUST NOT scroll behind a
  glass panel — no glass sticky header, no glass toolbar over a feed. The
  measured backdrop is the ground; arbitrary content behind a panel makes
  contrast unmeasurable.
- **Dialogs stay opaque:** `dialog { background: var(--color-bg) }`. A modal
  asks for focus, and the page behind a modal is exactly the arbitrary
  backdrop the previous rule forbids.
- **No `prefers-reduced-transparency`** — it is outside the allowed set
  ([stack/css.md](../stack/css.md): not Baseline as of this document's date).
  The 80% alpha floor is the accommodation: panels stay readable for every
  user, which is why thinning the paint below the floor is banned, not
  discouraged.

## Measured contrast (2026-08-13)

The same throwaway-script method as [css-tokens.md](css-tokens.md) — oklch →
linear sRGB → WCAG relative luminance — extended with sRGB alpha compositing
for the glass panels. Worst pairs across both schemes:

- **Neumorphic:** every text role (`text`, `text-muted`, `accent`, `error`)
  on the shared ground ≥ **6.2:1**; `border` ≥ **3.3:1**; the primary button
  ≥ **6.4:1**. The shadow pair is checked only for sRGB gamut — it carries no
  information (guardrail above).
- **Glass:** every text role ≥ **5.9:1** on all four measured grounds — the
  plain `bg`, the fully tinted spot, and the unblurred panel composited over
  each; `border` ≥ **3.1:1** on all four; the primary button ≥ **7.4:1**.

After changing any value — including theming the hue — re-measure the pairs
it participates in. The glass grounds are four, not two.

## Rules

1. **One style per project.** Recorded in `DESIGN.md`, chosen at the start.
   Mixing styles — a glass header over neumorphic cards — is two design
   systems in one app.
2. **A style is values, not machinery.** No style class vocabulary
   (`.glass-card`, `.neu-raised`): the recipes above restyle the components
   the project already has, under their existing names.
3. **Text roles never move.** All three styles keep the starting set's
   `text`, `text-muted`, `accent`, and `error` values — a style moves grounds
   (`bg`, `surface`, `border`) and the radius, and adds decoration. That
   invariant is what keeps the re-measure small.
4. **Boundaries never rely on decoration.** In every style, form controls
   keep a `--color-border` boundary measured at ≥ 3:1 — shadows, highlights,
   and softened edges are additive, never load-bearing.

## Anti-patterns

- ❌ A theme toggle, style toggle, or per-page style — one project, one style,
  one theme ([css-tokens.md](css-tokens.md) rule 4).
- ❌ A neumorphic control whose only boundary is its shadows — an unlabeled
  one fails WCAG 1.4.11, and a labeled one hides its hit area; keep the
  border.
- ❌ Glass over scrolling content or images — the backdrop becomes
  unmeasurable; glass sits on the page ground only.
- ❌ Glass alpha below the measured 80% floor — the composite floors break.
  "Frostier" comes from the blur radius, not from thinner paint.
- ❌ Shadow ladders (`--shadow-sm` … `--shadow-xl`) — minimal has no shadows,
  glass has one decorative edge, neumorphic has exactly two shadow roles.
  An elevation scale is a framework habit, not a role.
