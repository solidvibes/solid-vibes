---
name: design
description: Pick the look of a whole new app, broad to deep, before any of it is built, and end with one picture of how the whole thing works. Use when setup of a new project has just finished, or someone says "design the app", "how should the app look", "what will it look like", "pick colours", "choose the colours and fonts", "a style for the app", or "make a design system". One new screen or a feel change on an app that already has a look goes to `brainstorm` instead.
---

# Design

The look of a new app, in four steps, broad to deep. One page and one approval per step:

1. **Direction** — three looks side by side; pick one or mix.
2. **Design system** — colours, type, spacing, icons and the core parts, built for everyone.
3. **Screens** — the main screens, their states and how you move between them.
4. **System picture** — one moving picture of how the whole thing works.

Then `plan`. The approved design system becomes the app's theme in the first build.

How you talk to the user (this is the only mode):
- Show, don't tell. Every step is a page (see Visuals); the chat holds one or two lines and the question.
- Open with the map above, one short line per step, before the first page.
- A choice comes as options, the recommended one first, each saying what it means and what it costs later. How this agent asks: `.solidvibes/agents.md`. They can always say what they don't like instead.
- Every term on a page gets one plain line: what it is, why it's here ("Contrast: how much the text stands out from the background, so it reads in sunlight").
- Never a tech question. Never "shall I go on?": an approval moves to the next step.

## The contract

Read the project's Factory contract: the `## Factory` section of `AGENTS.md` in the repo root. Spec: `.solidvibes/factory-contract.md`. Missing → say so in plain words and offer the `interview` skill first. Never guess a stack.

## Step 0 — Read first (silently)

- `docs/intent.md`: who it is for, the values, the never list. They shape the look ("calm, for tired parents" is not "loud, for teenagers").
- `docs/stack.md`: the devices and what runs where. The screens and the system picture use only those.
- `docs/decisions/`, `docs/direction/`.
- `docs/design/`: when some of it exists, start at the first step not yet written (Step 4: no `## How it all works` in `screens.md`) and say which. When they ask to change an approved step, redo that step and the ones after it, and record the change as a new decision that names the one it replaces.

An app with no screens (a background service, a command-line tool): skip to Step 4.

## Step 1 — Direction

One page, three directions side by side, each different in feel, not three shades of one idea. Each direction shows:
- **Palette** — five colour swatches, each with a plain name ("Deep teal, for buttons").
- **Type pair** — a heading font and a body font, as a short sample in the app's own words.
- **Mood** — three words.
- **One sample screen** — the app's main moment, drawn in that look.

Mark the one that fits the intent best as recommended, with one line why. Ask: pick one, mix ("A's colours with B's fonts"), or say what you don't like. Redraw until they approve. Each new round changes only what they pointed at.

On approval write `docs/design/direction.md` (palette with hex values, the type pair, the mood words, what they liked and rejected) and a decision file.

## Step 2 — Design system

Build it from the approved direction. One page:
- **Colours** — light and dark, each colour named by its job: background, surface, text, muted text, primary, on primary, accent, on accent, error, on error, success. Swatches for both modes side by side.
- **Type scale** — 5 or 6 sizes, from page title to small print, shown as specimens.
- **Spacing** — one base step (4 or 8) and the scale built on it.
- **Corners** — the radius for small parts, cards and sheets.
- **Icons** — one style (outline or filled), shown on a row of the app's own actions.
- **Illustration** — only when they want it. Ask once, as options (none, simple spot pictures, a mascot); none is recommended for a first version.
- **Core parts** — button, text field, card, list row, navigation bar, empty state, error message. Each in its states: normal, pressed, disabled, error.

Built for everyone, never asked:
- Text stands out from its background at least 4.5 to 1 (3 to 1 for large text), in both modes. Check every pair; adjust the colour, not the rule.
- Body text at least 16 points, and the layout holds when the phone's text size is turned up.
- Every tappable thing is at least 48 by 48 points.
- Colour never carries meaning alone: an error also has an icon or words.

Show the checks on the page as a short list of passes. On approval write `docs/design/system.md` in the shape below and a decision file.

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
The four rules above, with the checked pairs.
```

## Step 3 — Screens

From the intent's main moments, the screens a first version needs, in the approved look. One page:
- **The map** — every screen as a box, arrows for how you move between them. At most five places in the main navigation; back always works.
- **Each screen** — drawn on its own, with its states drawn separately: empty, loading, error, full. Never one mixed frame.
- **Where things sit** — the main action within thumb reach; one line per screen on what it is for.

Ask per screen ("ok", "2: move the button up"). Redraw only what they pointed at. On approval write `docs/design/screens.md` (the map as Mermaid, one section per screen: purpose, states, what sits where) and a decision file.

## Step 4 — System picture

One picture of how the whole thing works, the same for an engineer and for someone who has never built software:
- **Real things only** — the phone, the computer, the server, each outside service (payments, sign-in, email), from `docs/stack.md`. Nothing else.
- **Data moves** — dots travel along the arrows: what goes where, and when ("Your entries sync when there's internet").
- **One plain line per part** — what it is and why it's here, shown on hover or tap.

Ask once if it matches what they imagine. On approval add it to `docs/design/screens.md` under `## How it all works`, as Mermaid with one line per part, so the plan page can reuse it. Write a decision file.

## Decision files

One per approved step: `docs/decisions/<today>-design-<step>.md` (a change adds a short slug: `-design-<step>-<change>.md`) in the shape `docs/decisions/README.md` gives, **Who decided:** mine. Context: what was shown. Decision: what was picked. Why: their words. Alternatives: the options not picked.

## Hand-off

After Step 4 is approved, say one line ("Next I'll plan the first version, built in this look") and continue into the `plan` skill with the intent and `docs/design/` as its input. Don't ask first.

## Visuals

"Show a visual" means: as `.solidvibes/agents.md` says for the agent in use. If that file is missing, write a local HTML file and tell the user where it is. Follow the page rule in `AGENTS.md` (`## Visuals`). Until Step 1 is approved, pages use the Solid Vibes look; from then on, the approved direction. Without HTML, draw palettes as tables with hex values, screens as boxes in Mermaid, and the system picture as Mermaid.
