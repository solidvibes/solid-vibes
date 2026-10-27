# Skill names are public API

**Date:** 2026-10-24
**Who decided:** mine (the set of twelve); agent's, hard to undo (names as public API)

## Context

People say these names, projects cite them in `AGENTS.md` and docs, and agents are taught them. A rename breaks all of that quietly. Every skill is one more name to learn and keep true.

## Decision

Twelve skills. Called by name: `interview`, `hello`, `bye`, `release`, `update`. Picked by the routing in `AGENTS.md`: `brainstorm`, `brief`, `plan`, `design`, `go`, `review`, `verify`.

Small concerns are not skills of their own: security and docs drift are `review` lenses, a parked idea is one paragraph in `docs/ideas/`, and updating the docs is a `brief`.

## Why

People talk; the routing picks the step. A skill nobody calls by name is overhead unless it holds a step of its own. Twelve names cover a project from first idea to release and every session's start and end. Names are plain words a non-developer can say out loud.

## Alternatives

One skill per concern, such as a separate security audit or docs check (more names, overlapping work). A `ship` skill that both plans and builds (the routing plans; `go` builds).

## What it means

A new skill is cheap; a rename or removal needs a new decision and a note in the changelog. Codex and other agents rerun `solidvibes install` after a rename; it names links left by removed skills and deletes none. `solidvibes lint` fails when a skill or the routing template names a skill that does not exist.
