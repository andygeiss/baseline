# Pattern: CSS Icons (Mask, currentColor)

**Last verified: 2026-08-15**

The one decision this document owns: **how an icon gets onto the page.** Every
icon is a CSS mask — one shared `.icon` rule plus one custom property per
shape, all inside the single `web/static/css/app.css`. Nothing is fetched,
nothing is bundled, nothing is scripted. An icon takes its color from the text
around it and its size from that text's font size, so it fits every theme
([css-tokens.md](css-tokens.md)) and every surface style
([css-surfaces.md](css-surfaces.md)) without being told about either.

CSS masking became Baseline **Widely available** on 2026-06-07 (Chrome 120,
Safari 15.4, Firefox 53). It is in the allowed set
[stack/css.md](../stack/css.md) defines — unprefixed, with no fallback duty.
The `-webkit-mask` prefix is for Safari 15.3 and older; do not ship it.

## The mechanism

One rule carries every icon. It lives in the `components` layer:

```css
@layer components {
  .icon {
    display: inline-block;
    inline-size: 1em;
    block-size: 1em;
    flex-shrink: 0;          /* a 1em box in a flex row must not be squeezed */
    vertical-align: -0.125em; /* optical center against lowercase text */
    background-color: currentColor;
    mask: var(--icon) center / contain no-repeat;
  }

  /* Forced colors replaces author background colors with system ones, so
     currentColor never survives to paint the shape. A system keyword does. */
  @media (forced-colors: active) {
    .icon { background-color: CanvasText }
  }
}
```

The shape is the mask; the paint is `currentColor`. A missing `--icon` fails
loudly — the span renders as a solid 1em square — which is what you want from a
typo.

Controls put the icon beside their label, in the `base` layer:

```css
@layer base {
  button {
    display: inline-flex;
    align-items: center;
    justify-content: center; /* inline-flex starts at flex-start; buttons center */
    gap: var(--space-xs);
  }
}
```

## The starting set

Eight icons on Lucide's conventions: a 24-unit grid, a 2-unit stroke, round
caps and joins. Copy what the project needs, delete the rest, and keep
Lucide's license notice in the project README — the duty the next section
states for any pack:

```css
@layer components {
  .icon-check { --icon: url("data:image/svg+xml,%3Csvg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 24 24' fill='none' stroke='black' stroke-width='2' stroke-linecap='round' stroke-linejoin='round'%3E%3Cpath d='M20 6 9 17l-5-5'/%3E%3C/svg%3E") }
  .icon-x { --icon: url("data:image/svg+xml,%3Csvg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 24 24' fill='none' stroke='black' stroke-width='2' stroke-linecap='round' stroke-linejoin='round'%3E%3Cpath d='M18 6 6 18M6 6l12 12'/%3E%3C/svg%3E") }
  .icon-chevron { --icon: url("data:image/svg+xml,%3Csvg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 24 24' fill='none' stroke='black' stroke-width='2' stroke-linecap='round' stroke-linejoin='round'%3E%3Cpath d='m6 9 6 6 6-6'/%3E%3C/svg%3E") }
  .icon-menu { --icon: url("data:image/svg+xml,%3Csvg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 24 24' fill='none' stroke='black' stroke-width='2' stroke-linecap='round' stroke-linejoin='round'%3E%3Cpath d='M4 6h16M4 12h16M4 18h16'/%3E%3C/svg%3E") }
  .icon-search { --icon: url("data:image/svg+xml,%3Csvg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 24 24' fill='none' stroke='black' stroke-width='2' stroke-linecap='round' stroke-linejoin='round'%3E%3Ccircle cx='11' cy='11' r='8'/%3E%3Cpath d='m21 21-4.3-4.3'/%3E%3C/svg%3E") }
  .icon-plus { --icon: url("data:image/svg+xml,%3Csvg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 24 24' fill='none' stroke='black' stroke-width='2' stroke-linecap='round' stroke-linejoin='round'%3E%3Cpath d='M12 5v14M5 12h14'/%3E%3C/svg%3E") }
  .icon-trash { --icon: url("data:image/svg+xml,%3Csvg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 24 24' fill='none' stroke='black' stroke-width='2' stroke-linecap='round' stroke-linejoin='round'%3E%3Cpath d='M3 6h18M8 6V4h8v2M19 6l-1 14H6L5 6'/%3E%3C/svg%3E") }
  .icon-alert { --icon: url("data:image/svg+xml,%3Csvg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 24 24' fill='none' stroke='black' stroke-width='2' stroke-linecap='round' stroke-linejoin='round'%3E%3Cpath d='M12 3 2 20h20z'/%3E%3Cpath d='M12 10v4M12 17.5h.01'/%3E%3C/svg%3E") }
}
```

All eight together are about 2 KB of `app.css`, before the proxy compresses it
([go-performance.md](go-performance.md)). One shape covers four directions —
rotate `.icon-chevron` at the use site rather than adding three more masks. CSS
rotates clockwise, so from the down-pointing default `90deg` points it left,
`-90deg` right, and `180deg` up.

## Adding an icon

The SVG goes into the URL as text, not base64 — a percent-encoded shape stays
readable and diffable in review. Four mechanical rules make it work:

1. **Keep `xmlns='http://www.w3.org/2000/svg'`.** A standalone SVG document
   without it does not parse, and an image that does not parse is a fully
   transparent one — so the icon vanishes. That is the opposite tell from a
   missing `--icon`, which leaves the solid square above: gone means the shape
   is broken, square means the name is.
2. **Single quotes inside the SVG**, double quotes around the CSS `url()`.
3. **Percent-encode `<` → `%3C`, `>` → `%3E`, and `%` → `%25`.** Nothing else
   needs it.
4. **Never a `#` in the data URI** — it starts a URL fragment and truncates the
   icon. `stroke='black'` is why the set above has none; a color would need
   `%23`, and the mask discards it anyway.

Path data taken from an icon pack (Lucide, Feather, Bootstrap Icons — all MIT
or ISC) is copied into `app.css` as paths, never installed: there is no npm in
this stack. Keep the pack's license notice in the project README when its
geometry ships.

**These `data:` URLs are a CSP dependency.** The browser checks CSS image loads
against `img-src`, so the policy MUST carry `img-src 'self' data:` — under a
bare `default-src 'self'` every icon on the page is blocked and the app renders
with holes where the shapes should be. [security-headers.md](security-headers.md)
owns that policy; anyone tightening it starts here.

## Rules

1. **The icon is decoration; the accessible name lives on the control.** The
   span is always `aria-hidden="true"`. The shape lives in a CSS mask, so
   there is nothing inside the element for assistive technology to read in the
   first place — the attribute states that this is deliberate and keeps the
   empty span out of the control's accessible name for good. An icon-only
   control carries the name itself:

   ```html
   <!-- Label present: the text names the action, the icon decorates it. -->
   <button type="submit">
     <span class="icon icon-check" aria-hidden="true"></span>
     Save
   </button>

   <!-- Icon only: the name moves onto the control. -->
   <button type="submit" aria-label="Delete game">
     <span class="icon icon-trash" aria-hidden="true"></span>
   </button>
   ```

   Prefer the labeled form. `aria-label` is the ARIA patch
   ([stack/html.md](../stack/html.md): first rule of ARIA), correct here
   because no native mechanism names a control that has no text.
2. **Never information by icon alone.** A row whose state is *only* a check or
   an alert triangle fails WCAG 1.1.1 — the meaning has no text equivalent.
   Pair a meaningful icon with words, or put the meaning in the control's
   accessible name.
3. **`currentColor`, always.** `.icon` never sets a color of its own. It
   inherits the text role it sits in, and with it the contrast that role
   already measured ([css-tokens.md](css-tokens.md)) — which is how a
   meaningful icon clears the 3:1 non-text bar (WCAG 1.4.11) for free. An icon
   that wants its own color is a missing text role, not a special case.
4. **Size in `em`, never `px`.** `1em` ties the icon to its type, so it tracks
   fluid headings ([css-typography.md](css-typography.md)) and the user's
   font-size setting. A bigger icon comes from bigger text on the control, not
   from an icon-size ladder. One control sets its own factor: in a bottom
   navigation target the icon is what the thumb aims at and the word underneath
   only names it, so it takes `font-size: 1.5em` at that one use site
   ([css-layout.md](css-layout.md)) — still `em`, still no ladder.
5. **One mechanism.** No icon font, no sprite file, no `<img>` icon, no inline
   SVG in templates. A mark that cannot be a single-color mask — a logo, an
   empty-state illustration — is an image with `alt`, not an icon.
6. **Keep the set small.** Eight above, ~12 the ceiling — the same discipline
   as the token ceiling in [css-tokens.md](css-tokens.md). An icon enters when
   a control needs it and leaves when that control does.
7. **The set is recorded in `DESIGN.md`.** Icons are a shipped component, so
   they take a bullet in its Components inventory
   ([design-system.md](design-system.md) rule 5) naming the shapes and the
   grid — no values to mirror, because there are no icon tokens.

## Anti-patterns

- ❌ An icon font (Font Awesome, Material Icons) — a whole font file for a
  handful of glyphs, tofu boxes when it fails to load, and private-use
  codepoints that leak into the accessibility tree and the clipboard.
- ❌ A third-party origin or an npm icon package — rule 9 of
  [stack/css.md](../stack/css.md) keeps every icon in this stylesheet, and
  there is no npm in this stack; the paths a project needs are three lines of
  CSS.
- ❌ Base64 data URIs — larger than percent-encoding for text, and unreadable
  in a diff.
- ❌ `<img src="/static/icons/check.svg">` — one request per icon, and an
  `<img>` cannot be tinted by the text color around it.
- ❌ A separate `--color-icon` token or a color on `.icon` — it forks the
  measured contrast away from the text role (rule 3).
- ❌ An icon-size ladder (`.icon-sm`, `.icon-lg`) — `em` already tracks the
  type; the ladder just restates the font size in a second vocabulary.
- ❌ A spinner icon for loading — waiting is the indicator fade in
  [css-motion.md](css-motion.md), not a rotating mask.
- ❌ Two-tone or multi-color icons — a mask carries alpha only; color in the
  SVG is discarded, so the second tone silently disappears.

## Facts verified (2026-08-13)

- CSS masking Baseline **Widely available** 2026-06-07 — Chrome 120, Safari
  15.4, Firefox 53: https://webstatus.dev/features/masks
- `forced-colors` Baseline **Widely available** 2025-03-12, so the media query
  above needs no fallback: https://webstatus.dev/features/forced-colors
- Forced colors mode replaces author colors but uses system color keywords
  such as `CanvasText` as written:
  https://developer.mozilla.org/en-US/docs/Web/CSS/@media/forced-colors
- An image that fails to parse "is rendered as a solid-color transparent
  image", which in a mask means the element disappears:
  https://drafts.csswg.org/css-images-3/#invalid-image
- The eight mask declarations above measure 2,064 bytes, uncompressed.
