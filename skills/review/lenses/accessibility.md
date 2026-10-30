# Accessibility lens

A lens of the `review` skill: can everyone use this, including people who see poorly, use a screen reader or a keyboard, turn the text size up, or get dizzy from motion. Read-only. The checks are `## The basics` in the `accessibility` skill, written there once; this lens runs them as a review.

Scope: each screen and state the diff changes, or every screen when the user asks about the whole project. `docs/design/system.md` too when it changed.

- Work through the eight basics per screen, cheapest first, as the skill's `## Checking it` says. Compute contrast from the real colour values, in both modes.
- Each finding says who is left out and how ("someone using a screen reader hears 'button' and doesn't know it deletes the entry"), then the screen or file.
- A basic you could not check (no way to run the app) is a row saying so, not a pass.

Severity: BLOCKER when someone can't do the screen's main job (no label on the only button, text that fails contrast, an error shown only in red); SUGGEST for the rest. Include three to five OK rows for basics that passed.
