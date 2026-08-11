# Pattern: CSS Layout (Mobile-First, Grid)

**Last verified: 2026-08-11**

The one mechanic that makes pure-CSS layout work: **base styles are the phone
layout; wider screens only add to it.** Layout comes from CSS Grid and Flexbox
with `gap` — never floats, never absolute positioning — and from intrinsic
sizing (`auto-fit`, `minmax()`, `clamp()`) before media queries.

All layout code lives in the one stylesheet [stack/css.md](../stack/css.md)
prescribes. Page scaffolding — the page shell, `.card-list`, `.with-sidebar` —
goes in the `layout` layer, so its width queries stay page-level. Component
blocks — the subgrid card and the container query below — go in the
`components` layer.

## Decision order

1. **Normal flow.** Headings, paragraphs, forms, and lists stack correctly with
   zero layout code. Most markup needs nothing.
2. **Flexbox** — one row or column of content-sized items: toolbars, nav links,
   tag lists. `flex-wrap: wrap` plus `gap` makes them responsive for free.
3. **Grid** — anything two-dimensional, and all page scaffolding.

If a layout seems to need measuring or absolute positioning, redesign it with
these three.

## Mobile-first rules

1. **Base = narrowest.** Base styles — everything outside a media or
   container query — MUST render correctly at 320 px width. Width media
   queries use `min-width` only, and only *widen* the layout — a bare
   `max-width` override is the tell that the base styles are the desktop
   layout. Four `base`-layer declarations keep narrow screens honest.
   `body { overflow-wrap: anywhere }` breaks long unbreakable strings (a
   bare URL) that otherwise scroll the page sideways at any width.
   `img { max-inline-size: 100%; block-size: auto }` shrinks images that
   otherwise widen the page. `input, select, textarea { max-inline-size: 100% }`
   keeps a wide `<select>` from doing the same. In an `fr`-sized track,
   `100%` only helps when the control's grid parent carries the
   `minmax(0, 1fr)` guard the page shell shows. Guarding that grid also
   shields every grid above it.
   `fieldset { min-inline-size: 0 }` removes the browser's min-content
   floor, which otherwise defeats the form-control cap.
2. **Page level only.** Width media queries reshape page scaffolding (the `layout`
   layer). Components adapt with container queries — that split is
   [stack/css.md](../stack/css.md) rule 6.
3. **Few, and content-driven.** Add a breakpoint where the content breaks, not
   per device. Most pages need zero or one. Write them in `em`, so breakpoints
   track the user's font-size setting: `@media (min-width: 48em)`. A
   breakpoint cannot be a token — media queries cannot read custom properties.
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
    grid-template-columns: minmax(0, 1fr); /* implicit column has an auto minimum — a <pre> block would widen it past the viewport */
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

The shell assumes `layout.html`'s markup ([stack/html.md](../stack/html.md)):
`header`, `main`, and `footer` are the only in-flow children of `body`. The
trailing `<script>` renders nothing and takes no row. Any other visible child
takes one: a skip link before `header` hands `1fr` to the wrong element; a
toast appended after `footer` un-pins the footer. Keep such elements off
`body`'s grid: the top layer (`<dialog>`, popover), `position: fixed`, markup
inside `main`, or the `.visually-hidden` off-screen pattern — the skip
link's usual home.

`--measure` caps prose. A page built around a `.card-list` or `.with-sidebar`
needs the full width: cap `main` at a page width instead — a wider token,
e.g. `--page-max: 80rem`. Put `max-inline-size: var(--measure)` on the text
blocks inside it. Inside a 65 ch `main` the card grid below is stuck at one
or two cramped columns. The sidebar's `48em` query — which reads the
viewport, not the container — fires while the content column is still narrow.

## Card grid — zero media queries

The default for any collection of like items (cards, products, thumbnails):

```css
.card-list {
  display: grid;
  grid-template-columns: repeat(auto-fit, minmax(min(100%, 16rem), 1fr));
  gap: var(--space);
  list-style: none; /* the minimal reset keeps ul markers and padding */
  padding: 0;
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
  grid-template-columns: minmax(0, 1fr); /* the stacked state needs the same auto-minimum guard as the shell */
  gap: var(--space);
}

@media (min-width: 48em) {
  .with-sidebar {
    grid-template-columns: minmax(0, 1fr) 16rem;
  }
}
```

`minmax(0, 1fr)` — not bare `1fr` — for the content track: `1fr` means
`minmax(auto, 1fr)`, so a `<pre>` block or a table widens the track and
pushes the sidebar off screen. `minmax(0, 1fr)` lets the content column shrink
and its wide children scroll. A code block scrolls with `overflow-x: auto` on
the `<pre>` itself. A table needs a wrapping `<div>` with `overflow-x: auto`
— `overflow` does not apply to table boxes — plus
`table { overflow-wrap: normal }`, or rule 1's `anywhere` letter-breaks cell
contents instead of letting the wrapper scroll. Long unbreakable strings in
running text need no extra work: rule 1's `overflow-wrap: anywhere` breaks
them.

## Equal-height cards — subgrid

When cards in a `.card-list` have internal parts that should align across the
row (title, body, actions), each card joins the parent's tracks:

```css
.card {
  display: grid;
  grid-template-columns: minmax(0, 1fr); /* same auto-minimum guard as the shell */
  grid-template-rows: subgrid;
  grid-row: span 3; /* title, body, actions — one track each */
  gap: 0.5rem;
}
```

Subgrid needs an unbroken chain of grids from list to card, and the shortest
chain is no wrapper at all: class the `li` (`<li class="card">`). With a
plain wrapper between list and card, `grid-template-rows: subgrid` silently
falls back to `none` — there is no parent grid track to join.

The actions row now sits on one line across the whole row of cards, however
long each body is. Without subgrid this took equal-height hacks or JS.

## Component adaptation — container query

Components respond to the space they are given, not the viewport, so they work
in `main`, in a sidebar, and in any future page unchanged. A container cannot
style itself from its own size, so the query hook sits on the wrapper — here
the list item. The class names differ from the subgrid list's on purpose
(explained below the snippet):

```css
.media-list {
  display: grid;
  gap: var(--space);
  list-style: none; /* the minimal reset keeps ul markers and padding */
  padding: 0;
}

.media-list > li {
  container-type: inline-size;
}

.media-card {
  display: grid;
  gap: var(--space);
}

@container (min-width: 24rem) {
  .media-card {
    grid-template-columns: auto minmax(0, 1fr); /* thumbnail moves beside the text */
  }
}
```

The thumbnail needs `width` and `height` attributes at its display size:
`auto` sizes the first track to the image, and a wide or unsized image
collapses the text track to zero.

Pick one per list — this pattern or subgrid alignment, not both — and keep
the class names apart when a project uses both kinds. Subgrid needs the card
itself to be the grid item spanning the parent's tracks; the container query
needs a wrapper between list and card. Worse than the markup clash:
`container-type` makes the element establish an independent formatting
context, which forces `subgrid` to its `none` fallback. A shared
`.card-list > li` selector would therefore kill the subgrid list's alignment
as silently as a wrapper does.

## Spacing

Space *between* siblings comes from `gap` on the parent — never from margins
on the children. Margins leak at wrap edges and first/last positions; `gap`
cannot. Margins keep two jobs: rhythm between flow content (`h2 + p`) and
centering (`margin-inline: auto`, as in the page shell).
Rhythm selectors written against bare elements reach into every grid — a
`p + p` rule pushes a card's actions down inside its shared subgrid track
and doubles up with `gap`. Scope rhythm to prose containers, or zero margins
on card children (`.card > * { margin-block: 0 }`).

Never give a text container a fixed height. Content determines height;
`min-height` when a floor is needed.

## Anti-patterns

- ❌ Desktop-first `max-width` ladders — the base layout must be the phone layout.
- ❌ Device breakpoints ("tablet", "iPhone") — break where the content breaks.
- ❌ `display: none` per viewport to hide content or features.
- ❌ Fixed pixel widths or heights on containers.
- ❌ A global 12-column system (`.col-md-6`) — that is a framework habit; each
  layout declares the few tracks it actually has.
- ❌ Absolute positioning for layout — it is for overlay decorations (badges,
  status dots) anchored to a `position: relative` parent, and for off-screen
  accessibility hiding (`.visually-hidden`) — never page layout.
