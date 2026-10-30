# Agents

**Status:** Built. Checked against the Codex docs on 2026-10-24: Codex reads `.agents/skills/` from the working folder up to the repo root and `~/.agents/skills/`, and follows linked skill folders; the Codex app and CLI (0.156+) draw Mermaid. A real Codex session is not yet owner-checked.

> Skills say "show a visual" or "start a sub-agent". The agent profile says how.

## Where the settings live

- `setup/agents/<agent>.md` in this repo: one table row and one section per agent. Not a top-level `agents/` folder, because a plugin's `agents/` folder is loaded as Claude Code sub-agents.
- `solidvibes init --agents claude,codex,generic` copies the rows and sections in use into the project's `.solidvibes/agents.md` (generated). The visuals block in `AGENTS.md` points there. The profile says how a visual is shown; the `eli-solid` skill says how it is made. A project's `## Look` section (in `AGENTS.md` outside the generated blocks, or in `CLAUDE.md`) is project data that sets the page's look.
- Without that file (before `init` ran), skills write a local HTML file for a visual.
- A new agent is a new profile file.

## The profiles

| Agent | Visuals | Sub-agents | Worktrees | Skills folder |
|---|---|---|---|---|
| Claude Code | Artifacts | Agent tool, fresh context | `isolation: "worktree"` | plugin `skills/`, `.claude/skills/` |
| Codex | local HTML file; Mermaid for diagrams | `solidvibes run` per phase, else one session | `solidvibes worktrees` + `git worktree add` | `.agents/skills/`, `~/.agents/skills/` |
| Other agents, local models | Mermaid; HTML when a browser is at hand | `solidvibes run --agent "<cmd>"`, else one session | `solidvibes worktrees` + `git worktree add` | `.agents/skills/` and `~/.agents/skills/`, by path |

Each section also says how a choice is asked: Claude Code through AskUserQuestion on the main thread, the others as lettered options A–D plus "or tell me something else".

Without sub-agents, a skill runs every step in one session and the report says the review was not independent.

## Instructions and skills

- `AGENTS.md` is the only instruction file. Codex reads it natively; Claude Code reads it when there is no `CLAUDE.md`. In a project that has a `CLAUDE.md`, `init` adds the line `@AGENTS.md` to it.
- Project rules live in `.agents/skills/`. Claude Code does not read that folder, so `init` makes relative links `.claude/skills/<name>` → `../../.agents/skills/<name>`, committed, which work on every clone. `solidvibes doctor` reports a link that no longer resolves.
- Solid Vibes skills reach Claude Code through the plugin (`/sv:<name>`), and other agents through `~/.agents/skills/`, linked by `solidvibes install`. Install links every skill of sv, and of sv-pro when it finds it (`SOLIDVIBES_PRO_ROOT`, else a `solid-vibes-pro` folder beside sv). It replaces only its own links: a real folder or someone else's link of the same name is left alone and reported, and nothing is deleted.
- Setup is part of the `interview` skill (`skills/interview/setup.md`), so it works the same in every agent; `hello` reruns it as a refresh when the installed Solid Vibes is newer.
- Install also reports a link of its own whose skill is gone (a skill removed in a later version) as `dangling`, and leaves it for the user to remove. Rerun `solidvibes install` after every Solid Vibes update, so new and renamed skills (`go`, `hello`, `bye`) get linked.
- Codex and other agents have no session hooks: the user types hello at the start and bye at the end ([hello and bye](hello-and-bye.md)).
- Without a skill loader, a fresh session per phase comes from `solidvibes run --agent codex` or `--agent "<command>"` ([headless runs](headless-run.md)).

## Models

Claude Code pins `opus` for planning, plan review, code review and code in a `risk` area, `sonnet` for the rest. Elsewhere: "strongest" and "cheaper".
