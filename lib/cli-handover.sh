# solidvibes handover --snapshot [dir]
#   Replaces the `## Snapshot` section of .solidvibes/handover.md at dir's git toplevel with the
#   branch, `git status --short`, `git diff --stat`, the last 5 commits and `git worktree list`, at most 30 lines each.
#   Everything else in the file stays byte for byte; a missing file is created with that section only.
#   Silent and writes nothing unless .solidvibes/manifest.json exists and .solidvibes/.gitignore
#   lists handover.md, so the file is never committed. Run by the PreCompact hook.
#   Then trims `## Done` to its first 5 entries (newest first); older ones move to the top of
#   .solidvibes/done/YYYY-MM.md (the entry's month, else this one), which no hook prints, and an
#   older .solidvibes/done.md is split the same way once. Only when .solidvibes/.gitignore lists done/.
# solidvibes handover --log [dir]
#   Moves every entry of .solidvibes/done/YYYY-MM.md to the top of the committed docs/log/YYYY-MM.md,
#   then removes the local file. Prints one line per month logged. Run by go and brief with the work.

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

HANDOVER_DONE_KEEP=5

handover_trim() { # <top>
  local top="$1" sv="$1/.solidvibes" file="$1/.solidvibes/handover.md" old="$1/.solidvibes/done.md"
  local dir="$1/.solidvibes/done" tmp moved split f m
  [ -f "$sv/manifest.json" ] || return 0
  grep -qxF done/ "$sv/.gitignore" 2>/dev/null || return 0
  [ ! -L "$file" ] && [ ! -L "$old" ] && [ ! -L "$dir" ] || return 0
  tmp="$sv/.handover.tmp.$$"
  moved="$sv/.done.tmp.$$"
  : > "$moved"

  # Entries are `- ` lines with their continuation lines; blank lines between moved ones are dropped.
  if [ -f "$file" ]; then
    awk -v keep="$HANDOVER_DONE_KEEP" -v moved="$moved" '
      /^```/ { fence = !fence }
      { line = $0; sub(/\r$/, "", line) }
      !fence && line ~ /^## / { if (moving) print ""; done = (line == "## Done"); moving = 0 }
      done && !fence && line ~ /^- / && ++n > keep { moving = 1 }
      moving { if (line != "") print > moved; next }
      { print }' "$file" > "$tmp"
  fi
  # A done.md from before the monthly archive is older than anything moved now.
  if [ -f "$old" ]; then awk 'body { print; next } /^- / { body = 1; print }' "$old" >> "$moved"; fi

  if [ ! -s "$moved" ]; then
    rm -f "$tmp" "$moved"
    return 0
  fi

  # One file per month, by the first YYYY-MM in an entry's first line, else this month.
  split="$sv/.done.split.$$"
  mkdir "$split"
  awk -v out="$split" -v now="$(date +%Y-%m)" '
    BEGIN { m = now }
    /^- / { m = now; if (match($0, /(19|20)[0-9][0-9]-(0[1-9]|1[0-2])/)) m = substr($0, RSTART, 7) }
    { if (out "/" m != last) { if (last != "") close(last); last = out "/" m } print >> last }' "$moved"

  mkdir -p "$dir"
  for f in "$split"/*; do
    m="${f##*/}"
    {
      echo "# Done $m"
      echo
      echo "_Done lines moved out of handover.md, newest first, by \`solidvibes handover\`; no hook prints this file._"
      echo
      cat "$f"
      if [ -f "$dir/$m.md" ]; then awk 'body { print; next } /^- / { body = 1; print }' "$dir/$m.md"; fi
    } > "$f.md"
    mv "$f.md" "$dir/$m.md"
    rm -f "$f"
  done
  rmdir "$split"
  if [ -f "$tmp" ]; then mv "$tmp" "$file"; fi
  rm -f "$old" "$moved"
}

handover_log() { # <top>
  local top="$1" dir="$1/.solidvibes/done" log="$1/docs/log" f m n
  [ -f "$top/.solidvibes/manifest.json" ] && [ -d "$dir" ] && [ ! -L "$dir" ] && [ ! -L "$log" ] || return 0
  for f in "$dir"/*.md; do
    m="${f##*/}"; m="${m%.md}"
    case "$m" in [12][0-9][0-9][0-9]-[01][0-9]) ;; *) continue ;; esac
    [ -f "$f" ] && [ ! -L "$f" ] && [ ! -L "$log/$m.md" ] || continue
    n="$(grep -c '^- ' "$f" || true)"
    mkdir -p "$log"
    {
      echo "# Work log $m"
      echo
      echo "_Done lines from the handover, newest first. Added by \`solidvibes handover --log\` with the work they describe._"
      echo
      awk 'body { print; next } /^- / { body = 1; print }' "$f"
      if [ -f "$log/$m.md" ]; then awk 'body { print; next } /^- / { body = 1; print }' "$log/$m.md"; fi
    } > "$log/.$m.tmp.$$"
    mv "$log/.$m.tmp.$$" "$log/$m.md"
    rm -f "$f"
    echo "logged $n line(s) to docs/log/$m.md"
  done
}

cli_handover() {
  local snapshot=false logged=false dir="" top
  while [ $# -gt 0 ]; do
    case "$1" in
      --snapshot) snapshot=true ;;
      --log) logged=true ;;
      -*) echo "error: unknown option: $1" >&2; return 1 ;;
      *) [ -z "$dir" ] || { echo "error: one project folder only" >&2; return 1; }; dir="$1" ;;
    esac
    shift
  done
  [ "$snapshot" != "$logged" ] || { echo "usage: solidvibes handover --snapshot|--log [dir]" >&2; return 1; }
  top="$(git -C "${dir:-.}" rev-parse --show-toplevel 2>/dev/null)" || return 0
  if [ "$logged" = true ]; then
    handover_log "$top"
    return 0
  fi
  handover_snapshot "$top"
  handover_trim "$top"
}
