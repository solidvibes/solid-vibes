---
name: design-system
description: Turn an approved look into a simple design system the app is built from: colours by job in light and dark, a type scale, spacing, corners, icons and the core parts in their states, with accessibility built in. Use when someone says "make a design system", "set up the colours and fonts", "add dark mode", "the type sizes are all over the place", "make the buttons consistent", or when the `design` skill reaches its design system step. No approved look yet (no `docs/design/direction.md`) goes to `design` first.
---

# Design system

The approved look, turned into the few values and parts every screen is built from. Simple on purpose: enough to make every screen consistent, nothing a first version won't use. It becomes the app's theme in the first build.

Runs as step 3 of the `design` skill, after the brand. Run on its own, it reads `docs/design/direction.md` (and `brand.md` when there is one); without `direction.md`, say so in plain words and run the `design` skill from its first step.

How you talk to the user:
- One page (see Visuals); the chat holds one or two lines and the question.
- Every term gets one plain line ("Surface: the colour of cards and sheets, a step off the background").
- Accessibility is built in, never asked. Say in one line when it changed something they picked.
- An approval moves on. Never "shall I go on?".

## Read first (silently)

`docs/design/direction.md`, `docs/design/brand.md`, `docs/design/system.md` (a change, not a first draft), `docs/stack.md` for the devices, and the `accessibility` skill's basics.

## The page

Build it from the approved direction and brand colours:
- **Colours** — light and dark, each colour named by its job: background, surface, text, muted text, primary, on primary, accent, on accent, error, on error, success. Swatches for both modes side by side.
- **Type scale** — 5 or 6 sizes, from page title to small print, shown as specimens in the app's own words.
- **Spacing** — one base step (4 or 8) and the scale built on it.
- **Corners** — the radius for small parts, cards and sheets.
- **Icons** — one style (outline or filled), shown on a row of the app's own actions.
- **Illustration** — only when they want it. Ask once, as options (none, simple spot pictures, a mascot); none is recommended for a first version.
- **Core parts** — button, text field, card, list row, navigation bar, empty state, error message. Each in its states: normal, pressed, focused, disabled, error.
- **Checks** — the `accessibility` skill's basics 1, 2, 6 and 7 against every colour pair and part, in both modes, shown as a short list of passes. A failing pair changes the colour, not the rule.

They answer per item ("ok", "colours: warmer primary"). Redraw only what they pointed at.

## On approval

Write `docs/design/system.md` in exactly this shape (a stack pack turns it into the app's theme), and a decision file as the `design` skill describes.

```
# Design system

## Colours
| Job | Light | Dark |
One row per job from the list above, in that order; values as #RRGGBB.
## Type
| Role | Font | Size | Weight | Line height |
Roles: display, title, heading, body, label, small. Size in points, weight 100–900, line height as a multiple (1.4).
## Spacing
Base: <n>. Scale: <list of points>.
## Corners
| Part | Radius |
Parts: small, card, sheet. Radius in points.
## Icons
<style, set>
## Illustration
<none, or the style>
## Components
One line each: what it is, its states.
## Accessibility
The basics checked, with each colour pair and its contrast ratio.
```

With Pro: the `ui` pack adds layout and navigation rules for phone, tablet, foldable and desktop, and a design craft review of hierarchy, alignment, density and consistency.

## Visuals

"Show a visual" means: as `.solidvibes/agents.md` says for the agent in use. If that file is missing, write a local HTML file and tell the user where it is. The page uses the approved direction. Without HTML, draw the colours as a table with hex values and the parts as boxes in Mermaid.
