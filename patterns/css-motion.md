# Pattern: CSS Motion (Transitions, View Transitions, Reduced Motion)

**Tier 2** (shape — waived only on the record) · Last verified: 2026-08-12

The one rule that makes motion work: **motion is feedback, never decoration.** It has
exactly three jobs — confirm a state change, connect old and new content across a swap,
and show that the app is working. An animation doing none of those is noise; delete it.
Everything below fits the single stylesheet [stack/css.md](../stack/css.md) prescribes.

## Two duration tokens

Add both to the `tokens` layer that [css-tokens.md](css-tokens.md) defines:

```css
/* Motion — two speeds, feedback and movement. */
--motion-fast: 150ms; /* state feedback: hover, presses, indicator fades */
--motion-slow: 300ms; /* movement and entry: dialogs, revealed content */
```

- `--motion-fast` answers a pointer or a request. Feedback slower than ~200 ms reads as
  lag, not polish.
- `--motion-slow` is for anything that moves or appears. No one-shot authored motion runs
  longer; a motion that seems to need more time is decoration. (The browser, not the
  stylesheet, times the smooth-scroll glide below. A loading loop is not one-shot — it
  repeats until the response lands or its ~5 s cap stops it.)
- **Easing on one-shot motion is always the built-in `ease-out`** — fast start, gentle
  settle, which reads as responsive. A loop runs `linear`. A custom cubic-bezier is a
  brand decision this baseline does not make, so there is no easing token.

Every one-shot authored duration is one of these two tokens; a loading loop's cycle length
is the one authored duration outside them. A delay is a threshold, not a duration — the
indicator's 100 ms delay below stays a literal.

## One media feature: `prefers-reduced-motion`

[stack/css.md](../stack/css.md) rule 5 wraps every `transition` and `animation` in
`@media (prefers-reduced-motion: no-preference)`. The trap is what does *not* go inside:
**state rules stay outside; only the motion moves inside.** `.htmx-indicator { opacity: 0 }`
is visibility, not motion — wrap its `transition`, never the rule itself. Done this way a
reduced-motion user loses nothing: every state still changes, instantly.

One mechanism flips the polarity. The view-transition kill switch below uses
`(prefers-reduced-motion: reduce)` because the animations it cancels come from the
browser's own stylesheet — a stylesheet cannot wrap what it never declared, only cancel it.

## State feedback: interactive elements (base layer)

Interactive elements ease between their states; the states themselves are already
mandatory per [stack/css.md](../stack/css.md) rule 4. Their transition block also carries
the smooth-scroll glide:

```css
@layer base {
  @media (prefers-reduced-motion: no-preference) {
    html { scroll-behavior: smooth } /* same-page anchor jumps glide */

    a, button, summary,
    input, select, textarea {
      transition: color var(--motion-fast) ease-out,
                  background-color var(--motion-fast) ease-out,
                  border-color var(--motion-fast) ease-out,
                  box-shadow var(--motion-fast) ease-out;
    }
  }
}
```

Three rules govern every transition in the app:

1. **List properties explicitly — `transition: all` is banned.** `all` silently animates
   whatever any later rule touches, including layout properties added months from now.
2. **Only two families may animate.** State paints (`color`, `background-color`,
   `border-color`, `box-shadow`, `opacity`) and compositor moves (`translate`/`transform`,
   `opacity`). Layout properties (`width`, `height`, `margin`, `inset`, `font-size`) MUST
   NOT animate — they reflow the page every frame. Move with `translate`, reveal with
   `opacity`.
3. **`outline` never transitions.** The ring MUST appear the instant focus lands — a
   keyboard user is not an audience to ease in for. Draw it with `outline`, not
   `box-shadow`, which would inherit the 150 ms ease above.

## Waiting: the indicator fade (components layer)

`app.css` owns the indicator CSS because the canonical layout disables htmx's inline
version for CSP ([stack/htmx.md](../stack/htmx.md)):

```css
@layer components {
  .htmx-indicator { opacity: 0 } /* visibility, not motion — stays outside the wrapper */

  .htmx-request .htmx-indicator,
  .htmx-request.htmx-indicator { opacity: 1 }

  @media (prefers-reduced-motion: no-preference) {
    .htmx-indicator { transition: opacity var(--motion-fast) ease-out }

    .htmx-request .htmx-indicator,
    .htmx-request.htmx-indicator { transition-delay: 100ms }
  }
}
```

**The asymmetric delay is the point.** A class change reads its transition from the
element's *new* state, so entering `.htmx-request` picks up the 100 ms delay and responses
faster than that never flash an indicator — the >100 ms indicator rule from
[stack/htmx.md](../stack/htmx.md), expressed in CSS. Leaving the state reads the rule
without the delay, so the fade-out starts the moment the response lands. Under reduced
motion the indicator flips instantly both ways, which is the preference honored.

The indicator is for the eye, not the screen reader: `opacity: 0` hides nothing from the
accessibility tree, so the markup carries `aria-hidden="true"` and the `aria-live` regions
from [stack/html.md](../stack/html.md) announce what matters (WCAG 4.1.3).

## Swaps: view transitions

The canonical layout's `htmx-config` meta ([stack/html.md](../stack/html.md)) sets
`"globalViewTransitions":true`, so htmx wraps every swap in the same-document View
Transition API and boosted navigations cross-fade instead of blinking. Baseline Newly,
inherently graceful: unsupported browsers swap instantly, and no markup changes either way.

1. **Rapid-fire swaps MUST opt out** with `hx-swap="outerHTML transition:false"`: active
   search, polling, and any control users hit in quick succession. A cross-fade per
   keystroke is noise, and the costs are real — the API briefly holds rendering while it
   snapshots the page, and during the fade pointer input lands on nothing, because
   captured content is exempt from hit-testing.
2. **The kill switch lives in `utilities`** — the one layer where `!important` is allowed
   ([stack/css.md](../stack/css.md) rule 3). The fade animations come from the browser's
   stylesheet and the API does not read the media query itself; with them cancelled, a
   "transition" completes on the spot:

   ```css
   @layer utilities {
     @media (prefers-reduced-motion: reduce) {
       ::view-transition-group(*),
       ::view-transition-old(*),
       ::view-transition-new(*) {
         animation: none !important;
       }
     }
   }
   ```

3. **Element morphs are a MAY, used sparingly.** `view-transition-name: score` on a stable
   element makes it glide to its new place instead of cross-fading. Each name MUST be
   unique on the page — a duplicate makes the browser skip the whole transition.

## Entry: dialogs (base layer)

Element defaults belong in `base`, and this rule styles the bare `dialog` element:

```css
@layer base {
  @media (prefers-reduced-motion: no-preference) {
    dialog:modal {
      transition: opacity var(--motion-slow) ease-out,
                  translate var(--motion-slow) ease-out;
    }

    @starting-style {
      dialog:modal {
        opacity: 0;
        translate: 0 0.75rem;
      }
    }
  }
}
```

`@starting-style` supplies the "before" styles for the element's first rendered frame — the
fade runs when `showModal()` flips the dialog from `display: none`, which a plain
transition cannot animate from. Baseline Newly, inherently graceful: a browser that does
not know the at-rule shows the dialog fully formed.

- **The selector is `dialog:modal` (Baseline Widely), not `dialog[open]`.** In this stack a
  dialog matches `:modal` only through `showModal()`, which the `command="show-modal"`
  invoker button from [stack/html.md](../stack/html.md) runs, so the entry animation plays
  only when the user opens it. `[open]` also matches a server-rendered `<dialog open>` at
  first paint and one swapped in by htmx with `open` already set — entrance animations
  nobody asked for. An open dialog is never a swap target anyway: replacing the element
  drops it out of the top layer, taking backdrop, focus containment, and `Esc` with it.
  Re-render the contents, not the dialog.
- **Exit is instant, by design.** An exit fade needs the `overlay` property (not Baseline)
  to hold the dialog in the top layer while it fades. Entry animated, exit instant is
  correct: showing guides the eye; dismissing should just obey.
- **Leave `::backdrop` alone.** Older browsers do not let it inherit custom properties from
  the dialog, so a token-based backdrop fade silently breaks — and an instant backdrop
  behind a fading dialog looks fine.

## Not in the allowed set yet

These solve real problems but none has reached Baseline as of this document's verification
date, which lands them in the feature rule's "otherwise" tier
([stack/css.md](../stack/css.md)): MUST NOT, graceful fallback or not. Re-check
https://web.dev/baseline at the next verification.

- `animation-timeline: scroll()` / `view()` — scroll-driven animations.
- `interpolate-size` / `calc-size()` — animating `height: auto`. Baseline status alone
  would not admit it: it animates a layout property, which transition rule 2 forbids.
- `overlay` — the dialog exit fade. Baseline status alone would not admit it either: exit
  is instant by design.

## Anti-patterns

- ❌ `transition: all` — animates whatever any later rule touches.
- ❌ Animating layout properties — reflow every frame; move with `translate`, reveal with
  `opacity`.
- ❌ Transitioning `outline` — the focus ring appears the instant focus lands, always.
- ❌ Entrance animations on page load (hero fades, staggered reveals) — page load is not a
  state change the user caused.
- ❌ Infinite animations outside a loading indicator — a pulsing badge is decoration with a
  heartbeat. Even the loading loop caps its cycles to go static by ~5 s: motion running
  longer must be stoppable (WCAG 2.2.2), and a frozen indicator still shows the wait.
- ❌ Scroll hijacking and parallax — the scrollbar belongs to the user.
- ❌ htmx class-based swap animation (`.htmx-added` fades, `swap:`/`settle:` delays) — that
  machinery predates view transitions, and a `settle:` delay slows the swap to buy what
  `"globalViewTransitions":true` gives free.
- ❌ One-shot durations past `--motion-slow` — 300 ms is the ceiling, not a suggestion.
