# The page skill is called `visual`

**Date:** 2026-11-01
**Who decided:** mine (the name `visual`, no alias); agent's (patch bump to 0.1.3)

## Context

`eli-solid` shipped in 0.1.2 two days ago. It is a name nobody can say out loud, and the Visuals step of every skill says "show a visual". `2026-10-24-skill-names-are-public-api.md` says a rename needs a new decision and a changelog note.

## Decision

The page skill is renamed `visual`, called as `/sv:visual`. The folder moves with `git mv`; every skill, the `AGENTS.md` template, the README and the docs name the new word. Its description keeps every old trigger phrase and adds "show me a visual" and "make it visual". Released as 0.1.3.

## Why

A plain word anyone can say, and it matches the phrase the skills already use. Nobody outside uses the old name yet, so this is the cheapest moment.

## Alternatives

Keeping `eli-solid` as an alias (project rule: no shims; no outside users). Leaving the name (hard to say, hard to remember).

## What it means

Codex users rerun `solidvibes install`, which names the old `~/.agents/skills/eli-solid` link for them to remove. Set-up projects refresh their generated `AGENTS.md` blocks on the next `hello`, when the sv version differs. The public website names `visual` only after 0.1.3 is released. The 2026-10-30 decision stays as history, with a pointer line.
