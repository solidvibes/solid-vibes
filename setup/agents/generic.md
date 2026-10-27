<!-- Agent profile. `solidvibes init --agents generic` copies the table row and the section below into a project's `.solidvibes/agents.md`. -->
| Other agents, local models | Mermaid in markdown; an HTML file when a browser is at hand | `solidvibes run --agent "<cmd>"`, else one session (the report says the review was not independent) | `solidvibes worktrees` + `git worktree add` | `~/.agents/skills/` and `.agents/skills/`, read by path |

### Other agents and local models

- **Visuals** — a Mermaid diagram or a table in markdown in the reply. When a browser is at hand, a self-contained HTML file in a temp folder, outside the repo, opened, with its path said.
- **Questions** — a choice comes as lettered options A–D, the recommended one first, each saying what it means, plus "or tell me something else".
- **Sub-agents** — `solidvibes run --agent "<command>"` runs a phase in a fresh session. Without it, everything runs in one session, and the report says plainly that the review was not independent.
- **Worktrees** — `git worktree add` for a lane; `solidvibes worktrees --clean` removes the finished ones.
- **Skills folder** — a skill named in `AGENTS.md` is read by path: `.agents/skills/<name>/SKILL.md` in the project, else `~/.agents/skills/<name>/SKILL.md`, where `solidvibes install` put it.
- **Instructions** — read `AGENTS.md` first, by convention.
- **Models** — the strongest model available for planning and review; a cheaper one for the rest.
