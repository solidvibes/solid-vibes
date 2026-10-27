# Sessions start with hello and end with bye

**Date:** 2026-10-24
**Who decided:** mine (the rituals, local handover); agent's (hooks, hash, gitignore)

## Context

Work stops overnight, and a long chat gets compacted. Both lose what the AI knew: what was done, what is open, what comes next. 
## Decision

- `hello` starts a session, kept light: reads `.solidvibes/handover.md`, pulls new commits when the branch is behind and clean, refreshes the setup when the installed Solid Vibes differs from the project's, clears finished worktrees after saying so, runs `## Checks at hello` from `docs/stack.md`, and ends with a brief of what's next, or the parked ideas when nothing is. Upgrades, the CI check and the docs tidy-up belong to `update`.
- `bye` ends one: writes Done, Open and Next to the handover, then writes the session's corrections and decisions into decisions, rules or `AGENTS.md`.
- The CLI does the counting: `solidvibes hello` prints the status lines, `--checked` stores the docs hash for `update`, `solidvibes handover --snapshot` writes the git snapshot.
- In Claude Code, two plugin hooks act only in projects with `.solidvibes/manifest.json` and never block: PreCompact writes the snapshot; SessionStart prints the handover and the status lines.
- The handover and the hash file are local. A generated `.solidvibes/.gitignore` lists both; `worktrees --clean` treats them as disposable.
- Between sessions the routing updates Done, Open and Next after a brief, a plan approval or a green pull request.

## Why

A fixed start and end means nothing is lost to the night or to compaction, and lessons get written while they are fresh. No hook can make the AI write before compaction, so the snapshot is mechanical and the routing keeps the AI's own words current.

## Alternatives

PreCompact asking the AI to write the handover (no way to inject that). Committing the handover (daily noise; it is one machine's state). Checking CI and tidying the docs every session (slow, mostly finds nothing; `update` does it now and then). `hello` updating Solid Vibes itself (Claude Code auto-updates the plugin; others rerun `install`).

## What it means

Codex and other agents have no hooks; the user types hello and bye. See `docs/how-it-works/hello-and-bye.md`.
