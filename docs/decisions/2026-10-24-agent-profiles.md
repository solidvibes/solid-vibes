# Agent profiles carry visuals, sub-agents, worktrees and skills folder

**Date:** 2026-10-24
**Who decided:** agent's, hard to undo

## Context

Skills say "show a visual" or "start a fresh sub-agent". How that happens differs by agent.

## Decision

One profile file per agent in `setup/agents/` (`claude`, `codex`, `generic`), not a top-level `agents/` folder, because a plugin's `agents/` folder is loaded as Claude Code sub-agents. `solidvibes init --agents` (run by the `interview` skill's setup) copies the profiles in use into the project's `.solidvibes/agents.md`, and the visuals rule in `AGENTS.md` points there. Without that file, skills write a local HTML file.

## Why

Skills stay the same in every agent; a new agent is a new file.

## Alternatives

Hardcoding Claude Code behavior in skills (not usable elsewhere). A top-level `agents/` folder (loaded as sub-agents by Claude Code).

## What it means

Without sub-agents a skill runs each step in one session and says the review was not independent. See `docs/how-it-works/agents.md`.
