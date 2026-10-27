# solidvibes statusline --check | --install | --decline
#   --check    reports the Claude Code settings file, whether it sets a statusLine, whether the
#              Solid Vibes script is installed, and the entry to add when none is set and the user
#              hasn't declined. Writes nothing.
#   --install  copies setup/statusline.sh to ${XDG_DATA_HOME:-~/.local/share}/solidvibes/statusline.sh,
#              then reports as --check does. Never writes the settings file; when a statusLine
#              that isn't ours is set, it copies nothing.
#   --decline  remembers a no next to the script, so setup stops offering it.

statusline_dest() { echo "${XDG_DATA_HOME:-$HOME/.local/share}/solidvibes/statusline.sh"; }
statusline_settings() { echo "${CLAUDE_CONFIG_DIR:-$HOME/.claude}/settings.json"; }

# none, declined, ours or other.
statusline_state() { # <settings> <dest>
  if [ ! -f "$1" ] || ! grep -q '"statusLine"' "$1"; then
    if [ -f "$(dirname "$2")/declined" ]; then echo declined; else echo none; fi
  elif grep -qF "$2" "$1"; then echo ours
  else echo other
  fi
}

# Replaces <dest> in one rename, so a status bar running at that moment never reads half a file.
statusline_copy() { # <dest>
  cp "$SOLIDVIBES_ROOT/setup/statusline.sh" "$1.tmp" && chmod +x "$1.tmp" && mv -f "$1.tmp" "$1"
}

# Refreshes an installed copy that differs from this version. Silent; never fails.
statusline_refresh() {
  local dest
  dest="$(statusline_dest)"
  [ -f "$dest" ] || return 0
  cmp -s "$SOLIDVIBES_ROOT/setup/statusline.sh" "$dest" && return 0
  statusline_copy "$dest" 2>/dev/null || rm -f "$dest.tmp" 2>/dev/null
  return 0
}

statusline_report() { # <settings> <dest> <state>
  local cmd="$2"
  echo "settings: $1"
  case "$3" in
    none) echo "statusLine: none" ;;
    declined) echo "statusLine: declined" ;;
    ours) echo "statusLine: Solid Vibes" ;;
    other) echo "statusLine: set, not ours; leave it alone" ;;
  esac
  if [ -f "$2" ]; then echo "script: $2"; else echo "script: not installed ($2)"; fi
  [ "$3" = none ] || return 0
  case "$cmd" in *" "*) cmd="\\\"$cmd\\\"" ;; esac
  echo "entry: \"statusLine\": { \"type\": \"command\", \"command\": \"$cmd\", \"padding\": 0 }"
}

cli_statusline() {
  local settings dest state
  settings="$(statusline_settings)"
  dest="$(statusline_dest)"
  state="$(statusline_state "$settings" "$dest")"
  case "${1:-}" in
    --check) ;;
    --install)
      if [ "$state" != other ]; then
        mkdir -p "$(dirname "$dest")"
        statusline_copy "$dest"
        rm -f "$(dirname "$dest")/declined"
      fi
      ;;
    --decline)
      mkdir -p "$(dirname "$dest")"
      : > "$(dirname "$dest")/declined"
      ;;
    *) echo "usage: solidvibes statusline --check | --install | --decline" >&2; return 1 ;;
  esac
  statusline_report "$settings" "$dest" "$(statusline_state "$settings" "$dest")"
}
