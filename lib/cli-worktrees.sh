# solidvibes worktrees [--clean] [path]
#   Every git worktree in one table; --clean removes the finished ones.
#
#   no path    the current repo, or every repo under $SOLIDVIBES_PROJECTS_DIR when set
#   <path>     that repo if <path> is inside one, else its child repos
#
# A worktree is removed only when all of these hold. When in doubt, it stays.
#   1. Not the main checkout, and not the worktree you are standing in.
#   2. No changes, and no ignored files beyond build output
#      (build, .dart_tool, node_modules, Pods, .gradle, .cxx) and the local
#      .solidvibes/handover.md and .solidvibes/hello.state.
#   3. No live owner: a git lock whose pid runs, a nono session or a pid file
#      (.claude/worktrees/<name>.pid). A lock with no pid at all also counts as owned.
#   4. Idle for 24h (the worktree's index and logs/HEAD untouched).
#   5. Done, by one of:
#      - its HEAD is already in the default branch (origin/HEAD, else the main checkout's HEAD);
#      - a same-repo PR for its branch at this exact HEAD is MERGED or CLOSED and none is OPEN;
#      - its lock's pid is dead and HEAD is on origin.
# Removal is `git worktree remove` without --force. Branches are never deleted.

WT_IDLE_SECS=$((24 * 3600))
WT_BUILD_DIRS=" build .dart_tool node_modules Pods .gradle .cxx "
WT_ROWS=""
WT_TOTAL_KB=0
WT_REMOVABLE_KB=0
WT_FREED_KB=0
WT_REMOVED=0

wt_human() { # KiB → 1.2G
  awk -v k="$1" 'BEGIN { split("K M G T", u); i = 1
    while (k >= 1024 && i < 4) { k /= 1024; i++ }
    fmt = (i == 1) ? "%d%s" : "%.1f%s"; printf fmt, k, u[i] }'
}

wt_human_age() {
  if [ "$1" -ge 86400 ]; then echo "$(($1 / 86400))d"; else echo "$(($1 / 3600))h"; fi
}

wt_size_kb() { # du still prints a total when a file vanishes mid-walk
  local kb
  kb="$(du -sk "$1" 2>/dev/null | cut -f1)" || true
  echo "${kb:-0}"
}

wt_real_path() { (cd "$1" 2>/dev/null && pwd -P) || echo "$1"; }

wt_mtime() { stat -f %m "$1" 2>/dev/null || stat -c %Y "$1"; }

# Seconds since the newest of the worktree's index and logs/HEAD. 0 if neither exists.
wt_idle_secs() {
  local gitdir newest=0 f m
  gitdir="$(git -C "$1" rev-parse --absolute-git-dir)"
  for f in "$gitdir/index" "$gitdir/logs/HEAD"; do
    [ -e "$f" ] || continue
    m="$(wt_mtime "$f")"
    if [ "$m" -gt "$newest" ]; then newest="$m"; fi
  done
  if [ "$newest" -eq 0 ]; then echo 0; else echo $((WT_NOW - newest)); fi
}

# Ignored paths with no build-dir segment (.env, notes, keys…), less the two local Solid Vibes files.
wt_extra_ignored() {
  local n=0 path seg build out
  local -a segs
  out="$(git --no-optional-locks -C "$1" status --porcelain --untracked-files=normal --ignored=matching)" || return 1
  while IFS= read -r path; do
    case "${path#!! }" in .solidvibes/handover.md|.solidvibes/hello.state) continue ;; esac
    build=false
    IFS=/ read -ra segs <<< "${path#!! }"
    for seg in "${segs[@]}"; do
      case "$WT_BUILD_DIRS" in *" $seg "*) build=true ;; esac
    done
    $build || n=$((n + 1))
  done < <(printf '%s\n' "$out" | grep '^!!' || true)
  echo "$n"
}

# live | stale | locked | -
wt_lock_state() {
  local locked="$1" reason="$2" name="$3" repo="$4" pid pidfile
  if [ -n "$WT_NONO_PS" ] && printf '%s\n' "$WT_NONO_PS" | grep -qF "\"sv-$name\""; then echo live; return; fi
  pidfile="$repo/.claude/worktrees/$name.pid"
  if [ -f "$pidfile" ] && ps -p "$(cat "$pidfile")" >/dev/null 2>&1; then echo live; return; fi
  if [ -z "$locked" ]; then echo -; return; fi
  pid="$(printf '%s' "$reason" | sed -n 's/.*pid \([0-9][0-9]*\).*/\1/p')"
  if [ -z "$pid" ]; then echo locked
  elif ps -p "$pid" >/dev/null 2>&1; then echo live
  else echo stale
  fi
}

# OPEN | MERGED | CLOSED | - | ?   for same-repo PRs at exactly this branch and HEAD
wt_pr_state() {
  local prs="$1" branch="$2" head="$3" states
  if [ "$prs" = "?" ]; then echo "?"; return; fi
  states="$(printf '%s\n' "$prs" | awk -v b="$branch" -v h="$head" '$1 == b && $2 == h { print $3 }')"
  case "$states" in
    *OPEN*) echo OPEN ;;
    *MERGED*) echo MERGED ;;
    *CLOSED*) echo CLOSED ;;
    *) echo - ;;
  esac
}

wt_on_origin() {
  [ -n "$(git -C "$1" branch -r --list 'origin/*' --contains "$2" 2>/dev/null)" ]
}

wt_sweep() {
  local repo repo_name prs="?" line i=-1 j base
  local -a W H B L R P
  while IFS= read -r line; do
    case "$line" in
      "worktree "*) i=$((i + 1)); W[i]="${line#worktree }"; H[i]=""; B[i]=""; L[i]=""; R[i]=""; P[i]="" ;;
      "HEAD "*) H[i]="${line#HEAD }" ;;
      "branch "*) B[i]="${line#branch refs/heads/}" ;;
      locked*) L[i]=1; R[i]="${line#locked}" ;;
      prunable*) P[i]=1 ;;
    esac
  done < <(git -C "$1" worktree list --porcelain)

  repo="${W[0]}"  # git lists the main checkout first
  repo_name="$(basename "$repo")"
  [ "$i" -ge 1 ] || return 0

  base="$(git -C "$repo" rev-parse -q --verify refs/remotes/origin/HEAD 2>/dev/null || echo "${H[0]}")"

  if [ -n "$(git -C "$repo" remote)" ] && command -v gh >/dev/null 2>&1; then
    prs="$(cd "$repo" && gh pr list --state all --limit 200 \
      --json headRefName,headRefOid,state,isCrossRepository \
      --jq '.[] | select(.isCrossRepository | not) | "\(.headRefName) \(.headRefOid) \(.state)"' \
      2>/dev/null)" || prs="?"
  fi

  local wt name rel branch head idle dirty extra lock pr verdict kb label
  for ((j = 1; j <= i; j++)); do
    wt="${W[j]}"; branch="${B[j]}"; head="${H[j]}"
    name="$(basename "$wt")"
    rel="${wt#"$repo"/}"
    label="${branch:-(detached ${head:0:7})}"

    if [ -n "${P[j]}" ]; then
      WT_ROWS+="$repo_name	$rel	$label	-	-	-	-	-	-	gone: pruned on --clean"$'\n'
      continue
    fi

    idle="$(wt_idle_secs "$wt")"  # before status, which may refresh the index
    dirty="$(git --no-optional-locks -C "$wt" status --porcelain --untracked-files=normal | wc -l | tr -d ' ')"
    extra="$(wt_extra_ignored "$wt")"
    lock="$(wt_lock_state "${L[j]}" "${R[j]}" "$name" "$repo")"
    pr=-
    if [ -n "$branch" ]; then pr="$(wt_pr_state "$prs" "$branch" "$head")"; fi

    verdict=remove
    case "$WT_HERE/" in "$(wt_real_path "$wt")/"*) verdict="keep: you are in it" ;; esac
    if [ "$verdict" != remove ]; then :
    elif [ "$dirty" -gt 0 ]; then verdict="keep: changes"
    elif [ "$extra" -gt 0 ]; then verdict="keep: ignored files"
    elif [ "$lock" = live ]; then verdict="keep: in use"
    elif [ "$lock" = locked ]; then verdict="keep: locked"
    elif [ "$idle" -lt "$WT_IDLE_SECS" ]; then verdict="keep: active"
    elif git -C "$repo" merge-base --is-ancestor "$head" "$base" 2>/dev/null; then :
    elif [ "$pr" = MERGED ] || [ "$pr" = CLOSED ]; then :
    elif [ "$lock" = stale ] && wt_on_origin "$repo" "$head"; then :
    else verdict="keep: not done"
    fi

    if [ "$WT_CLEAN" = true ]; then
      [ "$verdict" = remove ] || continue
      kb="$(wt_size_kb "$wt")"
      if [ "$lock" = stale ]; then git -C "$repo" worktree unlock "$wt"; fi
      if git -C "$repo" worktree remove "$wt"; then
        echo "removed $repo_name/$rel  $(wt_human "$kb")"
        WT_FREED_KB=$((WT_FREED_KB + kb)); WT_REMOVED=$((WT_REMOVED + 1))
      else
        echo "failed  $repo_name/$rel" >&2
      fi
    else
      kb="$(wt_size_kb "$wt")"
      WT_TOTAL_KB=$((WT_TOTAL_KB + kb))
      if [ "$verdict" = remove ]; then WT_REMOVABLE_KB=$((WT_REMOVABLE_KB + kb)); fi
      WT_ROWS+="$repo_name	$rel	$label	$pr	$dirty	$extra	$lock	$(wt_human_age "$idle")	$(wt_human "$kb")	$verdict"$'\n'
    fi
  done

  if [ "$WT_CLEAN" = true ]; then git -C "$repo" worktree prune; fi
}

cli_worktrees() {
  local root d
  WT_CLEAN=false
  if [ "${1:-}" = "--clean" ]; then
    WT_CLEAN=true
    shift
  fi
  root="${1:-${SOLIDVIBES_PROJECTS_DIR:-}}"
  if [ -z "$root" ]; then
    root="$(git rev-parse --show-toplevel 2>/dev/null)" || {
      echo "error: not inside a git repo; pass a path or set SOLIDVIBES_PROJECTS_DIR" >&2
      return 1
    }
  fi
  [ -d "$root" ] || { echo "error: not a directory: $root" >&2; return 1; }

  WT_NOW="$(date +%s)"
  WT_HERE="$(pwd -P)"
  WT_NONO_PS=""
  if command -v nono >/dev/null 2>&1; then
    WT_NONO_PS="$(nono ps --json 2>/dev/null || true)"  # plain `nono ps` truncates names
  fi

  if git -C "$root" rev-parse --git-dir >/dev/null 2>&1; then
    wt_sweep "$root"
  else
    for d in "$root"/*/; do
      if [ -d "$d.git" ]; then wt_sweep "${d%/}"; fi
    done
  fi

  if [ "$WT_CLEAN" = true ]; then
    if [ "$WT_REMOVED" -eq 0 ]; then
      echo "worktrees: nothing to clean"
    else
      echo "worktrees: freed $(wt_human "$WT_FREED_KB") from $WT_REMOVED worktree(s)"
    fi
  elif [ -z "$WT_ROWS" ]; then
    echo "no worktrees besides main checkouts"
  else
    { printf 'REPO\tWORKTREE\tBRANCH\tPR\tDIRTY\tIGNORED\tLOCK\tIDLE\tSIZE\tVERDICT\n'; printf '%s' "$WT_ROWS"; } \
      | column -t -s $'\t'
    echo
    echo "total $(wt_human "$WT_TOTAL_KB"), removable $(wt_human "$WT_REMOVABLE_KB") — solidvibes worktrees --clean removes the rows marked remove"
  fi
}
