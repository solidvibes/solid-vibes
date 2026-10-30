---
name: design
description: Pick the look of a whole new app, broad to deep, before any of it is built, and end with one picture of how the whole thing works. Use when setup of a new project has just finished, or someone says "design the app", "how should the app look", "what will it look like", "pick colours", "choose the colours and fonts", or "a style for the app". One new screen or a feel change on an app that already has a look goes to `brainstorm` instead.
---

# Design

The look of a new app, in five steps, broad to deep. One page and one approval per step:

1. **Direction** — three looks side by side; pick one or mix.
2. **Brand** — the logo, the app icon and a brand board (the `brand` skill).
3. **Design system** — colours, type, spacing, icons and the core parts, built for everyone (the `design-system` skill).
4. **Screens** — the main screens, their states and how you move between them.
5. **System picture** — one moving picture of how the whole thing works.

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
- `docs/design/`: when some of it exists, start at the first step not yet written (Step 5: no `## How it all works` in `screens.md`) and say which. When they ask to change an approved step, redo that step and the ones after it, and record the change as a new decision that names the one it replaces.

An app with no screens (a background service, a command-line tool): skip to Step 5.

## Step 1 — Direction

One page, three directions side by side, each different in feel, not three shades of one idea. Each direction shows:
- **Palette** — five colour swatches, each with a plain name ("Deep teal, for buttons").
- **Type pair** — a heading font and a body font, as a short sample in the app's own words.
- **Mood** — three words.
- **One sample screen** — the app's main moment, drawn in that look.

Mark the one that fits the intent best as recommended, with one line why. Ask: pick one, mix ("A's colours with B's fonts"), or say what you don't like. Redraw until they approve. Each new round changes only what they pointed at.

On approval write `docs/design/direction.md` (palette with hex values, the type pair, the mood words, what they liked and rejected) and a decision file.

## Step 2 — Brand

Follow the `brand` skill: three marks, then the brand board. It writes `docs/design/brand.md` and the logo files.

## Step 3 — Design system

Follow the `design-system` skill. It builds on the direction and the brand, with the `accessibility` skill's basics built in, and writes `docs/design/system.md`.

## Step 4 — Screens

From the intent's main moments, the screens a first version needs, in the approved look. One page:
- **The map** — every screen as a box, arrows for how you move between them. At most five places in the main navigation; back always works.
- **Each screen** — drawn on its own, with its states drawn separately: empty, loading, error, full. Never one mixed frame. The words follow the `writing` skill; each screen meets the `accessibility` skill's basics.
- **Where things sit** — the main action within thumb reach; one line per screen on what it is for.

Ask per screen ("ok", "2: move the button up"). Redraw only what they pointed at. On approval write `docs/design/screens.md` (the map as Mermaid, one section per screen: purpose, states, what sits where) and a decision file.

## Step 5 — System picture

One picture of how the whole thing works, the same for an engineer and for someone who has never built software:
- **Real things only** — the phone, the computer, the server, each outside service (payments, sign-in, email), from `docs/stack.md`. Nothing else.
- **Data moves** — dots travel along the arrows: what goes where, and when ("Your entries sync when there's internet").
- **One plain line per part** — what it is and why it's here, shown on hover or tap.

Ask once if it matches what they imagine. On approval add it to `docs/design/screens.md` under `## How it all works`, as Mermaid with one line per part, so the plan page can reuse it. Write a decision file.

## Decision files

One per approved step: `docs/decisions/<today>-design-<step>.md` (a change adds a short slug: `-design-<step>-<change>.md`) in the shape `docs/decisions/README.md` gives, **Who decided:** mine. Context: what was shown. Decision: what was picked. Why: their words. Alternatives: the options not picked.

## Hand-off

After Step 5 is approved, say one line ("Next I'll plan the first version, built in this look") and continue into the `plan` skill with the intent and `docs/design/` as its input. Don't ask first.

## Visuals

"Show a visual" means: as `.solidvibes/agents.md` says for the agent in use. If that file is missing, write a local HTML file and tell the user where it is. Follow the page rule in `AGENTS.md` (`## Visuals`). Until Step 1 is approved, pages use the Solid Vibes look; from then on, the approved direction. Without HTML, draw palettes as tables with hex values, screens as boxes in Mermaid, and the system picture as Mermaid.
