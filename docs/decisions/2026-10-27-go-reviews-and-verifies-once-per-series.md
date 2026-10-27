# `go` reviews and verifies once per series

**Date:** 2026-10-27
**Who decided:** mine

## Context

`go` ran three fresh agents per phase (coder, review-and-fix, verify), each re-reading everything and re-running the full test suite, then verified the whole series again. On an iOS app a 4-phase plan spent most of its time cold-starting agents and running simulator tests that had already passed.

## Decision

- One coder takes as many consecutive phases as fit under about 400k tokens of context. It self-reviews against the plan and rules and runs only `checks.fast` plus a compile.
- One independent review-and-fix agent covers the whole series' diff. A run that touches a contract `risk` area is also reviewed on its own, before the next run builds on it.
- One verify at the end runs `checks.full`, the `run` walkthrough and screenshots.
- Slow suites (device, simulator, desktop app) run once per series unless something failed, with slow post-test diagnostics turned off.

## Why

The independent review caught real bugs, so it stays, once. Everything else repeated work: per-phase verifies re-ran suites the final verify ran anyway. Current agents hold several phases in one context without losing track.

## Alternatives

Per-phase review and verify (slow, mostly repeated work). No independent review (cheaper, but misses the bugs the reviews caught).

## What it means

A bug from an early phase is found at the end of the series, not right after it; `risk` runs are the exception. See `skills/go/SKILL.md`.
