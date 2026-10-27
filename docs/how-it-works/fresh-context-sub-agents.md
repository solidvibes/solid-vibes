# Fresh-context sub-agents

**Status:** Built (`plan`, `brief`, `go`, `review`, `verify`).

> The agent that wrote the code never reviews it. Each step starts clean and sees only what it is handed.

## Why

A reviewer who watched the code being written shares the author's blind spots. A fresh agent reads the diff as a stranger would. Fresh contexts also keep each agent small: an orchestrator that keeps diffs in its head fills up and gets worse.

## Who does what

| Step | Agent | Gets | Returns |
|---|---|---|---|
| Plan review | one fresh reviewer, strongest model | the plan paths and rule file paths, not the author's reasoning | findings; the author fixes |
| Code a phase | one fresh coder per phase | the whole plan, the rule file paths, the contract's commands | one commit |
| Review a phase (`go`) | one fresh agent that reviews and fixes | the diff, the plan, the rule files | a findings table and one fix commit |
| Review a brief or a series | fresh table-only reviewers, one per topic rule file plus one general; fresh fixer per round, at most 3 rounds | the diff and the rules; never earlier findings | merged table; `fix: review round <N>` |
| Review lens | one fresh agent per lens (security, docs, speed, architecture) | the lens file, the diff or the whole project | the lens's table, merged; read-only |
| Verify | one fresh agent with the `verify` skill | `checks`, `run`, `harness`, the plan's `## Verification`, the diff | the evidence table and owner follow-ups |

The orchestrator (`go`, `brief`) keeps only conclusions: commits, findings, deviations. Never the diffs.

## Rules every prompt carries

- **Rule files by path.** Sub-agents don't load `AGENTS.md` or topic rules by themselves; the prompt names them.
- **Contract commands quoted.** The prompt includes the actual `codegen` and `checks.fast` commands.
- **Commit discipline.** One commit at the end; `codegen` if a matching file changed, then `checks.fast`; hooks pass, never skipped.
- **Sized to fit.** A plan phase fits one coder (the `plan` skill's size check). A phase that doesn't is split, never run whole.
- **Cheap work stays home.** Starting an agent costs about 50k tokens. Status checks, worktree cleanup and one-line doc edits are done by the orchestrator.

## Agents without sub-agents

Per `.solidvibes/agents.md`: `solidvibes run` gives each phase its own fresh session. Without it, the steps run in one session and the report says plainly that the review was not independent.
