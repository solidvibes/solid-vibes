# The contract names the stack and the harness; the harness interface is versioned

**Date:** 2026-10-24
**Who decided:** agent's, hard to undo

## Context

Skills need to prove changes through a harness when one exists, and to work without one. Detecting an add-on by looking for it would break in other agents and in CI.

## Decision

The Factory contract in `AGENTS.md` has two fields beyond the first ten: `stack` (the project's stack file and the profile it came from, or `none`) and `harness` (the command and what it covers, or `none`). Skills never check whether an add-on is installed. When `harness` is not `none` and its command exists, a skill runs `<command> status --json`, which lists each level and target as available or not. Available levels go through the harness; the rest fall back to `checks` and `run`; a level with neither becomes exact steps for the owner.

The harness interface. Commands: `version`, `status [--json]`, `up`, `down`, `reset --yes`, `devices [--erase|--shutdown]`, `guard`, `unit`, `db [--local|--linked]`, `story <name> --target <t>`, `screenshots`, `all`. Exit codes: 0 pass, 1 fail, 2 refused by the guard, 3 not available here. Every run writes `.harness/out/<run-id>/report.json`, a list of `{level, check, result, evidence}`, never holding a secret. The guard runs first and refuses CI, production hosts, non-loopback stacks, migration drift and a wrong linked project.

## Why

Declared beats sniffed: the same skills behave the same in every agent, and a missing tool costs only the level it served.

Exit code 3 lets `verify` tell "could not check here" from a pass or a failure. One report shape means one verify table for any harness.

## Alternatives

Looking for an installed plugin (breaks outside Claude Code). One all-or-nothing switch (no Docker would lose the device checks too). Free-form output (nothing to parse). Treating a missing tool as a failure (hides real failures among setup gaps).

## What it means

The `harness` and `stack` field names, the per-level fallback, the commands, the exit codes and the report shape are a contract; changing one needs a version bump and a new decision. See `docs/how-it-works/seam.md`.
