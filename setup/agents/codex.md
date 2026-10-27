<!-- Agent profile. `solidvibes init --agents codex` copies the table row and the section below into a project's `.solidvibes/agents.md`. -->
| Codex | local HTML file opened in the browser; Mermaid in markdown for diagrams | `solidvibes run` per phase, else one session | `solidvibes worktrees` + `git worktree add` | `.agents/skills/` (repo, from the working folder up), `~/.agents/skills/` |

### Codex

- **Visuals** — write a self-contained HTML file in a temp folder, outside the repo, and open it in the browser (`open` on macOS, `xdg-open` on Linux); say where it is. For a diagram inside a reply, Mermaid in a markdown code block: the Codex app draws it, and so does the terminal from Codex CLI 0.156 (some shapes fall back to source).
- **Questions** — a choice comes as lettered options A–D, the recommended one first, each saying what it means, plus "or tell me something else".
- **Sub-agents** — none built in. Run each phase as its own session with `solidvibes run --agent codex`, which gives it a fresh context. Without it, run the phases one after another in this session and say plainly in the report that the review was not independent.
- **Worktrees** — `git worktree add` for a lane; `solidvibes worktrees --clean` removes the finished ones.
- **Skills folder** — reads `.agents/skills/` in every folder from the working folder up to the repo root, and `~/.agents/skills/`, where `solidvibes install` links the Solid Vibes skills. It follows linked skill folders.
- **Instructions** — reads `AGENTS.md` natively.
- **Models** — the strongest model for planning, plan review, code review and code in a `risk` area; a cheaper one for the rest.
