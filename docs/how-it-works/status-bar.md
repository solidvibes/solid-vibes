# Status bar

**Status:** Built. How it looks in a real Claude Code session is owner-checked, not tested here.

> A two-line bar at the bottom of Claude Code: where you are, and how full the AI's memory is. Offered at setup to anyone who has none; an existing one is never touched.

```
my-app · main
Opus  ▓▓▓░░░░░░░ 30%  $1.23  1h15m
```

Line 1 is the folder and its git branch. Line 2 is the model, a 10-cell bar of the context window with its percentage, the session cost and the time. Past 400k tokens in context, or at 80% of a smaller window, it adds `→ time for a fresh start: /clear` in yellow. The rest is grey. At the start of a session, before the first answer, the percentage shows `–`.

## The script

`setup/statusline.sh` reads the session JSON Claude Code passes on stdin, with `sed` only (bash 3.2, no jq): `model.display_name`, `context_window.used_percentage`, `context_window.context_window_size`, `context_window.current_usage` (`input_tokens` + `cache_creation_input_tokens` + `cache_read_input_tokens`, the same sum Claude Code uses for the percentage), `cost.total_cost_usd`, `cost.total_duration_ms` and `workspace.current_dir`. Without a percentage it computes one from `current_usage`; when both are null it shows `–`. The branch comes from `git -C <dir> branch --show-current`.

## Installing

A plugin cannot set `statusLine`, so the user's own settings file has to.

| Command | Does |
|---|---|
| `solidvibes statusline --check` | Prints the settings file (`${CLAUDE_CONFIG_DIR:-~/.claude}/settings.json`), `statusLine: none`, `declined`, `Solid Vibes` or `set, not ours`, where the script is, and, when none is set and not declined, the exact `entry` to add. Writes nothing |
| `solidvibes statusline --install` | Copies the script to `${XDG_DATA_HOME:-~/.local/share}/solidvibes/statusline.sh`, then reports as `--check`. Copies nothing when a status line that isn't ours is set. Never writes the settings file |
| `solidvibes statusline --decline` | Leaves a `declined` file next to the script so setup stops offering it; `--install` removes it |

Setup's last step (Claude Code only) runs `--check`. With none set, it offers the bar in one sentence and shows the change to the settings file as a diff; on a yes it runs `--install` and the AI adds the entry with its edit tool, on a no it runs `--decline`. With one set, or after a no, it says nothing.

## Keeping it current

The SessionStart hook (`hello --hook`) refreshes the installed copy when it differs from this version (written beside it, then renamed over it), only in a project with `.solidvibes/manifest.json` and only when a copy exists. It writes nothing into the project and always exits 0.
