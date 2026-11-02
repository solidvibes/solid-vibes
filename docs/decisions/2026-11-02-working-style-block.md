# Working style is a generated block

**Date:** 2026-11-02
**Who decided:** mine (answer style is part of the setup); agent's (how an older section is handled)

## Context

How the AI answers (short, only what the person needs, lists and tables, a visual for each decision) should hold in every project, without the owner's own `CLAUDE.md`. `## Working style` was a seeded section: written once, never refreshed, and missing from projects that predate it.

## Decision

`working-style` joins `audience`, `routing` and `visuals` as a generated block, refreshed by every `init` and inserted before `## Factory` when missing. An older setup's `## Working style`, word for word as init seeded it, becomes the block. An edited one stays the owner's: init adds no block and says so, and `doctor` notes it.

## Why

A word-for-word seeded section holds nothing the owner wrote, so swapping it loses nothing. Replacing an edited one would overwrite their words; adding the block beside it would give two `## Working style` headings that can disagree.

## Alternatives

Always add the block beside the old section (two headings). Always replace it (overwrites edits). Never touch it (every existing project keeps the old text).

## What it means

`doctor` reports any template block missing from `AGENTS.md`, so `hello` refreshes a project missing one even at the same version. This updates `2026-10-24-agents-md-generated-blocks.md`, whose seeded list no longer has working style.
