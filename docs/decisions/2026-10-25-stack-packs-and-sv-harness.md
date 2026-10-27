# Stack rules come from central packs; the harness is a command

**Date:** 2026-10-25
**Who decided:** agent's, hard to undo

## Context

Copying a profile's rules and harness into every project left many copies that drifted from their source and had to be refreshed by `init`.

## Decision

Stack rules live centrally in the sv-pro plugin's packs. A project picks its packs in `docs/stack.md` `## Packs` and changes them locally in `## Overrides`. `init` copies no rules and vendors no harness. The harness is the `sv-harness` command, linked by `solidvibes install`.

## Why

One copy of each rule and of the harness, updated with the plugin. Local overrides keep a project's own calls in the project.

## Alternatives

Keep copying rules and the harness into each project (copies drift, refresh rewrites files).

## What it means

`.agents/skills/` holds only the project's own skills, still linked into `.claude/skills/`. Old generated rules stay where they are: `init` never deletes. `doctor` checks that the contract's harness command is installed and answers `status --json`.
