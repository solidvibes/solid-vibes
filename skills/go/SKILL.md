---
name: go
description: Build an approved plan, or several, all the way to green pull requests. Use when someone says "go", "go ahead", "build it", "build this plan", "start building", "do all of these", "run the plan", "let's implement it", or after a plan is approved; also the headless mode that `solidvibes run <plan>` starts. Stops at green PRs: merging, deploying and store release belong to the `release` skill.
---

# Go

Execute one plan or many, end to end, without stopping for the user: one coder for as many phases as fit its context budget, checking its own work, then one independent review and one verify over the whole series, a visual check, parallel lanes in worktrees for independent plans. It ends at green pull requests.

You are the **lean orchestrator**. Sub-agents code, review and verify; you keep their conclusions (commits, findings, deviations), never their diffs. Keep your own replies to a few lines.

Modes (one loop, different entries):
- **Single plan** — one plan, phases grouped into as few coder runs as fit.
- **Series** — several plans or phases in order on one shared branch and one PR.
- **Lanes** — independent plans run in parallel in worktrees, each lane a series.
- **Headless** — started by `solidvibes run <plan>` inside a worktree, no one to ask. See the last section.

## How you talk to the user (this is the only mode)

- Scope out loud and say what you are about to do before you do it.
- Ask product questions only: who uses it, what they see, what they do next, what "done" looks like. Never a tech fork. A tech fork is decided from `docs/stack.md` (the stack profile) and recorded in the plan's `## Deviations` or `## Decisions` as the agent's decision, with one plain sentence on why when it matters. One that touches a contract `risk` area is shown to the user first, with a visual and that one sentence.
- Any screen change is shown as a visual, not text (see Visuals). Plain words: no file paths, no plan tables.
- They check it before it is ready. After green, walk them through the contract's `run` step by step until they have seen the change themselves, then mark it ready for review. A lane touching `risk` stops at a draft for a human reviewer.
- Reports are plain: what changed and how it was checked, per PR, with no verification jargon. Technical detail (findings tables, commands, `file:line`, owner follow-ups in full) goes in the PR body for a reviewer.

## Do small things yourself

A sub-agent costs about 50k tokens just to start. Handle these directly, without spawning one: PR and CI status checks, worktree cleanup, and one-line docs updates. Code, copy and builds go to a sub-agent. A one-off step with no code (a docs-only change) gets no agent of its own: fold it into the next lane's prompt.

## Models

Pin the model on every sub-agent where the agent supports it, and pass this table to lanes for theirs. In Claude Code the names are `opus` and `sonnet`; elsewhere read "strongest" and "cheaper".
- **strongest (`opus`)** — coding in a contract `risk` area, code review, judging a failing test (app bug or test bug), plan review.
- **cheaper (`sonnet`)** — coding outside `risk`, running suites and waiting on builds, PR bodies, status checks, visuals from finished content.

Sub-agents come from the agent profile `.solidvibes/agents.md`. An agent without sub-agents runs each phase in sequence in one session and says plainly in the report that the review was not independent.

## The contract

Read the project's Factory contract: the `## Factory` section of `AGENTS.md` in the repo root. Spec: `.solidvibes/factory-contract.md`. Read from `AGENTS.md` only. Missing → say so in plain words ("this project has no setup file yet") and offer the `interview` skill before anything else (it reads the repo first and asks only what the code does not answer); headless: append the reason to the file on the prompt's `LOG_FILE:` line, notify if `osascript` is available, and exit. A missing field gets the same treatment, for that field only; a field set to `none` is answered, not missing.

## Setup

- Resolve the plans to run, **in order**: the file paths the user names; for "the phases", the `<slug>-phase-*.md` set in the contract's `plans` (default `docs/plans/`) in phase order; with no plan named, the `go <plan path>` line under `## Next` in `.solidvibes/handover.md`, else search for plans marked `**Status**: Approved` and not `Implemented`: in the contract's `plans` folder, and when `plans` is `none` or private, also in `plans/` and `docs/plans/`. Search with plain file reads, not git, since a private folder is git-excluded. One match: use it and say which. Several: ask. None: say so and offer the `plan` skill. Later plans build on earlier ones, so order is load-bearing and plans on one branch run strictly sequentially.
- Read each plan in full and its `## Constraints` for `rules` file paths; pass them to every sub-agent.
- Tell every sub-agent the plan's packs: "Load the skills for packs <names> and apply `## Overrides` from docs/stack.md." Sub-agents get no prompt hook, so the prompt must say it.
- **Group phases into coder runs.** One coder takes consecutive phases, in order, while the run stays under about 400k tokens of context (each phase's size from the `plan` skill's size check). Several small phases, or a whole small plan, go to one coder; a big phase gets a coder of its own. A phase that touches a contract `risk` area ends its run, so it is reviewed before anything builds on it. A plan that fails the size check is never run whole.
- **Branch strategy: one shared branch per series.** On the default branch, create `feat/<slug>` and work there; never commit the series straight to the default branch. No worktree and no PR per plan in a series. If the user asked to commit pre-existing working-tree changes first, make them one checkpoint commit before branching.
- Run the contract's `codegen` and checks per its rules; every sub-agent that commits gets the **commit discipline**: before committing, run `codegen` if a matching file changed, then `checks.fast` plus the compile; pre-commit hooks must pass, never skipped. Quote the contract's actual commands in the prompt, since sub-agents don't see this one.
- **Test budget: slow suites run once per series.** Per phase and in the review: `checks.fast` plus a compile of what changed (the build part of `run` when `checks.fast` doesn't compile it: no tests, no launch). `checks.full`, device and app suites (simulator, emulator, desktop app) and the `run` walkthrough run once, in the final verify, and again only to re-check something that failed. Turn off slow post-test extras the test tool offers unless a failure needs them (for example `xcodebuild test -collect-test-diagnostics never`). Put this in every prompt that runs tests.

## Lanes (several independent plans)

- **Sweep first.** Run `solidvibes worktrees --clean .` so worktrees of earlier, finished lanes don't pile up. It removes only what is provably finished, never branches.
- Group plans into **lanes**. Plans that share files, an entry type, a schema or a layer chain go in one lane, in dependency order. Independent lanes run in parallel.
- Per lane: one background sub-agent in its own worktree (in Claude Code, `isolation: "worktree"`; elsewhere `solidvibes worktrees` and `git worktree add`), told to run this skill's **Series** mode on its plans in order, treat the plans as approved, pass the user's earlier answers (recorded as **mine** decisions in the plans' `## Decisions`), and follow the contract's `run` rules (local stacks, simulators, never production, never a physical device).
- **One machine.** Lanes share the user's computer. At most two lanes build or test at once; device suites (simulator, emulator, desktop app) run one at a time across all lanes. Tell every lane: cap test concurrency, one scratch backend per lane and stop it after each run, stop build daemons after builds, kill processes it started, shut down devices it booted when done.
- A lane that depends on another lane's unmerged work waits, or stacks on its branch. Say which, and why.
- **Phases you run yourself still get reviewed.** When you drive a plan phase by phase instead of handing a lane Series mode, follow the same flow: coder runs grouped as above, risk reviews where they apply, then the series review and the verify. Never skip them because the coder said its checks pass.

## For each coder run, in order

A plan without phases is a series of one phase. The independent review and the verify run once, after the last run.

### 1. Code and self-review
Spawn a fresh sub-agent for the run's phases. Pass:
- The **full plan file paths** and which phases are this run's: tell it to read each whole plan and execute those phases end to end, in order. Give sub-agents the entire plan, since they need Context, Approach and Constraints.
- `AGENTS.md` for the invariants, and the contract's `layers`.
- **What earlier plans already landed on this branch**: name the files and symbols the prior phases created or changed, and tell it to read their *current* state. A plan was written against the pre-feature tree; by phase 2 that tree has moved.
- Rule paths from Constraints.
- **Craft skills**: when the phases touch what people see or read, the `accessibility` and `writing` skills; when they touch sign-in, payments, personal data or secrets, the `security-basics` skill. Tell it to follow their basics.
- Findings carried forward from earlier runs (see step 3).
- **Sync with the default branch first**, unless on it: `git fetch origin && git merge origin/<default>` as its own merge commit (never rebase, never force-push); with no remote, skip the sync. Resolve conflicts keeping both sides' intent; regenerate generated files with the contract's `codegen` instead of hand-merging; run `checks.fast`. A conflict where the two sides genuinely contradict means stop and report. Already up to date → no commit. Record the resulting `HEAD` as the run's **base**.
- **Self-review before each commit**: re-read its own diff against the plan's `## Approach` and `## Decisions` and every `rules` file the diff touches, and fix what it finds. This does not replace the independent review.
- **Test budget**: `checks.fast` plus the compile, nothing slower (see Setup).
- Discipline: **one commit per phase**, not per step, with a focused message (why over what) ending with the project's co-author trailer; the commit discipline above; mark each step `- [x]` in the plan file as it completes (these land in that phase's commit); steps only a human can do (manual or GUI smoke steps) can't run headless, so leave them unchecked and surface them.
- Don't pause between steps; the plan is approved. **Stop and report** only when a step proves impossible and the way around it changes a hard-to-undo decision (data ownership, a contract, a schema) or touches a contract `risk` area the plan didn't name. Every other deviation: decide, record it under `## Deviations` in the plan, and keep going. A stop comes back to you: stop the series and tell the user.
- Have it report back: the base hash (and how any merge conflicts were resolved), steps done, commits (hash and subject), what its self-review fixed, final check and test counts, deviations, unresolved BLOCKERs, findings that only bite a later phase.

Wait for completion before the next run.

### 2. Risk review (only a run that touches a contract `risk` area)
When a run's diff touches a `risk` area, review it now, before the next run builds on it: one fresh agent as in **Review the series** below, on this run's commits only (`git diff <base>..HEAD`, with the base the coder reported). Every other run waits for the series review.

### 3. Carry forward
Hand any finding that only bites a phase in a *later* run (a cost that appears once X is wired, a contract the next phase must honor) to that run's coder as context, instead of burning a fix round on something the next phase will resolve anyway.

## After the last run

### Review the series (ONE agent, ONE round, no loop)
Spawn **one** fresh sub-agent that reviews *and* fixes in the same context, over the whole series' diff: not one per phase or run, and not one reviewer per `rules` file. A separate fixer pays a cold start to re-read a diff the reviewer already read. The one agent checks the diff against every `rules` file the diff touches.

Pass:
- Every plan path (each `## Approach` is the spec).
- The diff: `git diff origin/<default>...HEAD` after a fetch, or the local default branch with no remote. That excludes the default branch's merged changes.
- The contract's `rules` paths that apply to the diff.
- The `review` skill, to run in its **review-and-fix mode** (its table-only reviewer instructions produce the table; it then fixes). Say: do not ask "fix all?".
- The fix mandate: produce the findings table first, then act on it. Fix every BLOCKER; apply each SUGGEST unless it contradicts a plan's `## Decisions`, would break the build, or is wrong (verify before applying; skipping is legitimate, silently applying a wrong one is not). Commit once as `fix: review findings (<M>)` with the commit discipline. No findings acted on → no commit.

**Nothing double-checks this agent's reasoning**, so it must run `checks.fast` plus the compile before committing (the verify next runs the full suite) and report the findings table verbatim, which findings it fixed and which it skipped with the reason, and plainly whether any fix forced it outside a plan's `## Approach` or `## Decisions`. Capture all of that for the PR body under `## Unresolved findings`: an unverified fix that nobody flagged is worse than a known-open BLOCKER.

**Stop conditions: report, do not fix.** If a finding is design-level, contradicts a plan, or clearly won't hold in one pass, the agent stops and reports. When that comes back, **stop the series and tell the user** instead of verifying on top of it.

Read the returned table yourself. It is your only view of the series' quality; if the skip reasons don't hold up, this is the moment to catch it.

### Verify the series (once)
Run the `verify` skill once, as a fresh sub-agent: the whole diff against the default branch, every plan's `## Verification`, `checks.full`, the `run` walkthrough with a screenshot per changed screen and state, and the `harness`. It fixes what it can in one commit (`fix: verification`), re-runs only what failed, and reports its table and owner follow-ups. A failure it can't fix stops the series like a design-level finding.

## Visual check

After the verify, when the series changed a screen or a flow, show the user the result: for each changed screen and state, the verify's screenshot (or the mockup from the plan next to it), as the agent profile says to show visuals, else a local HTML file. Regenerate the plan's visual summary **as built**: what changed vs the plan, deviations, the verification table, and any `risk` area that still needs a human review, so the user can check the result without reading the diff.

## Completion (once, after all plans)

- For each plan: set `**Status**: Implemented` plus today's date, record deviations under `## Deviations` (a step that proved impossible, a decision you made that the plan didn't), and commit the plan updates.
- **Changelog** per the contract's `docs`: one short user-facing line ("X now does Y") under `## Unreleased`. One plain sentence, no sub-clauses, no bold spans, no "instead of…" tails. Skip if `none` or the change is invisible to users.
- **Docs**: move the touched `docs/how-it-works/<surface>.md` from `Planned` to `Built` in the same change that lands the code, and update "Right now" in `docs/README.md` when it exists. Reconcile the plan's `## Rule gaps` and any doc gaps on the right side of the contract's `docs` line: a behavior fact, limit or intent → the behavior docs; a code rule or gotcha → the matching `rules` file, a line or two, don't let it bloat; a crosscutting invariant → `AGENTS.md`. Don't restate behavior in a rule file. Stop to ask only for a brand-new rule file or a core change.
- **Docs drift check**: run the `review` skill with the docs lens after the last phase, scoped to the docs the plans touched plus any doc that names a changed file or behavior. The lens reports and fixes nothing. Put its drift list (doc line, claim, what the code does) in the PR body under `## Docs drift`, or in the final report when there is no PR. Then fix the drift the plans own yourself, on the right side of the contract's `docs` line as in **Docs** above; the rest stays listed for the user.

## Drive to green

- **Every PR passes the contract's `checks.full`.** If the contract's `harness` is not `none`, every lane also runs `<harness command> all`; failures are fixed on the PR branch and re-run until green. No harness → say plainly what stayed manual.
- **Push and open one draft PR per series** (never one per plan): `git push -u origin feat/<slug>`; write the PR body to a temp file (avoids shell-quoting trouble) with each plan's `## TL;DR` under a per-plan heading, a one-line review summary (BLOCKERs found and fixed across the series), the verification table, `## Docs drift` (the docs lens's drift list, or "none found"), `## Needs human review` if the series touches a contract `risk` area (name it), `## Unresolved findings`, and owner follow-ups; then `gh pr create --draft --title "<feature title>" --body-file <file>`. If a PR for the branch already exists, `gh pr edit <n> --body-file <file>` instead of a second. **No remote or no `gh`**: skip the push and the PR, say so plainly, and report the branch and its commits.
- **Green → ready.** Walk the user through the change (Visual check), then `gh pr ready`.
- **Stopped → draft.** At a big fork, a contradiction with a plan's decisions, or checks that won't go green: stop that lane at a **draft PR** (no PR only if nothing is worth keeping) whose body has `## Stopped at`, `## Needs` and `## To continue`. Other lanes keep going.
- If `osascript` is available, notify "PR ready: <slug>"; otherwise skip.
- **Never merge, tag, release, deploy or bump versions.** Those are the `release` skill's job, on the user's go, every time. If `release` isn't installed, tell the user plainly that the build is done and the next step is theirs.

## When to talk to the user

Only for: a fork that is theirs and wasn't settled before, a lane that stopped, setup that only they can do and that blocks progress, or a question they asked. Otherwise stay silent; a finished agent gets at most one line. Never fabricate a sub-agent's result: if the user asks before it is in, say it is still running.

## Final report

One table: stream → PR(s) → ready or draft → how it was checked → what is manual. Then the tasks only the user can do (setup, values only they have), then anything stopped and what continuing needs. Under 20 lines, plain words.

## Afterwards

Corrections or new constraints the user gave that aren't in the docs yet: place them per the contract's `docs` line (behavior fact → behavior docs, code rule → a `rules` file, crosscutting → `AGENTS.md`) and mention it in one line.

## Headless mode

Started by `solidvibes run <plan>`: you run non-interactively (for example `claude -p`) inside a git worktree on branch `auto/<slug>`, branched from the repo's default branch. The plan path is appended to the prompt as a line `PLAN_FILE: <absolute path inside the worktree>`, followed by `LOG_FILE: <absolute path of the run's log>`. That file is the one you read and mutate; it lives in the worktree, so writes land in the branch's commits. Nobody answers: tech choices follow `docs/stack.md`; anything that cannot be decided from the plan and the project blocks.

### Setup
- Read the contract (spec `.solidvibes/factory-contract.md`). Missing → append the reason to the file on the `LOG_FILE:` line (the run's log, outside the worktree), notify if `osascript` is available (`display notification "go blocked: <slug>" with title "needs input"`), and exit.
- Read the file on the `PLAN_FILE:` line. Derive `<slug>` from the branch name (`git branch --show-current`, strip `auto/`).
- Extract from `## Constraints` the `rules` file paths (pass them to every sub-agent) and from `## TL;DR` the bullets (they become the PR body).
- Tell every sub-agent the plan's packs: "Load the skills for packs <names> and apply `## Overrides` from docs/stack.md."
- Every sub-agent gets the commit discipline: one commit at the end, not per step; `codegen` if a matching file changed, then `checks.fast`; hooks must pass, never skipped. Quote the contract's actual commands. The test budget above applies: `checks.full` and device suites run in the verify only.

### 1. Code
Spawn a fresh sub-agent. Pass the plan's `## TL;DR`, `## Files`, `## Steps` and `## Decisions` (these only, not the whole plan body), the contract's `layers`, "Read these rule files before starting: <paths>", the commit discipline, and: mark steps `- [x]` in the plan file as you complete them (they land in the single end commit). Do not pass your reasoning chain or anything from the plan beyond those sections. Wait for completion.

### 2. Review → fix loop (max 3 rounds)
**Review**: specialist review per the contract (the `review` skill's specialist review, table-only reviewers) on the full diff against the default branch, no truncation. Every reviewer also gets the plan's `## TL;DR` and `## Approach`. Each round's reviewers are fresh; never pass earlier findings. Merge the tables. No BLOCKERs → exit the loop. BLOCKERs and round < 3 → spawn a fixer.

**Fixer** (fresh sub-agent). Pass the merged findings table, the current diff against the default branch, the same rule paths, and: "Fix every BLOCKER. Address SUGGESTs unless they conflict with the plan's `## Decisions`. Commit ONCE as `fix: review round <N> (<M> findings)`", plus the commit discipline. Loop back to review. After 3 rounds exit even if BLOCKERs remain; capture them for the PR body.

### 3. Verify
Spawn a fresh sub-agent. Pass the `verify` skill, the contract's `checks`, `run` and `harness`, the plan's `## TL;DR` and `## Verification`, the diff against the default branch, the same rule paths, and: "This is a sandboxed headless run: no cloud credentials, no GUI. Anything needing them is an owner follow-up, not a failure. Fix failures you can, commit ONCE as `fix: verification`", plus the commit discipline. Capture its table and owner follow-ups.

### 4. Ship
- With a remote: `git push -u origin auto/<slug>`. Without one, skip the push and the PR and say so in the final line.
- Write the PR body to a temp file: the plan's `## TL;DR` bullets verbatim, then the verification table, then `## Docs drift` (the `review` skill with the docs lens on the docs the plan touched; its list, or "none found"), then `## Needs human review` if the diff touches a contract `risk` area (name it), then `## Owner follow-ups` if any, then `## Unresolved findings` if the fix loop ended with BLOCKERs.
- With a remote and `gh`: `gh pr create --draft --title "<plan H1 title>" --body-file <file>`.
- If `osascript` is available, notify "PR ready: <slug>"; otherwise skip.
- Update the plan: `**Status**: Implemented` plus today's date, deviations under `## Deviations`, and commit this update. Docs and changelog as in Completion above.
- Print the PR URL (or, with no PR, the branch name) on the final line of stdout.

## Visuals

"Show a visual" means: as `.solidvibes/agents.md` says for the agent in use. If that file is missing, write a local HTML file and tell the user where it is.
