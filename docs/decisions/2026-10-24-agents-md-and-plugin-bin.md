# AGENTS.md is the only instruction file; the CLI ships in the plugin's bin/

**Date:** 2026-10-24
**Who decided:** agent's, from the current Claude Code docs

## Context

Solid Vibes keeps every project's instructions and Factory contract in `AGENTS.md`, so Claude Code, Codex and other agents read one file. That only works if Claude Code reads `AGENTS.md` without a `CLAUDE.md`. The `solidvibes` CLI ships in the plugin, which only helps if Claude's shell can run it without setup.

## What the docs say

- Memory docs, section "AGENTS.md" (https://code.claude.com/docs/en/memory#agents-md): with an `AGENTS.md` and no `CLAUDE.md` or `CLAUDE.local.md` in the working directory or above it, Claude reads `AGENTS.md`. With both, it reads `CLAUDE.md` only. A `CLAUDE.md` that imports `@AGENTS.md` reads both, and the import never loads it twice.
- Same page: reading `AGENTS.md` directly needs Claude Code v2.1.277 or later. Older versions, a disabled built-in plugin, or some first sessions after an upgrade read `CLAUDE.md` only. A `CLAUDE.local.md` also turns `AGENTS.md` off. Files under `.agents/` are not read.
- Plugin manifest reference, "Standard layout" (https://code.claude.com/docs/en/plugins-reference#standard-layout): files in a plugin's `bin/` are on the Bash tool's `PATH` while the plugin is enabled. claude.ai and Cowork do not install a plugin with a top-level `bin/`.

## Decision

- `init` writes no `CLAUDE.md`. `AGENTS.md` holds the instructions and the contract.
- In a repo that already has a `CLAUDE.md`, `init` adds one line, `@AGENTS.md`, to it.
- No one-line `CLAUDE.md` pointer in the templates: the native read makes it unnecessary.
- The CLI ships in the plugin's `bin/`; the README adds a `PATH` line for other agents and humans.

## Why

Both behaviors are documented and current. One file means one place to keep true, for every agent.

## Alternatives

- A `CLAUDE.md` with `@AGENTS.md` in every project: works on older versions too, but adds a second file whose only job is a pointer. Kept as the fix for the edge cases above, which `doctor` can name later.
- A symlink `CLAUDE.md` → `AGENTS.md`: works, but symlinks are fragile on some clones and editors.
- The CLI only through npm or a manual `PATH` step: more setup for a new builder; npm stays possible later.

## Consequence

The plugin cannot be installed in claude.ai or Cowork while `bin/` sits at the root. Solid Vibes targets Claude Code, so that is accepted.
