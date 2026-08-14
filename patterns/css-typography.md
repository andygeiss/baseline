# Pattern: CSS Typography (Type Scale, Self-Hosted Fonts)

**Last verified: 2026-08-14**

The one decision this document owns: **how type is set** — which families, which
sizes, and what happens when a brand needs a font the operating system does not
have. [css-tokens.md](css-tokens.md) declares `--font-body` and `--font-mono`;
this document is what consumes them and the only place a web font may enter.

The default answer is the system font stack. It costs zero requests, shifts
nothing, and already looks native on every device. A web font is a brand
decision with a price, and the price is paid on the first paint.

## The scale

There are no size tokens. Sizes are fluid `clamp()` expressions on the elements
themselves, in the `base` layer, so type tracks both the viewport and the
user's font-size setting:

```css
@layer base {
  html {
    font-family: var(--font-body);
    line-height: 1.5;
    /* No font-size here — the UA default IS the user's chosen size. */
  }

  h1, h2, h3, h4, h5, h6 {
    line-height: 1.2;
    text-wrap: balance; /* Baseline Newly — older browsers just wrap normally */
  }

  h1 { font-size: clamp(1.75rem, 1.2rem + 2.4vw, 2.5rem) }
  h2 { font-size: clamp(1.375rem, 1.1rem + 1.2vw, 1.875rem) }
  h3 { font-size: clamp(1.125rem, 1rem + 0.5vw, 1.375rem) }
  h4, h5, h6 { font-size: 1rem } /* the UA shrinks h5 and h6 under body text */

  small { font-size: 0.875em }

  code, kbd, pre, samp {
    font-family: var(--font-mono);
    font-size: 0.9375em; /* mono faces run large; em so nesting compounds correctly */
  }

  input, button, select, textarea {
    font: inherit; /* UA controls use a small system face and ignore the page's */
  }

  th, td {
    font-variant-numeric: tabular-nums; /* digits share a width, so columns line up */
  }
}
```

The `rem` term in every `clamp()` is load-bearing, not decoration: a size built
from `vw` alone ignores the user's font-size setting and fails WCAG 1.4.4. The
`vw` term widens the type on wide screens; the `rem` term is what keeps it
zoomable.

`font: inherit` joins the other base-layer rules on these same elements — the
four declarations [css-layout.md](css-layout.md) rule 1 prescribes, the
`button` rule in [css-icons.md](css-icons.md) — and never replaces them. Each
sets different properties.

Line length is not set here. Prose is capped at `--measure` by the page shell
in [css-layout.md](css-layout.md).

## A brand font, self-hosted

Only when the brand requires it, and only ever from this origin — a font from a
third-party host is banned by [stack/css.md](../stack/css.md) rule 1, leaks
every visitor to that host, and would need a `font-src` hole the policy in
[security-headers.md](security-headers.md) does not have. A self-hosted font
needs no CSP change at all.

One **variable** family, as WOFF2, embedded in the binary from
`web/static/fonts/` like every other asset
([go-project-layout.md](go-project-layout.md) rule 5):

```css
/* Above the @layer block: @font-face is not a style rule, so it needs no layer. */
@font-face {
  font-family: "Brand";
  src: url("/static/fonts/brand-1.woff2") format("woff2");
  font-weight: 400 700; /* one file covers the range — never four static weights */
  font-style: normal;
  font-display: optional;
}
```

`font-style: normal` describes this face, not the family. A page that
italicizes anything — `<em>`, `<cite>` — needs the family's italic file in a
second `@font-face` with `font-style: italic`. Without it the browser slants
the roman itself, and a slanted roman is not an italic (rule 5). Only the
roman is preloaded: italic is rare enough on a page that it can wait for the
next view, which is what `font-display: optional` gives it anyway.

One token value then names it, and nothing else in the stylesheet changes —
the fallback stays in the stack, because with `font-display: optional` it is
what the first page view actually renders:

```css
@layer tokens {
  :root {
    --font-body: "Brand", system-ui, sans-serif;
  }
}
```

The head gains one line, after the stylesheet link
([stack/html.md](../stack/html.md)):

```html
<link rel="preload" href="/static/fonts/brand-1.woff2" as="font" type="font/woff2" crossorigin>
```

Three things about that line and the URL in it:

- **`crossorigin` is required even though the file is same-origin.** Fonts are
  always fetched in CORS mode. Without the attribute the preload lands in a
  different cache slot than the real request, so the browser downloads the font
  twice and the preload buys nothing.
- **Neither URL carries `?v={{version}}`.** `app.css` is a static file, so it
  cannot call the `version` template function — the same limit
  [pwa.md](pwa.md) hits with manifest icons. The preload href must match the
  `@font-face` `src` byte for byte or it fetches twice, so the template side
  drops the buster too.
- **A changed font file therefore gets a new filename** (`brand-2.woff2`), in
  both places, in the same commit — [pwa.md](pwa.md) rule 4's mechanism. The
  `immutable` cache is forever; a renamed file is the only way past it.

Serving the file takes one line at boot. Go's built-in mime table has no
`.woff2` entry, and on Unix `mime.TypeByExtension` also merges the host's own
mime files — so without this line the served type depends on the machine, the
same trap [pwa.md](pwa.md) documents for `.webmanifest`. Register it in
`cmd/server/main.go`, beside that one:

```go
// Go's built-in mime table has no .woff2 entry, and the system mime files it
// merges on Unix vary by host. The error is impossible for these literals.
_ = mime.AddExtensionType(".woff2", "font/woff2")
```

**`font-display: optional` is the rule, and the reason is the allowed feature
set.** `optional` gives the font a brief window; if it misses, the fallback
renders for that whole page view and the font — now cached — applies on the
next one. No flash, no reflow, no layout shift, ever. The usual alternative,
`swap` plus a metric-matched fallback face, is not available here: matching
metrics needs the `ascent-override`, `descent-override`, and
`line-gap-override` descriptors, which Safari has never shipped. They are
Baseline **Limited**, so [stack/css.md](../stack/css.md) rules them out.
`size-adjust` did reach Safari 17, but on its own it only scales the fallback:
the line boxes still move when the real font arrives. Without metric matching,
`swap` reflows the page under the reader's eyes.

Subsetting is a one-time act with any tool, like the icon export in
[pwa.md](pwa.md): run it once, commit the `.woff2`, record the tool and the
ranges in `DESIGN.md`. Subset to a character *range*, never to the strings on
today's pages — anything a user typed brings characters the UI never uses, and
a missing glyph drops that word into a different font mid-sentence. A single
subset needs no `unicode-range`: that descriptor exists to split a family
across several files, which is machinery this stack does not need.

## Rules

1. **The system stack is the default.** A web font is added deliberately,
   named in `DESIGN.md`, and justified in the project README like any other
   dependency.
2. **Never set a root `font-size`.** Not in `px`, and not the `62.5%` trick —
   both override the size the user chose in their browser. Body copy is
   `1rem`, and never smaller — the `em` steps above (`small`, code) size
   against the text they sit in, not against a shrunken body.
3. **No size tokens, no modular scale.** Sizes are `clamp()` on the element,
   and every `clamp()` keeps a `rem` term (WCAG 1.4.4). A `--text-*` ladder is
   the value-named token the role discipline in
   [css-tokens.md](css-tokens.md) rejects.
4. **Two families, at most.** `--font-body` and `--font-mono`. A third family
   is a design decision to make in `DESIGN.md`, not a token to add — the ~20
   token ceiling is real.
5. **Self-hosted, WOFF2, variable, `font-display: optional`.** One file per
   style, never a set of static weights. Italic is its own style: ship that
   file too, or don't italicize. Check the weight axis covers what the design
   uses. Whatever a face is missing the browser fakes — a slanted roman for
   italic, a smeared regular for bold.
6. **Font URLs carry no version query, so font files version by name.** The
   preload href and the `@font-face` `src` are byte-identical, and both change
   together when the file does.
7. **`text-wrap: balance` on headings only.** It is Baseline Newly and
   inherently graceful. `text-wrap: pretty` and `text-box` are still Baseline
   Limited — [stack/css.md](../stack/css.md) puts them out of the set.
8. **Lockstep with `DESIGN.md`.** The font stacks are two of the seventeen
   theme values ([design-system.md](design-system.md) rule 1): a stack changed
   in `app.css` is changed in `DESIGN.md`'s frontmatter and its Typography
   prose in the same commit.

## Anti-patterns

- ❌ Google Fonts, Adobe Fonts, or any third-party font origin — a second
  connection on the critical path, every visitor's IP handed to a third party,
  and a CSP exception to keep forever.
- ❌ `@import url(...)` for a font — it serializes the fetch behind the
  stylesheet parse. `@font-face` in `app.css` is already the one request.
- ❌ `html { font-size: 62.5% }` so `1rem` means `10px` — it silently shrinks
  type for everyone who raised their default size.
- ❌ `font-size` in `px` — it ignores the user's font-size setting; only page
  zoom rescues it.
- ❌ A size-token ladder (`--text-xs` … `--text-4xl`) — a framework habit; the
  three heading clamps above are the whole scale.
- ❌ Four static weight files (`400`, `500`, `600`, `700`) — four requests and
  four caches for what one variable axis covers.
- ❌ `font-display: block` (invisible text while loading) or `swap` (reflow
  mid-read, because metric overrides are unavailable).
- ❌ An icon font — icons are CSS masks ([css-icons.md](css-icons.md)).

## Facts verified (2026-08-13)

- `text-wrap: balance` Baseline **Newly available** since 2024-05-13, Safari
  17.5 last: https://webstatus.dev/features/text-wrap-balance
- `text-wrap: pretty` and `text-box` Baseline **Limited** — neither ships in
  Firefox: https://webstatus.dev/features/text-wrap-pretty and
  https://webstatus.dev/features/text-box
- `ascent-override`, `descent-override`, and `line-gap-override` ship in no
  Safari version, so metric matching is Baseline **Limited**;
  `size-adjust` alone landed in Safari 17:
  https://webstatus.dev/features/font-metric-overrides
- `font-display: optional` has no swap period — a font that misses the block
  window is skipped for that page view:
  https://developer.mozilla.org/en-US/docs/Web/CSS/@font-face/font-display
- `.woff2` is absent from Go's built-in mime table (`src/mime/type.go`, Go
  1.26.5). `mime.TypeByExtension(".woff2")` returns `font/woff2` on this Mac
  only because `/etc/apache2/mime.types` carries the entry — the host
  dependency [pwa.md](pwa.md) documents.
