# The cleanup skill

**Date:** 2026-11-01
**Who decided:** mine (called by name and routed; the owner says "cleanup"; answers `all`, `none` or numbers); agent's (the CLI does every delete)

## Context

The owner's Mac ran out of space and a hand cleanup was slow and risky: a `build/` folder held tracked files, and Claude Code denied every agent-typed `rm -rf`. `2026-10-24-skill-names-are-public-api.md` lists five skills called by name and says a new name needs a decision.

## Decision

A new skill, `cleanup`, called by name like `update` (owner-started, machine-wide, it deletes), and also given a routing row for "my disk is full" and "free up space". Six skills are now called by name.

The skill lists what takes space, explains each item in plain words, and asks for `all`, `none` or numbers. `all` means the safe items plus the proposed simulator group; other items go only by number. Every delete is done by `solidvibes disk --clean <id>…`, never by the agent: the CLI re-scans, re-checks each guard, refuses what it can't re-find, and never falls back after a tool refuses.

## Why

Said by name, it is started on purpose; the routing row catches the plain phrases people use when the disk is full. Deleting in the CLI keeps the checks in one tested place and needs one approval, and nobody is asked to loosen `rm` permissions.

## Alternatives

Routed only (a deleting skill could start from a stray phrase). Agent-typed `rm` and native commands (denied by Claude Code, and no guards). A fold into `update` (a different job, a different moment).

## What it means

The name is public API. Set-up projects refresh their routing block on the next `hello`, once the version that carries it is released. How it works: `docs/how-it-works/cleanup.md`.
