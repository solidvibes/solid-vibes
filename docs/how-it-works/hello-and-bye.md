# Hello and bye

**Status:** Built. A real Claude Code session (hello, `/compact`, bye) and a Codex session are owner-checked, not tested here.

> A session starts with `hello` and ends with `bye`. The CLI does the counting; the skills do the judging.

## Hello

`solidvibes hello [dir]` prints one line each, read-only, for the repo's top folder:

| Line | Says |
|---|---|
| `handover` | `.solidvibes/handover.md` present and its age, or `none` |
| `setup` | `same` or `differs`: the `sv` and profile versions in `.solidvibes/manifest.json` against the installed ones. No version math. A profile it cannot find shows as `unknown` and is not compared |
| `ci` | files under `.github/workflows/`, or `none` |
| `docs` | `same`, `changed` or `unchecked`: a hash of `AGENTS.md`, `docs/intent.md`, `docs/stack.md`, `docs/decisions/`, `docs/how-it-works/` and `.agents/skills/` against `.solidvibes/hello.state`. Plans and ideas are left out; they change every session |

`--full` adds `solidvibes doctor` and `solidvibes worktrees <top folder>`. `--checked` stores the current hash, and is run only after the AI tidied the docs.

The hash is `git hash-object` over the C-sorted file list followed by each file's contents.

The `hello` skill runs `git fetch` and `hello --full`, then: reads the handover and prunes Open and Next (see below); fast-forwards the branch when it is behind and clean; on `differs` refreshes the setup through `skills/interview/setup.md`; clears finished worktrees after saying so; runs `## Checks at hello` from `docs/stack.md`; ends with a brief: what needs the user, what's next from the handover and open plans, and the parked ideas when nothing is next. The `ci` and `docs` lines are read by `update`, whose audit checks CI and tidies the docs.

## Bye

The `bye` skill writes Done, Open and Next to `.solidvibes/handover.md` (about 15 lines, keeping `## Snapshot`) under the same pruning rule, then writes this session's corrections and decisions where the contract's `docs` line says, never inside `solidvibes:begin/end` blocks.

Between sessions the routing in `AGENTS.md` keeps Done, Open and Next current after a brief, a plan approval or a green pull request. A plan approval puts `- go <plan path>` first under Next, then runs `go <plan path>` in the same conversation while it is under about 250k tokens (the build runs in sub-agents), or ends with "Type /clear, then paste: `go <plan path>`" when it is longer; the SessionStart hook prints the handover after the clear, so the fresh session knows which plan to build. `go` with no plan named reads that line too, then falls back to searching the plans folders for an approved plan, private ones included. No hook can make the AI write before compaction, so this is how its own words survive.

## What the handover holds

Only what is in progress, since the SessionStart hook prints all of it every time. Done keeps its 5 newest lines (the hooks move the rest). Open and Next are pruned by `hello`, `bye` and the `AGENTS.md` routing, all with one rule: Keep Open and Next to what is still in progress: drop finished items (a one-liner goes to Done), merge duplicates, at most about 8 lines each. A thought for later goes to `docs/ideas/` not to Next.

## Hooks (Claude Code)

`hooks/hooks.json` in the plugin. Each hook runs a script in `hooks/` (`pre-compact.sh`, `session-start.sh`) that calls the CLI with the project from `$CLAUDE_PROJECT_DIR`, so the command line holds only the script's path. Both act only in a project with `.solidvibes/manifest.json` and always exit 0.

| Hook | Runs | Does |
|---|---|---|
| PreCompact | `solidvibes handover --snapshot` | Replaces the `## Snapshot` section of the handover with the branch, `git status --short` (at most 15 lines) and the last 5 commits. Everything else stays byte for byte, except the Done trim below. Writes nothing unless `.solidvibes/.gitignore` lists `handover.md` |
| SessionStart (`startup`, `resume`, `clear`, `compact`) | `solidvibes hello --hook` | Trims Done, then prints the handover and the status lines. Adds one line when the handover is over 6 KB, and one when `.solidvibes/.gitignore` lacks `done/` (the trim is off; run `solidvibes init`). On `startup` adds "Say hello for the full check." |

Both hooks keep the first 5 entries under `## Done` (newest first) and move the rest to the top of `.solidvibes/done/YYYY-MM.md`, newest first. The month is that of the first full date (`YYYY-MM-DD`, not in the future) in the entry's first line, else the current one. No hook prints these files, and each month stays its own file. A `.solidvibes/done.md` from an older version is split the same way once, then removed. Only when `.solidvibes/.gitignore` lists `done/`; an older project gets that line, and the hook's warning stops, when `init` runs again.

## Work log

`solidvibes handover --log` moves every entry of `.solidvibes/done/YYYY-MM.md` to the top of `docs/log/YYYY-MM.md` and removes the local file. `docs/log/` is committed, so the history reaches every device and every clone. `go` (at completion) and `brief` (at hand-off) run it, so the lines land in the same commit and pull request as the work. The hooks never write it: a hook writing a tracked file would leave every worktree dirty and two machines in conflict.

Codex and other agents have no hooks: the user types hello and bye.

## Local files

`.solidvibes/handover.md`, `.solidvibes/done/`, `.solidvibes/hello.state` and an older `.solidvibes/done.md` belong to one machine and are never committed. `init` writes a generated `.solidvibes/.gitignore` listing them (`done.md` too, so it stays ignored until it is split); it never touches the project's own `.gitignore`. `worktrees --clean` treats them as disposable, so a worktree that was compacted in can still be cleaned.
