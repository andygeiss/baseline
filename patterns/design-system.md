# Pattern: Design System (DESIGN.md, Themes)

**Last verified: 2026-08-13**

Every web application records its design system in one file: `DESIGN.md` at the
repo root, next to `README.md`. It holds the theme — the token values, measured
contrast, and component inventory that make this project look like itself — in
a format both humans and design tools parse. [stack/css.md](../stack/css.md)
and the CSS patterns own *how* styling works; `DESIGN.md` owns *which values
this project chose*. The two MUST stay lockstep: every CSS value quoted in
`DESIGN.md` is identical, character for character, to the same value in
`web/static/css/app.css`.

## The format

`DESIGN.md` follows the `design.md` specification
(https://github.com/google-labs-code/design.md, `version: alpha`): YAML
frontmatter carries the machine-readable tokens; the markdown body explains the
design in the spec's eight sections, in its order — Overview, Colors,
Typography, Layout, Elevation & Depth, Shapes, Components, Do's and Don'ts.
The spec accepts any CSS color, `oklch()` included, so the frontmatter
carries the tokens layer's values verbatim — no lossy hex conversion.

The file has two consumers beyond human readers:

- **AI coding agents.** An agent styling any page reads `DESIGN.md` first and
  takes every value from it — the same way it takes stack decisions from this
  baseline.
- **Claude Design** (claude.ai/design). The design tool extracts tokens,
  typography, and components from uploaded sources; `DESIGN.md` is that
  source. Push the file (or the repo), and push again when it changes — a
  stale copy generates off-brand designs. Where a sync integration is
  available it MAY be used; the repo's `DESIGN.md` stays the record either
  way.

An alpha-status spec is a sanctioned exception to the "never betas" rule
([README](../README.md) core value 5, [VERSIONS.md](../VERSIONS.md)): it is a
document format, not software — nothing ships it, nothing breaks at runtime.
A tool that does not know the format still reads plain markdown with a YAML
block at the top. Re-check the spec when updating this document's
`Last verified:` date.

The spec's format is a second sanctioned exception — to the Documents rules
in [STYLE.md](../STYLE.md): category headings (`Overview`, `Colors`, …) are
the names design tools parse, and a values record has no runnable example
to open with. Inside this one file the spec's structure wins; STYLE.md
still governs the prose within it.

## The file

The canonical `DESIGN.md`, carrying the default theme from
[css-tokens.md](css-tokens.md). Copy it and set `name`, `description`, and
the `# Design:` title. From then on three things may change: **values**,
which follow the project's own `app.css` and carry their re-measured
contrast floors with them (rules 3–4); **color roles**, added — never
renamed — in both files at once (rule 2); and the **Components**
inventory, which lists what the project ships (rule 5). The eight
sections never change:

````markdown
---
version: alpha
name: Baseline
description: One line saying what the application is.
colors:
  bg: "oklch(99% 0.002 260)"
  surface: "oklch(96% 0.005 260)"
  text: "oklch(22% 0.02 260)"
  text-muted: "oklch(45% 0.02 260)"
  accent: "oklch(45% 0.17 260)"
  error: "oklch(45% 0.17 25)"
  border: "oklch(62% 0.02 260)"
  bg-dark: "oklch(18% 0.01 260)"
  surface-dark: "oklch(24% 0.01 260)"
  text-dark: "oklch(93% 0.01 260)"
  text-muted-dark: "oklch(72% 0.02 260)"
  accent-dark: "oklch(75% 0.12 260)"
  error-dark: "oklch(75% 0.12 25)"
  border-dark: "oklch(56% 0.02 260)"
  primary: "oklch(45% 0.17 260)"
  primary-dark: "oklch(75% 0.12 260)"
typography:
  body:
    fontFamily: "system-ui, sans-serif"
  mono:
    fontFamily: "ui-monospace, monospace"
rounded:
  radius: "0.375rem"
components:
  button:
    backgroundColor: "{colors.accent}"
    textColor: "{colors.bg}"
    rounded: "{rounded.radius}"
---

# Design: Baseline

## Overview

This file is the project's design system: the theme values, contrast
floors, and component inventory every page is styled from. It is written
for whoever styles a page — usually an AI coding agent — and design tools
parse the same file. The theme is calm
and neutral: near-white surfaces, one accent hue for everything
interactive, generous whitespace. The dark scheme follows the OS setting —
there is no toggle. Every CSS value in this file is identical,
character for character, to the same value in `web/static/css/app.css`; the
two files change in the same commit.

## Colors

Every color `app.css` writes comes from the roles above — components never
use a raw color value. `accent` colors everything interactive: links, primary
buttons, focus rings. `primary` restates the `accent` values character for
character: the spec requires a `primary` palette, and tools invent one when
it is missing. `surface` is cards, table stripes, and wells. `error`
appears only on validation failures. Hover and active shades are mixed with
`color-mix()` at the use site — never stored as extra tokens.

Measured contrast (2026-08-12): every text role on both backgrounds ≥ 6.6:1
in both schemes; `border` on both backgrounds ≥ 3.2:1; the primary button
≥ 7.4:1. After any color change, re-measure and update these numbers.

## Typography

The system font stack, no web fonts: `body` for text, `mono` for code. There
is no fixed size scale — sizes are fluid `clamp()` expressions at the use
site, so type tracks the viewport and the user's font-size setting.

## Layout

One fluid spacing value drives all whitespace: `clamp(1rem, 0.5rem + 2vw, 2rem)`,
with quarter, half, and double steps derived from it. Prose lines measure
`65ch`; card and sidebar pages cap at `80rem`. Layout is mobile-first: the
base styles are the 320 px layout, and wider screens only add columns.

## Elevation & Depth

No shadows: this is the minimal surface style. Depth is one step deep:
`surface` panels on the `bg` page ground, separated by `border` lines. A
design needing a taller stack than that gets redesigned flatter.

## Shapes

One radius, `0.375rem`, on every rounded box: buttons, inputs, cards,
dialogs. Pills and circles are not part of this system.

## Components

Every component composes the roles above, and every interactive state
(hover, focus-visible, active, disabled, loading) is styled:

- **Button** — primary actions use the `button` composite above: `accent`
  background, `bg` text. Secondary actions drop the fill: a plain link
  when they navigate, a plain button when they act.
- **Form field** — label above the control, `border` boundary, `error` text
  directly under the control that failed.
- **Flash** — one-line result message at the top of the content area.
- **Card** — `surface` panel with `radius` corners; rows align across
  neighboring cards.
- **Dialog** — modal only: fades in with motion enabled, closes instantly.
- **Loading indicator** — with motion enabled, hidden until a request runs
  past 100 ms.

## Do's and Don'ts

- Do take every color from the roles above. Don't write a literal color
  value outside the stylesheet's tokens layer.
- Do let the OS pick the scheme. Don't add a theme toggle.
- Do use motion as feedback: `150ms` for state changes, `300ms` for
  movement. Don't decorate with motion.
- Do change this file and `app.css` in the same commit. Don't let them
  drift.
````

## Rules

1. **`DESIGN.md` holds the theme; the baseline holds everything else.**
   The theme's values are seventeen — the seven color roles in two schemes
   (fourteen values), two font stacks, one radius — plus any color role the
   project adds, which lands in both files at once (rule 2).
   Spacing, widths, motion durations, the type scale, and layout mechanics
   follow [css-tokens.md](css-tokens.md), [css-layout.md](css-layout.md),
   [css-typography.md](css-typography.md), and
   [css-motion.md](css-motion.md); the body restates their `app.css` values
   only so a design tool sees the whole system — restated here, chosen there.
2. **Token names mirror the tokens layer.** `--color-text-muted` →
   `colors.text-muted`, its dark-scheme value → `colors.text-muted-dark`;
   `--font-body` → `typography.body.fontFamily`; `--radius` →
   `rounded.radius`. Within these vocabularies — colors, fonts, radius —
   the two files carry exactly the same set: a token in one and not the
   other is the invented token vocabulary
   [css-tokens.md](css-tokens.md) exists to stop. The spacing, width,
   and motion tokens stay body prose (rule 1 above). One alias sits outside
   the mirror: the spec requires a `primary` palette, so `primary` and
   `primary-dark` restate the `accent` values character for character —
   spec vocabulary, not a new role, and not part of the seventeen.
3. **Lockstep, same commit.** A commit that changes a token value in `app.css`
   updates `DESIGN.md` too, and the reverse — the discipline `Makefile` and
   `ci.yml` already use ([stack/makefile.md](../stack/makefile.md)). Every CSS
   value quoted anywhere in `DESIGN.md`, frontmatter or body, is under this
   rule. When the files disagree, that is a defect, not a choice to make:
   flag it to the user — `git log` shows which edit missed its partner.
4. **A theme is new values in the same structure.** To theme a project:
   replace the neutral hue `260` with the brand hue everywhere it appears,
   keep every lightness and chroma as is, and leave `error` on hue `25` — red
   means failure regardless of brand. A brand hue near `25` would make
   `accent` and `error` twins; then — and only then — separate `error` by
   lightness so failure keeps its own color. Then re-measure contrast (the duty
   [css-tokens.md](css-tokens.md) states) and record the new floors in the
   Colors section. Fonts must be self-hosted, by the one recipe in
   [css-typography.md](css-typography.md); the radius is any `px`, `em`, or
   `rem` length — the only units the spec's dimension type allows — and an
   unrounded theme writes `0rem` in both files. Body prose follows its
   values: a sentence describing a replaced value — the Typography stack,
   the Shapes radius — is rewritten to describe the new one.
   The surface style composes the same way:
   [css-surfaces.md](css-surfaces.md) defines the three sanctioned styles,
   and the canonical file above *is* the minimal one — its Elevation & Depth
   section names the style, so copying it unchanged records the default. A
   neumorphic or glass project takes that pattern's token deltas as its
   values — new values, added color roles (rule 2), prose rewritten to
   follow them. It names its style in the same section. Like the theme,
   the project chooses the style once.
5. **Components reference tokens, never restate them.** The body bullets are
   the inventory: one per component the project ships, growing and shrinking
   with the app. The `components` map does not grow with them — it carries
   exactly one composite recipe, the primary button. The map uses
   `{colors.accent}`-style references; the body names roles (`accent`
   background, `surface` panel). A literal color in either is the same tell
   as a raw `oklch()` outside the tokens layer: a role is missing, or one
   already exists — use it.

## Anti-patterns

- ❌ Converting `oklch()` values to hex "for the design tool" — the spec
  accepts `oklch()`; a converted value breaks character-identical sync and
  rounds the color.
- ❌ A `data-theme` attribute, theme picker, or per-page theme — one theme per
  project, and the OS setting is the only scheme switch
  ([css-tokens.md](css-tokens.md) rule 4).
- ❌ The design system living in the design tool — Claude Design and Figma are
  consumers; the repo's `DESIGN.md` is the record, versioned with the code it
  styles.
- ❌ `DESIGN.md` as a second CSS architecture document — cascade layers,
  breakpoints, and motion mechanics belong to the baseline patterns; this file
  records values and inventory.
- ❌ Growing the frontmatter into a token catalog (`spacing-2xl`,
  `colors.brand-100` ladders) — the ~20-token ceiling of
  [css-tokens.md](css-tokens.md) applies here too.
