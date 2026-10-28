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

The `hello` skill runs `git fetch` and `hello --full`, then: reads the handover; fast-forwards the branch when it is behind and clean; on `differs` refreshes the setup through `skills/interview/setup.md`; clears finished worktrees after saying so; runs `## Checks at hello` from `docs/stack.md`; ends with a brief: what needs the user, what's next from the handover and open plans, and the parked ideas when nothing is next. The `ci` and `docs` lines are read by `update`, whose audit checks CI and tidies the docs.

## Bye

The `bye` skill writes Done, Open and Next to `.solidvibes/handover.md` (about 15 lines, keeping `## Snapshot`), then writes this session's corrections and decisions where the contract's `docs` line says, never inside `solidvibes:begin/end` blocks.

Between sessions the routing in `AGENTS.md` keeps Done, Open and Next current after a brief, a plan approval or a green pull request. A plan approval puts `- go <plan path>` first under Next and ends with "Type /clear, then paste: `go <plan path>`"; the SessionStart hook prints the handover after the clear, so the fresh session knows which plan to build. `go` with no plan named reads that line too, then falls back to searching the plans folders for an approved plan, private ones included. No hook can make the AI write before compaction, so this is how its own words survive.

## Hooks (Claude Code)

`hooks/hooks.json` in the plugin. Both act only in a project with `.solidvibes/manifest.json` and always exit 0.

| Hook | Runs | Does |
|---|---|---|
| PreCompact | `solidvibes handover --snapshot` | Replaces the `## Snapshot` section of the handover with the branch, `git status --short`, `git diff --stat`, the last 5 commits and `git worktree list`, at most 30 lines each. Everything else stays byte for byte. Writes nothing unless `.solidvibes/.gitignore` lists `handover.md` |
| SessionStart (`startup`, `resume`, `clear`, `compact`) | `solidvibes hello --hook` | Prints the handover and the status lines. On `startup` adds "Say hello for the full check." |

Codex and other agents have no hooks: the user types hello and bye.

## Local files

`.solidvibes/handover.md` and `.solidvibes/hello.state` belong to one machine and are never committed. `init` writes a generated `.solidvibes/.gitignore` listing both; it never touches the project's own `.gitignore`. `worktrees --clean` treats the two files as disposable, so a worktree that was compacted in can still be cleaned.
