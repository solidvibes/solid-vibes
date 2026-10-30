---
name: accessibility
description: Make sure everyone can use what gets built, on any platform: contrast, text that grows, labels for screen readers, focus, motion, touch size, colour never alone, plain errors. Use when someone says "is it accessible", "can blind people use it", "my dad can't read it", "the text is too small", "does it work with a screen reader", "is the contrast ok", "make it work for everyone", or when a design system, a screen or anything people see and tap is being made or changed.
---

# Accessibility

The basics that let everyone use what gets built: people who see poorly, who use a screen reader, who can't use a mouse, who turn the text size up, who get dizzy from motion. They hold on every platform (phone, computer, web) and every stack. They are built in, never asked: nobody chooses to leave someone out.

Used by `design-system` (the look is built to them), by `brief`, `plan` and `go` whenever a change touches what people see or tap, and by `review` through its accessibility lens.

How you talk to the user:
- Never ask whether to follow a basic. Follow it and say so in one line when it changed something they picked ("I darkened the green a little so the text on it reads in sunlight").
- Explain a term the first time in one plain line ("Screen reader: the phone reads the screen out loud for people who can't see it").
- Show a fix as a before and after, side by side (see Visuals).

## The basics

Each one is a check with a pass or a fail. When one fails, change the design, never the rule.

1. **Contrast.** Text stands out from its background at least 4.5 to 1; large text (about 24 points, or 19 bold) and icons that carry meaning at least 3 to 1. Check every text and background pair in light and dark mode.
2. **Text that grows.** Body text at least 16 points. With the system text size turned up to double, nothing is cut off, overlaps or needs sideways scrolling; rows and buttons grow with it.
3. **Labels for screen readers.** Every button, icon, image and field has a name a screen reader says: what it does, not what it looks like ("Delete entry", not "trash icon"). Decorative pictures are hidden from it. Headings are marked as headings.
4. **Focus and keyboard.** Everything that can be tapped can be reached and used with a keyboard (and a switch or TV remote where the platform has one), in reading order, with a visible focus ring. Nothing traps the focus.
5. **Motion.** No flashing more than three times a second. Animation that moves across the screen is reduced or replaced by a fade when the system asks for less motion. Nothing important happens only through motion.
6. **Touch size.** Every tappable thing at least 48 by 48 points (44 on Apple platforms), with space between neighbours, including small icons and links in text.
7. **Colour never alone.** An error, a state or a chart series also has an icon, a word or a pattern. Links in text are underlined or otherwise marked.
8. **Plain errors.** An error says what happened and what to do next, next to where it happened, in words (see the `writing` skill). It keeps what the person typed. It is read out by a screen reader when it appears.

Also: every field has a visible label (a placeholder is not a label), the screen title says where you are, time limits can be extended, and nothing needs a gesture without a single-tap alternative.

## While building

- **A design system**: check basics 1, 2, 6 and 7 for every colour pair and part, and list the checked pairs in `docs/design/system.md` under `## Accessibility`.
- **A screen or a change people see**: check all eight on what changed. Name, in the commit or PR body, any basic that was hard to meet and how it was met.
- **Can't meet one** (an outside service's widget, a brand colour the owner insists on): say so in plain words, offer the closest fix, and record it in the plan's `## Decisions` or a decision file.

## Checking it

Cheapest first: read the code and the design values for each basic; compute contrast from the hex values; then, when the contract's `run` can launch the app, turn up the text size, turn on the screen reader or the keyboard, and look. Report each basic as pass, fail or not checked, with why.

With Pro: the `ui` pack adds an accessibility checklist run over every changed screen and state, and the `flutter` pack wires the basics into the app's code.

## Visuals

"Show a visual" means: make the page with the `eli-solid` skill and show it as `.solidvibes/agents.md` says for the agent in use. If that file is missing, write a local HTML file and tell the user where it is. A failed basic is shown as the screen before and after the fix, side by side, with the contrast numbers or the sizes written under each.
