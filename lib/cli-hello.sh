# solidvibes hello [--full] [--checked] [--hook] [dir]
#   One line each, read-only, for the project at dir's git toplevel (default: the current one):
#     handover  .solidvibes/handover.md present and its age, or none
#     setup     sv and profile versions in .solidvibes/manifest.json vs the installed ones: same or differs
#     ci        .github/workflows/ present or not
#     docs      hash of AGENTS.md, docs/intent.md, docs/stack.md, docs/decisions/, docs/how-it-works/,
#               .agents/skills/ vs .solidvibes/hello.state: same, changed or unchecked
#   --full     adds `solidvibes doctor` and `solidvibes worktrees` for the toplevel
#   --checked  stores the current docs hash in .solidvibes/hello.state (the only write)
#   --hook     for the SessionStart hook: silent unless .solidvibes/manifest.json exists; prints the
#              handover, the lines above and, on startup, a reminder. Refreshes an installed status
#              bar script (outside the project) when it differs. Always exits 0.

HELLO_DOCS="AGENTS.md docs/intent.md docs/stack.md docs/decisions docs/how-it-works .agents/skills"

hello_mtime() { stat -f %m "$1" 2>/dev/null || stat -c %Y "$1"; }

hello_age() { # seconds → 5m, 3h, 2d
  if [ "$1" -ge 86400 ]; then echo "$(($1 / 86400))d"
  elif [ "$1" -ge 3600 ]; then echo "$(($1 / 3600))h"
  else echo "$(($1 / 60))m"
  fi
}

hello_docs_hash() { # <top>
  local p files
  files="$(cd "$1" && for p in $HELLO_DOCS; do if [ -e "$p" ]; then find "$p" -type f ! -name .DS_Store; fi; done | LC_ALL=C sort)"
  {
    printf '%s\n' "$files"
    while IFS= read -r p; do
      if [ -n "$p" ]; then cat "$1/$p"; fi
    done <<< "$files"
  } | git hash-object --stdin
}

# Prints the value of a top-level "key": "value" in the manifest.
hello_manifest_str() { # <manifest> <key>
  sed -n "s/^  \"$2\":[[:space:]]*\"\\([^\"]*\\)\".*/\\1/p" "$1" | head -n 1
}

hello_manifest_profile() { # <manifest> <name|version>
  sed -n "s/^  \"profile\":.*\"$2\":[[:space:]]*\"\\([^\"]*\\)\".*/\\1/p" "$1" | head -n 1
}

hello_fm_version() { # <SKILL.md>
  awk 'NR == 1 { if ($0 != "---") exit; next } $0 == "---" { exit }
    /^version:/ { v = $0; sub(/^version:[ \t]*/, "", v); gsub(/["\047 \t\r]/, "", v); print v; exit }' "$1"
}

# The installed profile's version, or unknown when its folder cannot be found.
hello_profile_version() { # <top> <name>
  local pro d
  pro="${SOLIDVIBES_PRO_ROOT:-$(dirname "$SOLIDVIBES_ROOT")/solid-vibes-pro}"
  if [ "$2" = blank ]; then
    d="$SOLIDVIBES_ROOT/setup/profiles/blank"
  else
    for d in "$pro/skills/$2" "$1/.agents/skills/$2" "$HOME/.agents/skills/$2" ""; do
      [ -n "$d" ] && [ -f "$d/SKILL.md" ] && break
    done
  fi
  if [ -n "$d" ] && [ -f "$d/SKILL.md" ]; then hello_fm_version "$d/SKILL.md"; else echo unknown; fi
}

hello_lines() { # <top>
  local top="$1" sv="$top/.solidvibes" m now n v_sv v_pn v_pv i_sv i_pv verdict hash
  now="$(date +%s)"

  if [ -f "$sv/handover.md" ]; then
    echo "handover: present, $(hello_age $((now - $(hello_mtime "$sv/handover.md")))) old"
  else
    echo "handover: none"
  fi

  m="$sv/manifest.json"
  if [ -f "$m" ]; then
    v_sv="$(hello_manifest_str "$m" sv)"
    v_pn="$(hello_manifest_profile "$m" name)"
    v_pv="$(hello_manifest_profile "$m" version)"
    i_sv="$(sed -n 's/^[[:space:]]*"version":[[:space:]]*"\([^"]*\)".*/\1/p' "$SOLIDVIBES_ROOT/.claude-plugin/plugin.json" | head -n 1)"
    i_pv="$(hello_profile_version "$top" "$v_pn")"
    verdict=same
    [ "$v_sv" = "$i_sv" ] || verdict=differs
    [ "$i_pv" = unknown ] || [ "$v_pv" = "$i_pv" ] || verdict=differs
    echo "setup: $verdict (project: sv $v_sv, $v_pn $v_pv; installed: sv $i_sv, $v_pn $i_pv)"
  else
    echo "setup: none (no .solidvibes/manifest.json)"
  fi

  n=0
  if [ -d "$top/.github/workflows" ]; then
    n="$(find "$top/.github/workflows" -maxdepth 1 -type f \( -name '*.yml' -o -name '*.yaml' \) | wc -l | tr -d ' ')"
  fi
  if [ "$n" -gt 0 ]; then echo "ci: present ($n workflow file(s))"; else echo "ci: none"; fi

  hash="$(hello_docs_hash "$top")"
  if [ ! -f "$sv/hello.state" ]; then echo "docs: unchecked"
  elif [ "$(cat "$sv/hello.state")" = "$hash" ]; then echo "docs: same"
  else echo "docs: changed"
  fi
}

hello_hook() { # <top>
  local top="$1" input="" source=""
  [ -f "$top/.solidvibes/manifest.json" ] || return 0
  # shellcheck source=/dev/null
  source "$SOLIDVIBES_ROOT/lib/cli-statusline.sh" && statusline_refresh
  [ -t 0 ] || input="$(cat)"
  source="$(printf '%s' "$input" | tr -d '\n' | sed -n 's/.*"source"[[:space:]]*:[[:space:]]*"\([a-z]*\)".*/\1/p')"
  if [ -f "$top/.solidvibes/handover.md" ]; then
    echo "Handover (.solidvibes/handover.md):"
    echo
    cat "$top/.solidvibes/handover.md"
    echo
  fi
  echo "Solid Vibes status:"
  hello_lines "$top"
  if [ "$source" = startup ]; then echo "Say hello for the full check."; fi
}

cli_hello() {
  local full=false checked=false hook=false dir="" top
  while [ $# -gt 0 ]; do
    case "$1" in
      --full) full=true ;;
      --checked) checked=true ;;
      --hook) hook=true ;;
      -*) echo "error: unknown option: $1" >&2; return 1 ;;
      *) [ -z "$dir" ] || { echo "error: one project folder only" >&2; return 1; }; dir="$1" ;;
    esac
    shift
  done
  dir="${dir:-.}"

  if [ "$hook" = true ]; then
    top="$(git -C "$dir" rev-parse --show-toplevel 2>/dev/null)" || top="$dir"
    hello_hook "$top" || true
    return 0
  fi

  [ -d "$dir" ] || { echo "error: not a directory: $dir" >&2; return 1; }
  top="$(git -C "$dir" rev-parse --show-toplevel 2>/dev/null)" || {
    echo "error: not inside a git repo: $dir" >&2
    return 1
  }

  if [ "$checked" = true ]; then
    mkdir -p "$top/.solidvibes"
    hello_docs_hash "$top" > "$top/.solidvibes/hello.state"
  fi
  hello_lines "$top"

  if [ "$full" = true ]; then
    echo
    "$SOLIDVIBES_ROOT/bin/solidvibes" doctor "$top" || true
    echo
    "$SOLIDVIBES_ROOT/bin/solidvibes" worktrees "$top" || true
  fi
}
