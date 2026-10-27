# solidvibes handover --snapshot [dir]
#   Replaces the `## Snapshot` section of .solidvibes/handover.md at dir's git toplevel with the
#   branch, `git status --short`, `git diff --stat`, the last 5 commits and `git worktree list`, at most 30 lines each.
#   Everything else in the file stays byte for byte; a missing file is created with that section only.
#   Silent and writes nothing unless .solidvibes/manifest.json exists and .solidvibes/.gitignore
#   lists handover.md, so the file is never committed. Run by the PreCompact hook.

# At most 30 lines of a git command's output, so the SessionStart hook stays small.
handover_git() { # <top> <git args…>
  local top="$1"; shift
  git -C "$top" "$@" 2>/dev/null | awk 'NR <= 30 { print } END { if (NR > 30) print "… " NR - 30 " more lines" }' || true
}

handover_section() { # <top>
  local top="$1"
  echo "## Snapshot"
  echo
  echo "_Written by \`solidvibes handover --snapshot\` on $(date '+%Y-%m-%d %H:%M'); replaced each time._"
  echo
  echo "Branch: $(git -C "$top" branch --show-current 2>/dev/null || true)"
  echo
  echo "Status:"
  echo '```'
  handover_git "$top" status --short
  echo '```'
  echo
  echo "Diff:"
  echo '```'
  handover_git "$top" diff --stat
  echo '```'
  echo
  echo "Last commits:"
  echo '```'
  handover_git "$top" log --oneline -5
  echo '```'
  echo
  echo "Worktrees:"
  echo '```'
  handover_git "$top" worktree list
  echo '```'
}

handover_snapshot() { # <top>
  local top="$1" file="$1/.solidvibes/handover.md" tmp bounds start end section
  [ -f "$top/.solidvibes/manifest.json" ] || return 0
  grep -qxF handover.md "$top/.solidvibes/.gitignore" 2>/dev/null || return 0
  [ ! -L "$file" ] || return 0
  section="$(handover_section "$top")"
  tmp="$top/.solidvibes/.handover.tmp.$$"

  if [ ! -f "$file" ]; then
    printf '%s\n' "$section" > "$tmp"
    mv "$tmp" "$file"
    return 0
  fi

  # Start and end line (exclusive) of the section, outside code fences; 0 0 when there is none.
  bounds="$(awk '
    /^```/ { fence = !fence }
    { line = $0; sub(/\r$/, "", line) }
    !fence && line == "## Snapshot" && !s { s = NR; next }
    !fence && s && !e && /^## / { e = NR }
    END { print s + 0, e + 0 }' "$file")"
  start="${bounds% *}"; end="${bounds#* }"

  {
    if [ "$start" -eq 0 ]; then
      cat "$file"
      if [ -s "$file" ] && [ -n "$(tail -c 1 "$file")" ]; then echo; fi
      if [ -s "$file" ]; then echo; fi
      printf '%s\n' "$section"
    else
      if [ "$start" -gt 1 ]; then head -n $((start - 1)) "$file"; fi
      printf '%s\n' "$section"
      if [ "$end" -gt 0 ]; then
        echo
        tail -n +"$end" "$file"
      fi
    fi
  } > "$tmp"
  mv "$tmp" "$file"
}

cli_handover() {
  local snapshot=false dir="" top
  while [ $# -gt 0 ]; do
    case "$1" in
      --snapshot) snapshot=true ;;
      -*) echo "error: unknown option: $1" >&2; return 1 ;;
      *) [ -z "$dir" ] || { echo "error: one project folder only" >&2; return 1; }; dir="$1" ;;
    esac
    shift
  done
  [ "$snapshot" = true ] || { echo "usage: solidvibes handover --snapshot [dir]" >&2; return 1; }
  top="$(git -C "${dir:-.}" rev-parse --show-toplevel 2>/dev/null)" || return 0
  handover_snapshot "$top"
}
