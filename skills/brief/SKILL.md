---
name: brief
description: Brief a small change, then implement, review and verify it, with no plan file. Use when someone asks for "a quick fix", "a small change", "can you tweak", "change this text", "fix this bug", "add a button", "update the docs", one clear thing with one obvious approach; also the headless mode that `solidvibes run "<task>"` starts.
---

# Brief

A small change, end to end: trace, brief, code, review, verify. For focused changes (a bug fix, a small addition, one logical unit) where a plan file is more overhead than the change deserves. For anything with separable phases or that needs a lasting record, use `plan`. "Update the docs" is a brief too: list what changed since the docs were last touched and reconcile them as in Phase 4, with no code change.

Two modes:
- **Interactive** (default): you work with the user, who reads and answers in plain language.
- **Headless**: started by `solidvibes run "<task>"`. No one answers; sub-agents do the work. See the last section.

How you talk to the user in interactive mode:
- Say what you are about to do before you do it.
- Ask a question only when something is genuinely ambiguous or would change the approach, and then only about outcomes (who uses it, what they see, what they do next, what "done" looks like). Never a tech question. A tech fork is decided from `docs/stack.md` and explained in one plain sentence; if it touches a contract `risk` area, show it with a visual first.
- Plain words, no file paths, no jargon in what the user reads. Technical detail (layers, `file:line`, findings) goes in the PR body or a commit message.

## The contract

Read the project's Factory contract: the `## Factory` section of `AGENTS.md` in the repo root. Spec: `.solidvibes/factory-contract.md`. It is read from `AGENTS.md` only. Missing → say so in plain words and offer the `interview` skill; never guess a stack. (Headless: end with `Status: blocked: no Factory contract`.) A missing field gets the same treatment, for that field only; a field set to `none` is answered, not missing.

## Phase 1 — Trace the code (silently)

Walk the contract's `layers` end to end for the change. Don't skim a layer.

Load the contract's always-on `rules` and the topic rules that apply to the code the change will touch. `AGENTS.md` covers crosscutting invariants. Load the skills for the packs in `docs/stack.md` `## Packs` that cover those files and apply `## Overrides` from `docs/stack.md`; a sub-agent you spawn gets the same instruction, since it gets no prompt hook. Check the contract's `plans` for recent related plans.

## Phase 2 — Brief

Report back to the user in plain words; the per-layer trace with `file:line` references goes in the commit message, not in what they read:
- **What's broken vs fine** — what works, what doesn't, and where the actual root cause sits.
- **Approach** — the fix and why. Alternatives only if they were genuinely close.
- **Edge cases handled** — enumerate them. Flag any you are deliberately not handling and why.
- **Risk** — any contract `risk` area touched, or "none".
- **Open questions** — only things that need the user's input. If there are none, say so.

Prefer the simplest approach that works and the one that stays stable over time.

## Phase 3 — Ship it

Proceed without waiting for a "go", unless the brief has an open question that would change the approach, or the change touches a `risk` area. Then stop and wait; if it is a `risk` area, show the user a visual of the choice and one plain sentence on what it changes for them.

Run `codegen` if a matching file changed, then `checks.fast` plus a compile of what changed. `checks.full` and device or app suites run once, in the verify at the end. Surface pre-existing errors in unrelated files, don't fix them.

## Phase 4 — Hand off

One or two sentences: what changed, how it was checked, anything pre-existing or unrelated you noticed.

Changelog per the contract's `docs`: one short user-facing line ("X now does Y") under `## Unreleased`. One plain sentence, no sub-clauses, no bold spans, no "instead of…" tails. Skip if `none` or the change is invisible to users (a pure refactor, internal infrastructure, generated code).

If the change revealed stale or missing docs, reconcile them on the right side of the contract's `docs` line: a changed behavior fact, limit or intent → the behavior docs (`docs/how-it-works/<surface>.md`, status `Built` in the same change, or `docs/intent.md` through a decision); a stale or missing code rule or gotcha → the matching `rules` file, a line or two, don't let it bloat; a crosscutting invariant → `AGENTS.md`. Don't restate behavior in a rule file. Stop to ask only for a brand-new rule file or a core change. Update "Right now" in `docs/README.md` when it exists and the state moved.

## Phase 5 — Review

Run the `review` skill on the current diff: specialist review per the contract. Show the merged findings table, then fix every BLOCKER and every SUGGEST you agree with, without asking, and re-run `checks.fast` plus the compile. Only stop to ask if a finding contradicts the brief.

Then run the `verify` skill against the brief's approach and fix what fails.

## Visuals

"Show a visual" means: as `.solidvibes/agents.md` says for the agent in use. If that file is missing, write a local HTML file and tell the user where it is.

## Headless mode

You run non-interactively (for example `claude -p`) inside a git worktree on branch `auto/<slug>`, branched from the repo's default branch. `solidvibes run` set this up. The task is appended to the prompt as a line `TASK: <one-sentence task description>`, followed by `LOG_FILE: <absolute path of the run's log>`. There is no user to ask: decisions follow `docs/stack.md` and the project's conventions, and anything that cannot be decided that way blocks.

### Setup
- Derive `<slug>` from the branch name (`git branch --show-current`, strip `auto/`).
- Read the `TASK:` line: that is your input.
- Read the contract (spec `.solidvibes/factory-contract.md`). Missing → `Status: blocked: no Factory contract`, see step 1's abort path.

Every sub-agent that commits gets the **commit discipline**: one commit at the end; before it, run the contract's `codegen` if a matching file changed, then `checks.fast`; pre-commit hooks must pass, never skip them. Quote the contract's actual commands in the prompt: sub-agents don't see this one.

### 1. Brief
Spawn a fresh sub-agent (fresh context, general-purpose). Pass:
- The task (the `TASK:` value).
- "Trace the call graph end to end for this change along these layers: <contract `layers`>. Don't skim a layer."
- "Find the rule files that apply: <contract `rules`>. Read only enough of each (for example a skill's description) to decide."
- "Write a note to `.claude/worktrees/<slug>.brief.md` with this structure (exact section names):
  - **What's broken vs fine** — per layer, with `file:line`
  - **Approach** — the fix and why
  - **Edge cases** — handled and deliberately not
  - **Pitfalls** — anything that could derail the fix
  - **Risk** — any of these areas touched: <contract `risk`>, or `none`
  - **Rules** — a line `Rules: <path1> <path2>` listing the rule file paths that apply
  - **Packs** — a line `Packs: <name> <name>` listing the packs in docs/stack.md `## Packs` that cover the touched files, or `Packs: none`
  - **Status** — the final line MUST be exactly one of:
    - `Status: proceed`
    - `Status: blocked: <one-line reason>`
  Block only when the task is ambiguous in a way that changes a hard-to-undo decision. The orchestrator reads only the `Status:` line to decide whether to continue. Phrasing matters; do not vary it."

Wait for completion. Read `.claude/worktrees/<slug>.brief.md` yourself.

Parse the final `Status:` line:
- `Status: proceed` → continue to step 2.
- `Status: blocked: <reason>` → abort. If `osascript` is available (macOS), run `osascript -e 'display notification "brief blocked: <slug>" with title "needs input"'`; otherwise skip the notification. Append the briefer note and the abort reason to the run's log (`echo` into the file on the `LOG_FILE:` line). Exit cleanly.

Extract the `Rules:` line. Those paths feed the coder, the reviewers and the fixer. Extract the `Packs:` line too: each of them is told "Load the skills for packs <names> and apply `## Overrides` from docs/stack.md."

### 2. Code
Spawn a fresh sub-agent. Pass:
- The task.
- The full briefer note.
- "Read these rule files before starting: <paths from the briefer>".
- The commit discipline.

### 3. Review → fix loop (max 3 rounds)
Same loop as the `go` skill's headless review loop, with the briefer note in place of the plan sections: fresh reviewers each round using the `review` skill, merge the tables, a fresh fixer for BLOCKERs, commit as `fix: review round <N> (<M> findings)`. Unresolved BLOCKERs go in the PR body.

### 4. Verify
Spawn a fresh sub-agent. Pass the `verify` skill, the contract's `checks`, `run` and `harness`, the task, the briefer note, the diff against the default branch and the same rule paths, and: "This is a sandboxed headless run: no cloud credentials, no GUI. Anything needing them is an owner follow-up, not a failure. Fix failures you can, commit ONCE as `fix: verification`", plus the commit discipline. Capture its table and owner follow-ups.

### 5. Ship
- If the repository has a remote: `git push -u origin auto/<slug>`. If it has none, skip the push and the PR and say so in the final line.
- Write the PR body to a temp file (a file avoids shell-quoting issues with backticks, `$` and quotes): the briefer note, then the verification table, then `## Needs human review` if its **Risk** isn't `none`, then `## Owner follow-ups` if any, then `## Unresolved findings` if the fix loop ended with BLOCKERs.
- With a remote and `gh` available: `gh pr create --draft --title "<one-line summary of the TASK>" --body-file <that file>`.
- If `osascript` is available, notify "PR ready: <slug>"; otherwise skip.
- Print the PR URL (or, with no PR, the branch name) on the final line of stdout.
