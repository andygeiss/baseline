# Pattern: CSS Layout (Mobile-First, Grid)

**Last verified: 2026-08-11**

The one mechanic that makes pure-CSS layout work: **base styles are the phone
layout; wider screens only add to it.** Layout comes from CSS Grid and Flexbox
with `gap` — never floats, never absolute positioning — and from intrinsic
sizing (`auto-fit`, `minmax()`, `clamp()`) before media queries.

All layout code lives in the `layout` and `components` layers of the one
stylesheet [stack/css.md](../stack/css.md) prescribes.

## Decision order

1. **Normal flow.** Headings, paragraphs, forms, and lists stack correctly with
   zero layout code. Most markup needs nothing.
2. **Flexbox** — one row or column of content-sized items: toolbars, nav links,
   tag lists. `flex-wrap: wrap` plus `gap` makes them responsive for free.
3. **Grid** — anything two-dimensional, and all page scaffolding.

If a layout seems to need measuring or absolute positioning, redesign it with
these three.

## Mobile-first rules

1. **Base = narrowest.** Unprefixed styles MUST render correctly at 320 px
   width. Media queries use `min-width` only, and only *widen* the layout —
   a `max-width` query means the base styles were written desktop-first.
2. **Page level only.** Media queries reshape page scaffolding (the `layout`
   layer). Components adapt with container queries — that split is
   [stack/css.md](../stack/css.md) rule 6.
3. **Few, and content-driven.** Add a breakpoint where the content breaks, not
   per device. Most pages need zero or one. Write them in `em` — media queries
   cannot read custom properties: `@media (min-width: 48em)`.
4. **Same content at every width.** A media query rearranges; it MUST NOT hide
   content or features. If something is worth hiding on phones, delete it.

## Page shell

The `layout`-layer scaffold every page shares — header, content, footer, with
the footer pinned to the bottom of short pages:

```css
@layer layout {
  body {
    min-height: 100dvh; /* not 100vh: on phones vh includes the browser chrome */
    display: grid;
    grid-template-rows: auto 1fr auto; /* header, main, footer */
  }

  main {
    inline-size: min(100% - 2 * var(--space), var(--measure));
    margin-inline: auto;
  }
}
```

`--space` (fluid gutter) and `--measure` (readable line length, e.g. `65ch`)
are `tokens`-layer custom properties:

```css
--space: clamp(1rem, 0.5rem + 2vw, 2rem);
--measure: 65ch;
```

`dvh` only ever appears with `min-height`. A fixed `height: 100dvh` makes the
page jump while phone browser chrome shows and hides.

## Card grid — zero media queries

The default for any collection of like items (cards, products, thumbnails):

```css
.card-list {
  display: grid;
  grid-template-columns: repeat(auto-fit, minmax(min(100%, 16rem), 1fr));
  gap: var(--space);
}
```

- `auto-fit` adds and removes columns as the width changes — one column on a
  phone, four on a desktop, no breakpoints.
- `min(100%, 16rem)` is the load-bearing part: a bare `minmax(16rem, 1fr)`
  overflows any container narrower than 16 rem and breaks the 320 px rule.

## Sidebar — the one media query

Content plus a sidebar stacks on phones and splits on wide screens. Source
order does the stacking; one query does the split:

```css
.with-sidebar {
  display: grid;
  gap: var(--space);
}

@media (min-width: 48em) {
  .with-sidebar {
    grid-template-columns: minmax(0, 1fr) 16rem;
  }
}
```

`minmax(0, 1fr)` — not bare `1fr` — for the content track: `1fr` means
`minmax(auto, 1fr)`, so one long URL or `<pre>` block widens the track and
pushes the sidebar off screen. `minmax(0, 1fr)` lets the content column shrink
and its wide children scroll (`overflow-x: auto` on the table or code block
itself).

## Equal-height cards — subgrid

When cards in a `.card-list` have internal parts that should align across the
row (title, body, actions), each card joins the parent's tracks:

```css
.card {
  display: grid;
  grid-template-rows: subgrid;
  grid-row: span 3; /* title, body, actions — one track each */
  gap: 0.5rem;
}
```

The actions row now sits on one line across the whole row of cards, however
long each body is. Without subgrid this took equal-height hacks or JS.

## Component adaptation — container query

Components respond to the space they are given, not the viewport, so they work
in `main`, in a sidebar, and in any future page unchanged. A container cannot
style itself from its own size, so the query hook sits on the wrapper — here
the list item:

```css
.card-list > li {
  container-type: inline-size;
}

.card {
  display: grid;
  gap: var(--space);
}

@container (min-width: 24rem) {
  .card {
    grid-template-columns: auto 1fr; /* thumbnail moves beside the text */
  }
}
```

Pick one per list — this pattern or subgrid alignment, not both. Subgrid needs
the card itself to be the grid item spanning the parent's tracks; the container
query needs a wrapper between list and card. One list cannot satisfy both.

## Spacing

Space *between* siblings comes from `gap` on the parent — never from margins
on the children. Margins leak at wrap edges and first/last positions; `gap`
cannot. Margins remain for one job: space between flow content (`h2 + p`
rhythm in the `base` layer).

Never give a text container a fixed height. Content determines height;
`min-height` when a floor is needed.

## Anti-patterns

- ❌ Desktop-first `max-width` ladders — the base layout must be the phone layout.
- ❌ Device breakpoints ("tablet", "iPhone") — break where the content breaks.
- ❌ `display: none` per viewport to hide content or features.
- ❌ Fixed pixel widths or heights on containers.
- ❌ A global 12-column system (`.col-md-6`) — that is a framework habit; each
  layout declares the few tracks it actually has.
- ❌ Absolute positioning for layout — it is for overlays (badges, popovers)
  anchored to a `position: relative` parent, nothing else.
