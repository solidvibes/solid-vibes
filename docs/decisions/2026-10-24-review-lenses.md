# Security, docs, speed and architecture are review lenses

**Date:** 2026-10-24
**Who decided:** agent's

## Context

Security checks, docs drift checks, speed and code shape were separate skills or nothing at all. Each is a review with one concern, and each separate skill was another name to learn.

## Decision

`review` has lenses in `skills/review/lenses/`: `security.md`, `docs.md`, `speed.md`, `architecture.md`. A lens is read-only, runs on a diff or on the whole project, and reports in the review table. Several can run together, one sub-agent per lens. The security lens works through the stack profile's `security/` checklists when there are any.

Who runs them: the routing on "is it secure?", a first release or a change to sign-in, payments or personal data (security, whole project), and on "are the docs still true?" (docs); `go` after its last phase (docs); `release` every release (docs) and before the first one (security).

## Why

One skill, one table format, one way to merge findings. A new concern is a new lens file, not a new skill name.

## Alternatives

Separate `security-audit` and `update-docs` skills (more names, and the same review steps written twice). One review that always checks everything (slow, and the deep checks get skimmed).

## What it means

A lens never fixes; fixes go through `brief` or `plan`. See `skills/review/SKILL.md`.
