# solidvibes stop <slug>
#   Stops a run started by `solidvibes run`: its nono session sv-<slug>, or for a
#   --no-sandbox run the process in .claude/worktrees/<slug>.pid and its children.
#   The worktree, branch and log stay; `solidvibes worktrees --clean` removes the worktree once it is done.

cli_stop() {
  [ $# -eq 1 ] || { echo "usage: solidvibes stop <slug>" >&2; return 1; }
  local slug="$1" session="sv-$1" line repo pid_file pid
  case "$slug" in ""|.*|*/*) echo "error: not a run name: $slug" >&2; return 1 ;; esac
  line="$(git worktree list --porcelain 2>/dev/null | head -1)"
  [ -n "$line" ] || { echo "error: run this inside a git repo" >&2; return 1; }
  repo="${line#worktree }"
  pid_file="$repo/.claude/worktrees/$slug.pid"

  if command -v nono >/dev/null 2>&1 && nono ps --json 2>/dev/null | grep -qF "\"$session\""; then
    echo "stopping nono session $session"
    nono stop "$session"
  elif [ -f "$pid_file" ]; then
    pid="$(cat "$pid_file")"
    case "$pid" in ""|*[!0-9]*|0) echo "error: $pid_file does not hold a process id" >&2; return 1 ;; esac
    if kill -0 "$pid" 2>/dev/null && ps -ww -o args= -p "$pid" 2>/dev/null | grep -qF "$repo/.claude/worktrees/$slug.prompt.md"; then
      echo "stopping unsandboxed run $slug (process $pid and its children)"
      pkill -TERM -P "$pid" 2>/dev/null || true
      kill -TERM "$pid" 2>/dev/null || true
      local _
      for _ in 1 2 3 4 5; do
        kill -0 "$pid" 2>/dev/null || break
        sleep 1
      done
      if kill -0 "$pid" 2>/dev/null; then
        pkill -KILL -P "$pid" 2>/dev/null || true
        kill -KILL "$pid" 2>/dev/null || true
      fi
    else
      echo "$slug (process $pid) was not running; process $pid, if any, is something else and was left alone"
    fi
    rm -f "$pid_file"
  else
    echo "error: no nono session $session and no $pid_file" >&2
    return 1
  fi

  echo "stopped. The worktree and log stay:"
  echo "  $repo/.claude/worktrees/$slug/"
  echo "  $repo/.claude/worktrees/$slug.log"
}
