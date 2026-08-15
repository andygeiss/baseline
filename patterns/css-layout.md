# Pattern: CSS Layout (Mobile-First, Grid)

**Last verified: 2026-08-15**

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

## Bottom navigation — the fixed bar

An app whose pages are places rather than documents navigates from a bar fixed
to the bottom of the screen, where the thumb already is. The bar is
`position: fixed`, so it takes no space in the flow. The page shell above needs
no change: `<footer>` stays a grid item, and with its only child out of flow it
collapses to a zero-height row.

```css
@layer layout {
  footer nav {
    position: fixed;
    inset-block-end: 0;
    inset-inline: 0;
    display: flex;
    justify-content: space-around;
    padding-block: var(--space-xs);
    /* Without the inset the phone's home indicator sits on the last row of targets. */
    padding-block-end: calc(var(--space-xs) + env(safe-area-inset-bottom));
    border-block-start: 1px solid var(--color-border);
    background: var(--color-surface); /* opaque: the page scrolls behind the bar */
  }

  footer nav a {
    display: flex;
    flex-direction: column; /* icon over word */
    align-items: center;
    gap: 0.125rem;
    min-inline-size: 3.5rem;
    min-block-size: 3.5rem; /* 56px — the target size, not the 44px floor */
    padding: var(--space-xs);
    font-size: 0.8125rem;
    text-decoration: none;
    color: var(--color-text-muted);
  }

  /* The one control where the icon outgrows its label: the icon is what the
     thumb aims at, the word only names it (css-icons.md rule 4). */
  footer nav a .icon { font-size: 1.5em }

  footer nav a[aria-current="page"] {
    color: var(--color-accent);
    font-weight: 600;
  }
}
```

`main` reserves the bar's height, or the last card ends up underneath it:
`padding-block-end: calc(6rem + env(safe-area-inset-bottom))`.

Each link carries an icon span and a word, and the server marks the current
one — the markup [css-icons.md](css-icons.md) and
[stack/html.md](../stack/html.md) prescribe:

```html
<footer>
  <nav aria-label="Main">
    <a href="/inbox" aria-current="page">
      <span class="icon icon-inbox" aria-hidden="true"></span>Inbox
    </a>
    …
  </nav>
</footer>
```

Five rules hold the bar together:

1. **Every destination keeps its word.** An icon-only bar is a guessing game
   for everything past the house and the person glyph — an inbox tray, a star,
   and a check mark name no destination on their own, and a first-time user
   learns them by tapping. `aria-label` fixes the screen reader and nothing
   else. Both platform conventions agree (Apple HIG tab bars, Material bottom
   navigation): the label stays.
2. **Grow the box, never drop the label.** A bigger glyph adds no hit area —
   the target is the `<a>` box. 44 px is the floor (WCAG 2.5.5, Apple's 44 pt,
   Google's 48 dp; WCAG 2.5.8 AA asks only 24 px); a primary destination gets
   `3.5rem`. Whoever wants a bigger bar raises `min-block-size`.
3. **Five destinations at most.** Five 56 px targets fit a 320 px screen with
   room to spare (64 px each); six do not. A sixth destination belongs on a
   page, not in the bar — and a bar that hides destinations on phones breaks
   mobile-first rule 4 above.
4. **The current destination is marked twice over.** `aria-current="page"`
   names it, and color *plus* weight show it — color alone would be the
   distinction WCAG 1.4.1 forbids, and dropping the word (rule 1) leaves
   nothing but color.
5. **The bar is opaque.** Content scrolls behind it, so a translucent one has
   no measurable backdrop ([css-surfaces.md](css-surfaces.md)) and a raised or
   frosted one smears whatever passes underneath.

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
- **Every list that drops its markers carries `role="list"`** — this one and
  the `.media-list` below. Safari hands a list whose markers are gone to
  VoiceOver as plain content, so "list, 6 items" is never announced. It is the
  one place [stack/html.md](../stack/html.md)'s first rule of ARIA sends you to
  ARIA anyway: nothing native puts the semantics back. (A list inside `<nav>`
  keeps them — the bottom bar above needs nothing.)

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
- ❌ An icon-only bottom bar, or a taller icon buying a bigger tap target — the
  word stays under the glyph, and the target grows through the `<a>` box.
- ❌ Absolute positioning for layout — it is for overlay decorations (badges,
  status dots) anchored to a `position: relative` parent, and for off-screen
  accessibility hiding (`.visually-hidden`) — never page layout.
