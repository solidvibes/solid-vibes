# One marketplace called solid-vibes, with plugins sv and sv-pro

**Date:** 2026-10-24
**Who decided:** agent's, hard to undo

## Context

Install lines are typed by people and copied into guides, so the names stick.

## Decision

The public repo is the marketplace `solid-vibes` and the plugin `sv` at its root. Its `marketplace.json` also lists `sv-pro`, the Flutter and Supabase extension, which comes from a separate private repo. Install: `/plugin marketplace add solidvibes/solid-vibes`, then `/plugin install sv@solid-vibes`. Skills are namespaced, so `/sv:plan`.

## Why

One catalog to add, the method and its extensions side by side; people without access to the private repo only get an access error on `sv-pro`.

## Alternatives

One repo with a private submodule (leaks structure, breaks the plugin install for everyone without access).

## What it means

Renaming the marketplace or a plugin breaks every install line and every namespaced skill name.
