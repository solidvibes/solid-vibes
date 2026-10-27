---
name: blank
description: The stack profile with no opinions. Use when `interview` sets up a project and no `stack-*` profile fits or is installed; the choices are then made with the user and written into the project's `docs/stack.md`.
version: 0.1.0
---

# Blank stack profile

A profile with no tech choices made yet. `solidvibes init --profile <this folder>` seeds the project's `docs/stack.md` from `stack.md` and its `## Factory` from `contract.md`. The format is in the Solid Vibes repo, `docs/how-it-works/profile-format.md`.

With this profile:
- The `interview` skill records each choice in the project's `docs/stack.md` as the user's answers settle it (platforms, offline or online, where data lives), each with one plain sentence on why.
- The `interview` skill's setup drafts the contract fields that are still `none` from the code once there is some: how to check it, how to run it, which areas are risky.

No topic rules, no harness, no scaffold.
