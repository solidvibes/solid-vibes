# Progress pane

**Status:** Planned. Phase 1 (where we are) is built; phase 2 (what was kept, session details) is next. How it looks in a real Claude Code session is owner-checked, not tested here.

> A pane beside the chat that answers at a glance: where are we, do you need me, what was kept. It works in the Claude app, where the status bar is not shown.

```
▾ Now
  Running on its own
  Progress pane · Build · 5 of 8 steps · Phase 2 — What was kept
  Your next turn: check it works · after 3 more steps
▾ Journey
  ✓ Plan · you
  ▸ Build · AI · here
      ✓ Phase 1 — Where we are · 5 of 5 steps
      ▸ Phase 2 — What was kept · 0 of 3 steps
  ○ Review and verify · AI
  ○ Check it works · you
  ○ Release · you
▸ Files
▸ Session · 42% context
```

## When it acts

Only in a project with `.solidvibes/manifest.json`, checked again on every refresh. Anywhere else it opens nothing, registers nothing and passes every event on untouched. It never writes to the project and never blocks or changes a tool call: it only watches what already happened.

In a Solid Vibes project it opens at the start of a session and adds `/progress`, which opens it again and refreshes it.

## What it shows

| Section | Shows | Open at first |
|---|---|---|
| Now | `Running on its own` while the main turn runs; `Still working: N helpers running` when the main turn ended but sub-agents still run; else `Your turn` with the last paragraph of the AI's answer. Each open plan's stage, the ones that need you first, and with one plan the next time you are needed, `after N more steps` | yes |
| Journey (one plan) / Open work (several) | Plan → Build → Review and verify → Check it works → Release, each marked `you` or `AI`, the current one `here`; Build lists the plan's phases with their step counts. Several plans are one foldable card each. Running sub-agents sit under the plan their description names, the rest under `Other work`. With no open plan: `Working without a plan`, running helpers and the last five files changed this chat | yes |
| Files | The open plans, `.solidvibes/handover.md` and `docs/intent.md`, those that exist. Pressing one shows it in the pane, cut at 20,000 characters, with Back | no |
| Session | How full the AI's memory (context) is, with the percent in the header. At 80% it says to start fresh: `/clear`, then `go <plan>` for an approved plan, else that the handover keeps your place | no |

It never estimates time. Steps left are counted instead.

## Where it reads from

Plans and files come from the project, so the pane survives `/compact` and a new chat; only the turn state and the files changed this chat are per chat, and `/clear` resets them.

- **Plans folder**: the folder of the first backticked path on the Factory contract's `plans` line in `AGENTS.md`; with `none`, no line or no `AGENTS.md`, `docs/plans/` then `plans/`.
- **A plan's status**: the first word after `**Status**:` in the body, else the frontmatter `status:` (`draft` → Draft, `not-started` → Approved, `implemented` → Implemented, `deferred` → Deferred, `idea` hidden). Only Draft and Approved plans show.
- **Stage**: Draft is Plan (you approve it); Approved with unchecked steps is Build; Approved with every step checked is Review and verify.
- **Steps**: every `- [ ]` and `- [x]`, except those under `## Verification` and those for the owner only (the line says `only the user`, `owner-only` or `(you)`). Phases are `##` or `###` headings that start with `Phase`.
- **Sub-agents**: the session's agent list, those not completed, failed or killed.

It refreshes at the start of a session, when the main turn starts and ends, after a file is written, on `/progress`, and when Session is unfolded. Fold state is kept per section.

## The code

`hooks/progress-pane.tsx` is a Claude Code hooks module that `hooks/hooks.json` names under `modules`, beside the command hooks. `hooks/progress-pane-parse.ts` holds the plan parsing, `hooks/progress-pane-state.d.ts` the state it keeps (named as `types` in `plugin.json`), and `hooks/progress-pane.test.tsx` the tests `claude plugin test .` runs on the terminal, desktop, VS Code and mobile.

## Later

- **Stuck**: say when the AI is waiting on something it cannot do alone.
- **What to keep**: at Done, list what is worth saving into the project.
- **Phone notification** when it is your turn.
- **Worktree-aware step counts**: count steps a run ticks off in its own worktree.
