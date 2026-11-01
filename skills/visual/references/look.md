# The look of a page

How to set `templates/style.html` for the project in front of you. The method is fixed; the look comes from the project.

## Where the look comes from

First match wins. Name the source in the page's layout comment.

1. A `## Look` section in the project's `AGENTS.md` (outside every `solidvibes:begin/end` block) or in `CLAUDE.md`, or the user's own words. One line, such as "accent #0055AA, headings in Georgia". The generated `## Visuals` block is never a look source: `init` overwrites it.
2. `docs/design/system.md`.
3. `docs/design/direction.md` (palette by job, type pairing), where `system.md` is silent.
4. The app's theme token files (colour, type, radius).
5. The template's defaults: the Solid Vibes look, Notebook in fern green.

## Roles

The template colours everything through roles. Set the roles, never a colour in a class.

| Role | Used by |
|---|---|
| `--paper` | page background, `.fig`, `.card` |
| `--card` | `.sheet`, chips, `.tbl`, boxes |
| `--cell` | table heads, `.bxOff` |
| `--line` | borders, `.grid` |
| `--line-strong` | box, dashed and lifeline strokes (3:1) |
| `--ink`, `--ink-soft` | text; muted text |
| `--link` | links, nav hover, focus ring |
| `--link-ink` | eyebrow, numbers, link text, "Raise in" lines |
| `--hot`, `--hot-ink`, `--hot-tint`, `--on-hot` | not done and on the critical path, or the recommended pick; nothing else |
| `--ok`, `--ok-tint` | done |
| `--warn-tint` | warning pills |
| `--off` | rejected or old zones |
| `--tint-a`, `--tint-b`, `--tint-c` | zones and bars |
| `--band`, `--on-band`, `--on-band-soft`, `--link-band` | the footer |
| `--display`, `--sans`, `--mono` | type |
| `--r-tile`, `--r-card`, `--r-sheet` | corners |

## Mapping from `system.md`

By the job names the `design-system` skill writes. Theme files use matching names.

- background to `--paper`; surface to `--card`; text to `--ink`; muted text to `--ink-soft`; rule line to `--line`.
- primary to `--link`; on primary to nothing (chrome text sits on `--card`).
- success to `--ok`; accent (a wash) to `--ok-tint` when it is the success or primary wash, otherwise `--tint-a`.
- error to nothing. Red stays for real errors.
- display, title and heading font to `--display`; body and label font to `--sans`.
- small, card and sheet corners to `--r-tile`, `--r-card`, `--r-sheet`.

Map straight to the app's values. Never lighten a token in place of an existing role.

## `--hot`

Use the app's warning or attention token if it has one. If none exists, or the mapped `--hot` equals `--ok` or `--link`, derive a warm attention colour (an ochre or amber) that passes the pairs below. Set `--on-hot` and `--hot-tint` with it.

`--hot` means "not done, on the critical path" or "the recommended pick". Chrome never uses it.

## Roles the app lacks

Cell, off, line-strong, warn and zone tints, the band. Keep the template's values when they pass the pairs below against the app's paper and card. Otherwise derive low-chroma ones. Mark each derived value with a comment.

## The `-ink` roles

- `--link-ink` is `--link` when it passes 4.5:1 on card, paper and cell, else `--ink`.
- `--hot-ink` is `--hot` when it passes 4.5:1 on card, paper and `--hot-tint`, else `--ink`. Never fall `--hot-ink` back to chrome.

## Recheck after mapping

Both themes.

At 4.5:1:
- `--ink`, `--ink-soft` and `--link-ink` on paper, card and cell;
- `--ink-soft` on every tint;
- `--hot-ink` on card, paper and `--hot-tint`;
- `--ok` on card and `--ok-tint`;
- `--on-hot` on `--hot`;
- `--on-band` and `--on-band-soft` on `--band`.

At 3:1:
- `--line-strong` on paper, card, cell and off;
- `--hot` and `--ok` strokes on card.

The template's defaults, measured (light / dark):

| Pair | Light | Dark |
|---|---|---|
| `--hot` on card | 5.75 | 7.31 |
| `--hot` on paper | 5.51 | 8.03 |
| `--hot` on `--hot-tint` | 4.93 | 6.78 |
| `--hot` on `--warn-tint` | 4.91 | 6.27 |
| `--on-hot` on `--hot` | 5.75 | 8.06 |
| `--ok`, `--link` on card | 6.29 | 7.67 |
| `--ok`, `--link` on paper | 6.03 | 8.43 |
| `--ok` on `--ok-tint` | 5.47 | 6.97 |
| `--ink-soft` on cell | 5.09 | 7.38 |
| `--ink-soft` on tints a, b, c | 4.71 or more | 6.69 or more |
| `--ink-soft` on `--hot-tint` | 4.81 | 6.55 |
| `--line-strong` on paper, card, cell, off | 3.18 or more | 3.26 or more |
| `--on-band-soft` on `--band` | 7.18 | 8.16 |

## Dark

An app with no dark values ships the page light only: remove both dark blocks and say so in a note on the page. Never put the default dark values under an app's light ones.

## Fonts

Use the app's real families from Google Fonts when they are there, with a system fallback otherwise. Change the `<link>` to match. h1 and h2 weights follow the app's display and heading roles (defaults: 400 and 600).

## Classes

- **Page:** `.wrap`, `header.hero` with `.eyebrow`, `h1`, `.lede`, `.facts` of `.chip`s, and `nav.toc`.
- **Section:** `section.sheet` with `.head` (`.num`, `h2`, one line), then one `figure` holding `.fig` with an SVG and a `figcaption`, or one `.tbl`.
- **Boxes:** `.bx` plain, `.bxHot` the recommended or not-done one, `.bxOk` done, `.bxOff` rejected or not built (dashed).
- **Zones:** `.zA`, `.zB` grouping; `.zOff` rejected.
- **Lines:** `.ln` plain, `.lnHot` critical path, `.lnDash` optional, `.life` lifeline, `.grid`; arrow markers `#ah` and `#ahHot`.
- **Text in SVG:** `.tx`, `.txL`, `.ts`, `.tm` for real names in mono, `.tmI`, `.tmH`, `.txW` on `.goal`.
- **Pills:** `.pOk`, `.pTodo`, `.pWarn`. In tables, `.st.ok`, `.st.todo`, `.st.warn`.
- **Open questions:** `.cards` of `.card`, each with `h3`, one sentence and a `.raise` line.
- **Footer:** `footer.band` holding "Go deeper".

SVGs set `min-width: 820px` inside `.fig`, which scrolls sideways on phones. Build from the classes; don't restyle them.

## Mockups

Draw a screen inside `.fig` with the app's own components. Only here, also copy the app's tokens under their own names, so the components use real names. Use real-looking data, no device chrome, and give each state its own screen.
