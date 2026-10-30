# Design

**Status:** Built. A real design run in Claude Code is owner-checked, not tested here.

> The look of a new app, picked broad to deep before anything is built.

## Intent

Builders want something to see early, and one picture of how the whole thing works. Going deep at once (every screen in detail) gets feedback on the wrong things; going broad first (colours, type, mood) settles the feel in one round.

## How it works

| Step | The page shows | Approval writes |
|---|---|---|
| 1 Direction | Three looks side by side: palette, type pair, mood words, one sample screen | `docs/design/direction.md` |
| 2 Brand | Three marks, then a brand board: logo, colours, type, voice, the look on real things, contrast of the brand colours (`brand` skill) | `docs/design/brand.md`, `docs/design/brand/*.svg` |
| 3 Design system | Colours light and dark, type scale, spacing, corners, icons, illustration only if wanted, core parts in their states (`design-system` skill) | `docs/design/system.md` |
| 4 Screens | The navigation map, each screen with its empty, loading, error and full states | `docs/design/screens.md` |
| 5 System picture | Real things (phone, computer, server, outside services) with data moving between them, one line per part | `## How it all works` in `docs/design/screens.md` |

- One approval per step; each approval also writes one decision file (`docs/decisions/<date>-design-<step>.md`, mine).
- Accessibility is built in, never asked: the `accessibility` skill's basics, checked for every colour pair and part in both modes. See [craft-skills.md](craft-skills.md).
- `system.md` has a fixed shape (tables per section), so a stack pack can turn it into the app's theme.
- Started by setup on a first setup of a new project (no app code, no `docs/design/`), or by the routing for the look of a whole new app. One new screen or a feel change on an existing app goes to `brainstorm`.
- Resumes at the first step with no approved file. Changing an approved step redoes it and the steps after it, with a decision that names the one it replaces.
- An app with no screens gets only the system picture.
- Ends by going straight into `plan`. The plan page reuses the system picture and the look.

## Do / Don't

- Do draw every screen and state separately.
- Don't ask a tech question, or "shall I go on?" after an approval.
