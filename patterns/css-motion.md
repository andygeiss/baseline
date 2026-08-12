# Pattern: CSS Motion (Transitions, View Transitions, Reduced Motion)

**Last verified: 2026-08-12**

The one rule that makes motion work: **motion is feedback, never decoration.**
Motion has exactly three jobs: confirm a state change (hover, focus, press),
connect old and new content across a swap, and show that the app is working.
An animation doing none of those jobs is noise — delete it. Everything below
fits the single stylesheet [stack/css.md](../stack/css.md) prescribes: two
tokens, one media feature, a handful of rules per layer.

## Two duration tokens

Add both to the `tokens` layer that [css-tokens.md](css-tokens.md) defines:

```css
/* Motion — two speeds, feedback and movement. */
--motion-fast: 150ms; /* state feedback: hover, presses, indicator fades */
--motion-slow: 300ms; /* movement and entry: dialogs, revealed content */
```

- `--motion-fast` is for anything answering a pointer or a request. Feedback
  slower than ~200 ms reads as lag, not polish.
- `--motion-slow` is for anything that moves or appears. No one-shot authored
  motion runs longer — the browser, not the stylesheet, times the
  smooth-scroll glide (below). A loading loop is not one-shot: it repeats
  until the response lands or its ~5 s cap stops it.
  A motion that seems to need more time is decoration (see anti-patterns).
- **Easing on one-shot motion is always the built-in `ease-out`.** Starting
  fast and settling gently reads as responsive. A loop runs `linear`. A
  custom cubic-bezier curve is a brand decision this baseline does not make,
  so there is no easing token.

Every one-shot authored duration is one of these two tokens. A loading
loop's cycle length is the one authored duration outside them. A delay is a
threshold, not a duration — the indicator's 100 ms delay below stays a
literal.

## One media feature: `prefers-reduced-motion`

[stack/css.md](../stack/css.md) rule 5 wraps every `transition` and
`animation` in `@media (prefers-reduced-motion: no-preference)`.
The trap is what does *not* go inside: **state rules stay outside; only the
motion moves inside.** `.htmx-indicator { opacity: 0 }` is visibility, not
motion — wrap its `transition`, never the rule itself. Done this way a
reduced-motion user loses nothing: every state still changes, instantly.

One mechanism flips the polarity. The view-transition kill switch below uses
`(prefers-reduced-motion: reduce)` because the animations it cancels come
from the browser's own stylesheet, not from `app.css` — a stylesheet cannot
wrap what it never declares, only cancel it.

## State feedback: interactive elements (base layer)

Interactive elements ease between their states — the states themselves
(`:hover`, `:focus-visible`, `:active`, `:disabled`) are already mandatory
per [stack/css.md](../stack/css.md) rule 4. Their transition block also carries
the smooth-scroll glide the tokens section deferred:

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

1. **List properties explicitly — `transition: all` is banned.** `all`
   silently animates whatever any later rule touches, including layout
   properties added months from now.
2. **Only two families of properties may animate.** State paints (`color`,
   `background-color`, `border-color`, `box-shadow`, `opacity`) and
   compositor moves (`translate`/`transform`, `opacity`). Layout properties
   (`width`, `height`, `margin`, `inset`, `font-size`) MUST NOT animate: they
   reflow the page every frame. Move with `translate`, reveal with `opacity`.
3. **`outline` never transitions.** Focus is always visible
   ([stack/html.md](../stack/html.md)), and the ring MUST appear the instant
   focus lands — a keyboard user is not an audience to ease in for. Draw the
   ring with `outline`, not `box-shadow` — a `box-shadow` ring would inherit
   the 150 ms ease from the snippet above. (The dialog entry fade below
   briefly carries the ring in with the dialog; the ring itself still never
   eases.)

## Waiting: the indicator fade (components layer)

`app.css` owns the indicator CSS because the canonical layout disables htmx's
inline version for CSP ([stack/htmx.md](../stack/htmx.md)):

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

The asymmetric delay is the point. A class change reads its transition from
the element's *new* state, so entering `.htmx-request` picks up the 100 ms
delay. With motion enabled, responses faster than 100 ms never flash an
indicator — the >100ms indicator rule from
[stack/htmx.md](../stack/htmx.md), expressed in CSS.
Leaving the state reads the rule without the delay, so the fade-out starts
the moment the response lands. Under reduced motion there is no transition and no
delay — the indicator flips instantly both ways, which is the preference
honored, not a bug.

The indicator is for the eye, not the screen reader. `opacity: 0` hides
nothing from the accessibility tree, so the indicator markup carries
`aria-hidden="true"`. The `aria-live` regions from
[stack/html.md](../stack/html.md) announce the updates that matter
(WCAG 4.1.3).

## Swaps: view transitions

The canonical layout's `htmx-config` meta
([stack/html.md](../stack/html.md)) sets `"globalViewTransitions":true` —
htmx wraps every swap in the same-document View Transition API, so boosted
navigations and fragment swaps cross-fade instead of blinking. Baseline
Newly, inherently graceful ([stack/css.md](../stack/css.md) table):
unsupported browsers swap instantly, and no markup changes either way.

1. **Rapid-fire swaps MUST opt out** with `hx-swap="outerHTML
   transition:false"`: active search (`hx-trigger="input changed
   delay:300ms"`), polling (`every 30s`), and any control users hit in
   quick succession (pagination, steppers). A cross-fade per keystroke is
   noise, and the costs are real. The API briefly holds rendering while it
   snapshots the page. During the fade, pointer input lands on nothing —
   captured content is exempt from hit-testing.
2. **The view-transition kill switch lives in `utilities`** — the one layer
   where `!important` is allowed ([stack/css.md](../stack/css.md) rule 3).
   The fade animations come from the browser's stylesheet — the polarity
   flip above — and the API does not read the media query itself. With the
   animations cancelled, a "transition" completes on the spot:

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

3. **Element morphs are a MAY, used sparingly.** `view-transition-name:
   score` on a stable element makes it glide to its new place instead of
   cross-fading. Each name MUST be unique on the page — a duplicate makes the
   browser skip the whole transition. The default cross-fade is the right
   answer almost everywhere.

## Entry: dialogs (base layer)

Element defaults belong in `base` ([stack/css.md](../stack/css.md)), and this
rule styles the bare `dialog` element:

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

`@starting-style` supplies the "before" styles for the element's first
rendered frame — the fade runs when `showModal()` flips the dialog from
`display: none`, which a plain transition cannot animate from. Baseline
Newly, inherently graceful ([stack/css.md](../stack/css.md) table): a browser
that does not know the at-rule ignores it and shows the dialog fully formed.

- **The selector is `dialog:modal` (Baseline Widely), not `dialog[open]`.**
  In this stack, a dialog matches `:modal` only through the show-modal
  steps: `showModal()`, which the `command="show-modal"` invoker button
  from [stack/html.md](../stack/html.md) runs. (The spec's other matcher —
  the fullscreen flag — needs JavaScript.) The entry animation therefore
  plays only when the user opens the dialog. `[open]` also matches a
  server-rendered `<dialog open>` at first paint and one swapped in by htmx
  with `open` already set — entrance animations nobody asked for (see
  anti-patterns). An open dialog is never itself a swap target anyway.
  Replacing the element drops it out of the top layer — backdrop, focus
  containment, `Esc` all gone. Re-render the contents, not the dialog.
- **Exit is instant, by design.** An exit fade needs the `overlay` property
  (not Baseline — see below) to hold the dialog in the top layer while it
  fades. Entry animated, exit instant is correct: showing guides the eye;
  dismissing should just obey.
- **Leave `::backdrop` alone.** Older browsers do not let `::backdrop`
  inherit custom properties from the dialog, so a token-based backdrop fade
  silently breaks — and an instant backdrop behind a fading dialog looks
  fine.

## Not in the allowed set yet

These solve real problems, but none has reached Baseline — Newly or Widely —
as of this document's verification date. Each still misses at least one
engine. That lands them in the feature rule's "otherwise" tier
([stack/css.md](../stack/css.md)): MUST NOT, graceful fallback or not.
Re-check https://web.dev/baseline at the next verification:

- `animation-timeline: scroll()` / `view()` — scroll-driven animations.
- `interpolate-size` / `calc-size()` — animating `height: auto` (an opening
  `<details>`). Baseline status alone would not admit it: it animates a
  layout property, which transition rule 2 above forbids.
- `overlay` — the dialog exit fade above. Baseline status alone would not
  admit it either: exit is instant by design.

## Anti-patterns

- ❌ `transition: all` — animates whatever any later rule touches; list
  properties explicitly.
- ❌ Animating layout properties (`width`, `height`, `margin`, `inset`,
  `font-size`) — reflow every frame; move with `translate`, reveal with
  `opacity`.
- ❌ Transitioning `outline` — the focus ring appears the instant focus
  lands, always.
- ❌ Entrance animations on page load (hero fades, staggered reveals) — page
  load is not a state change the user caused.
- ❌ Infinite animations outside a loading indicator — a pulsing badge is
  decoration with a heartbeat. Even the loading loop caps its cycles
  (`animation-iteration-count`) to go static by ~5 s: motion running longer
  must be stoppable (WCAG 2.2.2), and a frozen indicator still shows the
  wait.
- ❌ Scroll hijacking and parallax — the scrollbar belongs to the user.
- ❌ htmx class-based swap animation (`.htmx-added` fades, `swap:`/`settle:`
  delays in `hx-swap`) — that machinery predates view transitions; a
  `settle:` delay slows the swap to buy what `"globalViewTransitions":true`
  gives free.
- ❌ One-shot durations past `--motion-slow` — 300 ms is the ceiling, not a
  suggestion.
