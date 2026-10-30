---
name: brand
description: Give the app its face: a logo mark and wordmark drawn as SVG, an app icon, and a shareable brand board that shows the logo, colours, type and voice on real things. Use when someone says "make a logo", "design a logo", "I need an app icon", "what's our brand", "make a brand board", "something I can show people", "how does it look on a website", or when the `design` skill reaches its brand step. No approved look yet (no `docs/design/direction.md`) goes to `design` first.
---

# Brand

The face of the app: a mark, the name written out, an app icon, and one board that shows it all on real things. Built from the approved direction's colours and type, not new ones. Simple on purpose: a mark that still reads as a small app icon beats a detailed illustration.

Runs as step 2 of the `design` skill, after the direction. Run on its own, it reads `docs/design/direction.md`; without it, say so in plain words and run the `design` skill from its first step.

How you talk to the user:
- Show, don't tell. Each round is a page (see Visuals); the chat holds one or two lines and the question.
- Every term gets one plain line ("Wordmark: the app's name written in its own lettering").
- A choice comes as options, the recommended one first, each saying what it means. They can always say what they don't like instead.
- An approval moves on. Never "shall I go on?".

## Read first (silently)

`docs/intent.md` (who it is for, the values), `docs/design/direction.md` (palette, type pair, mood), `docs/design/brand.md` when it exists (a change, not a first draft), and the `writing` skill's voice section.

## Round 1 — The mark

One page, three marks side by side, each a different idea, not three shades of one: for example a letter, a simple symbol from the app's main moment, and an abstract shape. Each shows:
- The mark on light and on dark, and as an app icon at full size and at the size it has on a home screen.
- The wordmark: the name in the direction's heading font, next to the mark.
- One line on the idea behind it.

Draw each as SVG by hand: a few simple shapes, the direction's colours, no tiny detail, no text inside the mark. Mark the one that fits the intent best as recommended, with one line why. Redraw until they pick one; each round changes only what they pointed at.

## Round 2 — The brand board

One shareable page, built from the picked mark:
- **Logo** — mark, wordmark and the two together; on light and dark; the clear space around it and the smallest size it may be used at.
- **Colours** — the direction's palette as swatches with names, hex values and what each is for.
- **Type** — the heading and body fonts, as a sample in the app's own words.
- **Voice** — the voice in one line: three words and one example sentence (the `writing` skill's voice).
- **On real things** — the look applied, each drawn separately: a notepad, a pen, a phone screen, a foldable open and closed, a website hero, and the navigation (a tab bar on the phone, a top bar on the website).
- **Accessibility** — the contrast of each brand colour pair used for text or the mark, with pass or fail per the `accessibility` skill's basic 1. A colour that fails for text is marked "for shapes only".

Ask once if it feels right; redraw only what they pointed at.

## On approval

Write the files and a decision file as the `design` skill describes:
- `docs/design/brand/mark.svg`, `docs/design/brand/wordmark.svg`, `docs/design/brand/app-icon.svg` (1024 by 1024, square, a solid background, the mark inside the middle 80 percent so platform masks don't cut it, no words).
- `docs/design/brand.md` in this shape:

```
# Brand

## Mark
The idea in one line. Files: brand/mark.svg, brand/wordmark.svg, brand/app-icon.svg.
## Use
Clear space, smallest size, on light and on dark, what never to do (stretch, recolour, add effects).
## Colours
| Name | Hex | For |
From the direction; no new colours.
## Type
Heading and body font.
## Voice
Three words. One example sentence.
## Accessibility
| Pair | Contrast | Text or shapes only |
## Board
Where the brand board lives (its link or file path).
```

The board itself goes where `.solidvibes/agents.md` says visuals go (a published page or a local HTML file). Its link or path goes under `## Board`, so it can be shared later.

With Pro: the `ui` pack adds a design craft review (hierarchy, alignment, density, restraint, consistency) of the board and every screen.

## Visuals

"Show a visual" means: make the page with the `eli-solid` skill and show it as `.solidvibes/agents.md` says for the agent in use. If that file is missing, write a local HTML file and tell the user where it is. Pages use the approved direction's look. The SVGs are inlined on the page, so what they approve is what gets saved. Without HTML, save the SVG files and list them with one line each.
