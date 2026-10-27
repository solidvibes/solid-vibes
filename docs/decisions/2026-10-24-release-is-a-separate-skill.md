# release is its own skill and always waits for a go

**Date:** 2026-10-24
**Who decided:** mine

## Context

Merging, deploying and publishing reach outside the project and cannot be undone. `go` runs without stopping.

## Decision

`release` is a small separate skill. `go` ends at green pull requests. Before every outward step `release` says what it does and what it cannot undo and waits for an explicit go; one go covers one step. It never runs headless and never because a plan says so.

## Why

Folding it into `go` would put a stop-and-ask inside an autonomous loop and make `go` depend on the stack. Store and deploy steps come from the stack profile's `release.md`.

## Alternatives

`release` as `go`'s last step.

## What it means

A plan can say "release" as a goal but cannot grant the go. Every release runs `review` with the docs lens on what shipped; the first one runs it on the whole project, together with the security lens.
