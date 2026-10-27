# Headless runs

**Status:** Built. A real run against a real agent is owner-checked, not tested here.

> `solidvibes run` starts one agent with no one to answer it, in its own worktree, inside a sandbox, and gets out of the way.

## What starts

| Input | Skill | The prompt ends with |
|---|---|---|
| a plan file, committed on the base branch | `go`, headless mode | `PLAN_FILE: <path in the worktree>` |
| a task in quotes | `brief`, headless mode | `TASK: <the task>` |

The prompt is the skill's `SKILL.md`, the line "Run this skill's Headless mode.", that line and `LOG_FILE: <the run's log>`, where a blocked run says why. It is written to `.claude/worktrees/<slug>.prompt.md` and reaches the agent on stdin.

- **Agent:** `claude -p` (default), `codex exec --sandbox danger-full-access --ephemeral -` (nono is the sandbox, so Codex's own is off), or `--agent "<cmd>"`: any command, run by bash; `{prompt_file}` in it becomes the prompt's path.
- **Where:** branch `auto/<slug>`, worktree `.claude/worktrees/<slug>`, log `<slug>.log` beside it (not inside the worktree). `.claude/worktrees/` goes into the repo's `.git/info/exclude`, never into a tracked file.
- **Base:** `origin/HEAD` when there is an `origin` remote (fetched first), else `main`, else `master`, else the main checkout's branch.
- **No remote:** the run commits on its branch and skips the push and the pull request; both `run` and the skill say so.
- **Refuses:** no `## Factory` in `AGENTS.md` on the base, a plan not committed there, a branch or worktree that already exists, nono missing without `--no-sandbox`.
- **`--dry-run`:** prints the base, branch, worktree, prompt and the exact commands, and changes nothing (not even a fetch).
- **Stop:** `solidvibes stop <slug>` stops nono session `sv-<slug>`, or an unsandboxed run's process and its children. The worktree, branch and log stay; `solidvibes worktrees --clean` removes the worktree once it is done.

## The sandbox

`profiles/solidvibes.json` extends nono's `default` profile, which denies credentials, keychains, browser data, shell history and shell configs. It grants nothing itself. `run` passes it by path, so it always matches the CLI; `solidvibes install nono` also links it into `${XDG_CONFIG_HOME:-~/.config}/nono/profiles/`, where nono looks up a profile by name, for running nono by hand.

Each run grants:

| Access | What |
|---|---|
| read | the repo, the Solid Vibes folder, the agent's folder and install folder (never the home folder or `/`), `~/.claude` (Claude) or `$CODEX_HOME`/`~/.codex` (Codex), `~/.agents/skills`, `~/.gitconfig`, `~/.config/gh`, `~/.config/git` |
| read and write | the run's worktree, the repo's `.git`, the run's log, `/tmp` |
| from the contract | each `sandbox` `read:` and `write:` path; a missing folder, an unset variable, `/`, the home folder or a folder above it, and a write into `~/.claude`, `~/.codex` or `~/.agents` are skipped with a warning |

Paths that don't exist are not granted. A GitHub sign-in kept in the macOS keychain stays out of reach, so `gh` inside a run only works with a token in `GH_TOKEN` or in `~/.config/gh`.

`--no-sandbox` runs the same command without nono, in the background, and records its process id in `.claude/worktrees/<slug>.pid`. The agent still skips its own permission prompts, since nobody is there to answer them, so it acts with every permission you have; `run` warns so on every such run. `stop` kills that process only while its command line still names the run's prompt file, so a reused process id is left alone.
