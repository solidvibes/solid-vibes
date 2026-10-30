# Craft skills

**Status:** Built. Real runs in Claude Code are owner-checked, not tested here.

> How to do one discipline well, on any stack: the basics everyone should get right.

## Intent

Workflow skills say when to do what. Craft skills say how to do one thing well, so a first version gets the basics right without a stack pack. Pro packs go deeper per stack.

## How it works

| Skill | What it covers | Writes | Used by |
|---|---|---|---|
| `brand` | Logo mark and wordmark as SVG, app icon, brand board on real things, contrast of the brand colours | `docs/design/brand.md`, `docs/design/brand/*.svg`, the board as a visual | `design` step 2 |
| `design-system` | Colours by job light and dark, type scale, spacing, corners, icons, core parts and states | `docs/design/system.md` (fixed shape) | `design` step 3 |
| `accessibility` | Eight basics: contrast, text that grows, screen reader labels, focus, motion, touch size, colour not alone, plain errors | the checked pairs in `system.md` | `design-system`, `plan`, `brief`, `go`, review's accessibility lens |
| `security-basics` | Who could be hurt, then eight basics: secrets, what leaves the device, logs, sign-in, access checks, payments, input, leaving | lines in the plan's Constraints or the brief's Risk | `plan`, `brief`, `go`, review's security lens |
| `writing` | The voice, eight basics: plain words, true claims, buttons, errors, confirmations, empty screens, no AI tics, consistency; docs | the voice line in `brand.md` | `brand`, `plan`, `brief`, `go` |
| `eli-solid` | One method for every page that explains or decides something: big pictures, few words, real names, in the app's own look | the page, as a visual | every skill's Visuals step |

- **Building vs checking.** A craft skill guides the build. The review lens checks afterwards: the security and accessibility lenses read the skill's `## The basics` as their floor, so each list is written once.
- **When they load.** `plan`, `brief` and `go` load `accessibility` and `writing` when a change touches what people see or read, and `security-basics` when it touches sign-in, payments, personal data or secrets. Their descriptions also catch direct requests ("make a logo", "is the contrast ok").
- **The brand board** is shown where `.solidvibes/agents.md` says visuals go (a published page or a local HTML file); its link or path is kept under `## Board` in `brand.md`.
- **Pro.** Each skill ends with one "With Pro" line naming the pack that goes deeper. The design craft review (hierarchy, alignment, density, restraint, consistency) is Pro only.

## Do / Don't

- Do change the design when a basic fails, never the rule.
- Don't ask whether to follow a basic; follow it and say what it changed.
