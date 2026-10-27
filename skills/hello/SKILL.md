---
name: hello
description: Start a working session. Read where the last one stopped, bring the project and its setup to the latest state, clear finished work, and say what to do next. Use when someone says "hello", "hi", "good morning", "let's start", "let's get going", "where were we", "what's next", or at the start of a session when the start-of-session note says to say hello.
---

# Hello

The start of a session, kept light. It picks up where the last one stopped, so nothing is lost overnight or to a compacted conversation, brings the project to its latest state and says what to do next. It never upgrades packages or tools and never audits; that is the `update` skill, run now and then.

How you talk to the user:
- Plain words, outcomes only. Say what you are about to do before you do it.
- Short. One line per thing found; details only when something needs their answer.
- One round at a time; group related questions.

The `solidvibes` command: in Claude Code the plugin puts it on the path; elsewhere it is `bin/solidvibes` in the Solid Vibes folder, two levels above this file's folder.

## 1. Read the status

From the repo root, run `git fetch` (no remote: skip it), then `solidvibes hello --full`. It prints one line each:
- `handover`: whether `.solidvibes/handover.md` exists, and its age;
- `setup`: `same` or `differs`, the project's Solid Vibes and profile versions against the installed ones;

then `solidvibes doctor` (the project's setup health) and `solidvibes worktrees` (finished side copies of the project). The `ci` and `docs` lines are for `update`; skip them here.

No Factory contract in `AGENTS.md`, or `setup: none`: say so in plain words and offer the `interview` skill. Stop here unless they decline.

## 2. Pick up the handover

Read `.solidvibes/handover.md` if it exists: Done, Open, Next, and the `## Snapshot` (branch, uncommitted work, last commits) written before the last compaction. Keep it in mind for the brief. Don't recite it.

## 3. Bring the project to its latest state

- **Latest commits.** When the current branch has an upstream and is behind it: with no uncommitted work, `git pull --ff-only` and say how many commits came in. Uncommitted work, or the branch has its own commits too: say so in one line and leave it. Never stash, merge or rebase here.
- **Latest setup.** On `setup: differs`, say "Solid Vibes was updated since this project was set up; I'll bring its files up to date. Nothing you wrote changes." Then follow `../interview/setup.md` (next to the `interview` skill) as a refresh: profile and agents from `.solidvibes/manifest.json`, never the blank defaults. Report what it changed in one line.
- **Doctor problems**: say each in one plain line and offer the fix; fix only on a yes.

Never update Solid Vibes itself here; Claude Code updates the plugin, and other agents rerun `solidvibes install`.

## 4. Clear finished work

When the worktrees table has rows marked `remove`, say "I'll clear N finished side copies of the project; nothing unfinished is touched." Then run `solidvibes worktrees --clean <repo root>`, always with the repo root, never a folder of projects. Report what was freed in one line.

## 5. Stack checks

Run what `## Checks at hello` in `docs/stack.md` lists, and say each result in one line. A failing check: say what it means and offer to fix it. Missing section, or still the italic placeholder: skip it; `update` drafts it.

## 6. Brief

One short message, a few lines:
- **Done in this hello**: what came in, what was refreshed or cleared. Nothing: leave the line out.
- **Needs you**: anything waiting on the user (a doctor problem, a failing check, an owner check from the handover's Open).
- **Now**: the handover's Next, then plans in the contract's `plans` folder with `status: not-started` or `draft`, newest first.
- **Ideas**: only when Now is empty, the parked ideas in `docs/ideas/`, one line each from its first sentence.

End with a question about what to work on, the first Now item (or, with none, the first idea) as the suggestion.
