# AGENTS.md has generated blocks and seeded sections

**Date:** 2026-10-24
**Who decided:** agent's, hard to undo

## Context

`AGENTS.md` is read by every agent and edited by people, and Solid Vibes needs its routing to improve over time without overwriting the project's words.

## Decision

Three parts are generated and refreshed by every `init`, between `<!-- solidvibes:begin <name> -->` and `<!-- solidvibes:end <name> -->`: `audience`, `routing` and `visuals`. Everything outside the markers (project, non-negotiables, working style, the Factory contract) is seeded once and never overwritten. `doctor` flags a generated block that was edited by hand.

## Why

A project picks up routing improvements by running `init` again, and keeps its own words.

## Alternatives

Fully generated (overwrites the project's words). Fully seeded (routing never improves).

## What it means

The marker names are part of the format. `solidvibes init` never moves anything itself. When it reports a `## Factory` in `CLAUDE.md`, the setup steps (`skills/interview/setup.md`, at the end of `interview` and in `hello`'s refresh) move it to `AGENTS.md` word for word, and only after the user says yes.
