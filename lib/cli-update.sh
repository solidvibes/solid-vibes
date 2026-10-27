# solidvibes update [dir]
#   One line each, read-only and offline, for the project at dir's git toplevel (default: the current
#   one). Only what `hello --full` doesn't print; the update skill fetches first.
#     branch      current branch; vs its upstream: N ahead, M behind <upstream>, or no upstream
#     default     origin/HEAD, else origin/main, origin/master, main, master; this branch N ahead,
#                 M behind it
#     changes     clean, or N uncommitted file(s)
#     unreleased  bullets under ## Unreleased in the changelog the contract's docs names
#                 (changelog: `<path>`), else CHANGELOG.md; or no changelog
#     branches    N local
#   Then one line per project folder, sorted; none found means no line. Folders are searched to
#   depth 3, skipping build, node_modules and dot folders. A path is relative to the toplevel.
#     flutter     <dir> (flutter|dart[, workspace member|workspace root][, pinned <ver>]) per
#                 pubspec.yaml; the pin is .fvmrc "flutter" or .fvm/fvm_config.json
#                 "flutterSdkVersion", in that folder or the nearest one above it
#     node        <dir> (npm|pnpm|yarn|none[, astro]) per package.json; the lock file beside it
#     supabase    <dir>[ (imports <path>)] per supabase/config.toml; deno.json beside it or in functions/

up_git() { git --no-optional-locks -C "$UP_TOP" "$@"; }

up_ahead_behind() { # <ref> → N ahead, M behind
  up_git rev-list --left-right --count "HEAD...$1" | awk '{ printf "%s ahead, %s behind", $1, $2 }'
}

# Folders holding a file named <name>, relative to the toplevel (. for the toplevel itself), sorted.
up_find() { # <name>
  (cd "$UP_TOP" && find . -maxdepth 3 \
    \( -type d \( -name '.?*' -o -name build -o -name node_modules \) -prune \) \
    -o -type f -name "$1" -print) | sed -e 's|/[^/]*$||' -e 's|^\./||' | LC_ALL=C sort
}

up_json_str() { # <file> <key>
  tr -d '\n' < "$1" | sed -n "s/.*\"$2\"[[:space:]]*:[[:space:]]*\"\\([^\"]*\\)\".*/\\1/p"
}

up_fvm_pin() { # <dir>
  local d="$UP_TOP/$1" v=""
  [ "$1" = . ] && d="$UP_TOP"
  while :; do
    if [ -f "$d/.fvmrc" ]; then v="$(up_json_str "$d/.fvmrc" flutter)"
    elif [ -f "$d/.fvm/fvm_config.json" ]; then v="$(up_json_str "$d/.fvm/fvm_config.json" flutterSdkVersion)"
    fi
    if [ -n "$v" ] || [ "$d" = "$UP_TOP" ]; then break; fi
    d="$(dirname "$d")"
  done
  printf '%s' "$v"
}

up_repo_lines() {
  local name up ref b n f docs has_head=true
  up_git rev-parse -q --verify HEAD >/dev/null || has_head=false
  name="$(up_git symbolic-ref -q --short HEAD)" || name=""

  if [ "$has_head" = false ]; then
    echo "branch: ${name:-unknown}, no commits"
  elif [ -z "$name" ]; then
    echo "branch: detached at $(up_git rev-parse --short HEAD)"
  else
    up="$(up_git rev-parse -q --abbrev-ref --symbolic-full-name '@{upstream}' 2>/dev/null)" || up=""
    if [ -n "$up" ]; then echo "branch: $name, $(up_ahead_behind "$up") $up"
    else echo "branch: $name, no upstream"
    fi
  fi

  ref="$(up_git symbolic-ref -q --short refs/remotes/origin/HEAD)" || ref=""
  if [ -z "$ref" ]; then
    for b in remotes/origin/main remotes/origin/master heads/main heads/master; do
      if up_git show-ref -q --verify "refs/$b"; then ref="${b#*s/}"; break; fi
    done
  fi
  if [ -z "$ref" ]; then echo "default: none found"
  elif [ "$has_head" = true ]; then echo "default: $ref, this branch $(up_ahead_behind "$ref")"
  else echo "default: $ref"
  fi

  n="$(up_git status --porcelain --untracked-files=normal | wc -l | tr -d ' ')"
  if [ "$n" -eq 0 ]; then echo "changes: clean"; else echo "changes: $n uncommitted file(s)"; fi

  f=""
  docs="$(contract_field "$UP_TOP" docs 2>/dev/null)" || docs=""
  case "$docs" in
    *'changelog: `'*) f="${docs#*changelog: \`}"; f="${f%%\`*}" ;;
  esac
  f="${f:-CHANGELOG.md}"
  if [ -f "$UP_TOP/$f" ]; then
    n="$(awk '/^## / { u = ($0 ~ /^## \[?Unreleased\]?[ \t]*$/); next } u && /^[-*] / { n++ } END { print n + 0 }' "$UP_TOP/$f")"
    echo "unreleased: $n in $f"
  else
    echo "unreleased: no changelog"
  fi

  echo "branches: $(up_git for-each-ref refs/heads | wc -l | tr -d ' ') local"
}

up_project_lines() {
  local d p info pin
  while IFS= read -r d; do
    [ -n "$d" ] || continue
    p="$UP_TOP/$d/pubspec.yaml"
    if grep -q 'sdk:[[:space:]]*flutter' "$p"; then info=flutter; else info=dart; fi
    if grep -q '^resolution:[[:space:]]*workspace' "$p"; then info="$info, workspace member"
    elif grep -q '^workspace:' "$p"; then info="$info, workspace root"
    fi
    pin="$(up_fvm_pin "$d")"
    if [ -n "$pin" ]; then info="$info, pinned $pin"; fi
    echo "flutter: $d ($info)"
  done <<< "$(up_find pubspec.yaml)"

  while IFS= read -r d; do
    [ -n "$d" ] || continue
    p="$UP_TOP/$d"
    if [ -f "$p/package-lock.json" ]; then info=npm
    elif [ -f "$p/pnpm-lock.yaml" ]; then info=pnpm
    elif [ -f "$p/yarn.lock" ]; then info=yarn
    else info=none
    fi
    if grep -q '"astro"[[:space:]]*:' "$p/package.json"; then info="$info, astro"; fi
    echo "node: $d ($info)"
  done <<< "$(up_find package.json)"

  while IFS= read -r d; do
    case "$d" in supabase|*/supabase) ;; *) continue ;; esac
    if [ -f "$UP_TOP/$d/deno.json" ]; then echo "supabase: $d (imports $d/deno.json)"
    elif [ -f "$UP_TOP/$d/functions/deno.json" ]; then echo "supabase: $d (imports $d/functions/deno.json)"
    else echo "supabase: $d"
    fi
  done <<< "$(up_find config.toml)"
}

cli_update() {
  local dir=""
  while [ $# -gt 0 ]; do
    case "$1" in
      -*) echo "error: unknown option: $1" >&2; return 1 ;;
      *) [ -z "$dir" ] || { echo "error: one project folder only" >&2; return 1; }; dir="$1" ;;
    esac
    shift
  done
  dir="${dir:-.}"

  [ -d "$dir" ] || { echo "error: not a directory: $dir" >&2; return 1; }
  UP_TOP="$(git -C "$dir" rev-parse --show-toplevel 2>/dev/null)" || {
    echo "error: not inside a git repo: $dir" >&2
    return 1
  }
  # shellcheck source=lib/contract.sh
  source "$SOLIDVIBES_ROOT/lib/contract.sh"

  up_repo_lines
  up_project_lines
}
