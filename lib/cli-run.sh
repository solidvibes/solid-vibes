# solidvibes run <plan-file | "task"> [--agent claude|codex|"<cmd>"] [--dry-run] [--no-sandbox]
#   Starts one headless agent run in its own worktree, in the background.
#
#   <plan-file>  a plan committed on the base branch → the `go` skill's headless mode
#   "task"       one sentence → the `brief` skill's headless mode
#
#   --agent claude  `claude -p` (default) · codex  `codex exec` · "<cmd>" any command:
#                   the prompt arrives on stdin, and `{prompt_file}` in <cmd> becomes its path
#   --dry-run       print what would run and change nothing
#   --no-sandbox    run without nono: the agent gets every permission you have (not recommended)
#
# Base: origin/HEAD when the repo has an `origin` remote, else the local default branch
# (main, else master, else the main checkout's branch). Without a remote the run commits
# on its branch and skips the push and the pull request.
# Worktree <repo>/.claude/worktrees/<slug> on branch auto/<slug>; log <slug>.log beside it,
# named in the prompt's LOG_FILE: line.
# Sandboxed runs are nono sessions named sv-<slug>; stop one with `solidvibes stop <slug>`.

# shellcheck source=/dev/null
source "$SOLIDVIBES_ROOT/lib/contract.sh"

run_die() { echo "error: $*" >&2; exit 1; }

# The main checkout, also when called from inside a worktree.
run_repo_root() {
  local line
  line="$(git worktree list --porcelain 2>/dev/null | head -1)" || return 1
  [ -n "$line" ] || return 1
  printf '%s\n' "${line#worktree }"
}

run_local_default() {
  local b
  for b in main master; do
    if git -C "$1" show-ref -q --verify "refs/heads/$b"; then echo "$b"; return; fi
  done
  git -C "$1" symbolic-ref -q --short HEAD
}

run_quote() {
  local a out=""
  for a in "$@"; do out="$out $(printf '%q' "$a")"; done
  printf '%s\n' "${out# }"
}

# Adds `--read <dir>` for the program's folder and, when it is a link, the folder above its
# target (an install like <dir>/versions/<v>). Never the home folder or the root.
run_program_grants() {
  local bin real dir
  bin="$(command -v "$1" 2>/dev/null)" || return 0
  case "$bin" in /*) ;; *) return 0 ;; esac
  dir="$(cd "$(dirname "$bin")" && pwd -P)"
  run_grant_dir "$dir"
  [ -L "$bin" ] || return 0
  real="$(readlink -f "$bin" 2>/dev/null || realpath "$bin" 2>/dev/null)" || return 0
  run_grant_dir "$(dirname "$(dirname "$real")")"
}

# True for a folder too broad to grant: the root, the home folder or a folder above it,
# and for writes also ~/.claude, ~/.codex or ~/.agents (an agent's own settings and hooks).
run_too_broad() { # <dir> [write]
  local dir home
  dir="$(cd "$1" 2>/dev/null && pwd -P || printf '%s' "$1")"
  home="$(cd "$HOME" 2>/dev/null && pwd -P || printf '%s' "$HOME")"
  case "$dir" in /|"$home") return 0 ;; esac
  case "$home/" in "$dir"/*) return 0 ;; esac
  if [ "${2:-}" = write ]; then
    case "$dir/" in "$home"/.claude/*|"$home"/.codex/*|"$home"/.agents/*) return 0 ;; esac
  fi
  return 1
}

run_grant_dir() {
  run_too_broad "$1" || RUN_GRANTS+=(--read "$1")
}

run_grant_if() { # <flag> <path>: only paths that exist
  if [ -e "$2" ]; then RUN_GRANTS+=("$1" "$2"); fi
}

cli_run() {
  local agent=claude dry=false sandbox=true arg=""
  while [ $# -gt 0 ]; do
    case "$1" in
      --agent) [ $# -ge 2 ] || run_die "--agent needs a value"; agent="$2"; shift 2 ;;
      --dry-run) dry=true; shift ;;
      --no-sandbox) sandbox=false; shift ;;
      -*) run_die "unknown option: $1" ;;
      *) [ -z "$arg" ] || run_die "one plan file or one task, in quotes"; arg="$1"; shift ;;
    esac
  done
  [ -n "$arg" ] || run_die "usage: solidvibes run <plan-file | \"task\"> [--agent claude|codex|\"<cmd>\"] [--dry-run] [--no-sandbox]"

  local repo
  repo="$(run_repo_root)" || run_die "run this inside a git repo"

  local mode slug skill input plan_rel=""
  if [ -f "$arg" ]; then
    mode=plan
    local plan_abs
    plan_abs="$(cd "$(dirname "$arg")" && pwd -P)/$(basename "$arg")"
    case "$plan_abs" in
      "$repo"/*) plan_rel="${plan_abs#"$repo"/}" ;;
      *) run_die "the plan must live inside the repo ($repo)" ;;
    esac
    slug="$(basename "$plan_abs" .md)"
    skill=go
  elif [[ "$arg" == */* ]] || [[ "$arg" == *.md ]]; then
    run_die "'$arg' looks like a path but doesn't exist"
  else
    mode=task
    local words
    words="$(printf '%s' "$arg" | tr '[:upper:] ' '[:lower:]-' | tr -cd 'a-z0-9-' | cut -c1-30 | sed 's/-*$//')"
    slug="$(date +%Y%m%d-%H%M%S)-${words:-task}"
    skill=brief
  fi
  local skill_file="$SOLIDVIBES_ROOT/skills/$skill/SKILL.md"
  [ -f "$skill_file" ] || run_die "skill not found: $skill_file"

  local branch="auto/$slug" session="sv-$slug"
  local wt_dir="$repo/.claude/worktrees"
  local worktree="$wt_dir/$slug" log="$wt_dir/$slug.log" prompt_file="$wt_dir/$slug.prompt.md" pid_file="$wt_dir/$slug.pid"

  local has_remote=false base
  if git -C "$repo" remote get-url origin >/dev/null 2>&1; then
    has_remote=true
    $dry || git -C "$repo" fetch origin --quiet 2>/dev/null || true
    base="$(git -C "$repo" symbolic-ref -q --short refs/remotes/origin/HEAD)" || \
      run_die "origin/HEAD is not set; fix it once with: git -C \"$repo\" remote set-head origin --auto"
  else
    base="$(run_local_default "$repo")" || run_die "no default branch found"
  fi

  if git -C "$repo" show-ref -q --verify "refs/heads/$branch" \
    || git -C "$repo" show-ref -q --verify "refs/remotes/origin/$branch"; then
    run_die "branch $branch already exists; if a run is going, stop it with: solidvibes stop $slug"
  fi
  [ ! -e "$worktree" ] || run_die "$worktree already exists"

  if [ "$mode" = plan ]; then
    git -C "$repo" cat-file -e "$base:$plan_rel" 2>/dev/null || \
      run_die "$plan_rel is not committed on $base; commit it first"
    input="PLAN_FILE: $worktree/$plan_rel"
  else
    input="TASK: $arg"
  fi

  # The contract on the base branch: what the run will see.
  local ctmp kind path
  ctmp="$(mktemp -d)"
  git -C "$repo" show "$base:AGENTS.md" > "$ctmp/AGENTS.md" 2>/dev/null || true
  if ! contract_file "$ctmp" >/dev/null; then
    rm -rf "$ctmp"
    run_die "no ## Factory section in AGENTS.md on $base; set the project up with: solidvibes init"
  fi
  RUN_GRANTS=()
  while read -r kind path; do
    case "$kind" in
      read|write)
        if run_too_broad "$path" "$kind"; then
          echo "warning: sandbox $kind path skipped, too broad to grant: $path" >&2
          continue
        fi ;;
    esac
    case "$kind" in
      read) RUN_GRANTS+=(--read "$path") ;;
      write) RUN_GRANTS+=(--allow "$path") ;;
    esac
  done < <(contract_sandbox "$ctmp")
  rm -rf "$ctmp"

  local -a cmd
  local program
  case "$agent" in
    claude)
      program=claude
      cmd=(claude -p --dangerously-skip-permissions --output-format text)
      run_grant_if --read "$HOME/.claude"
      ;;
    codex)
      program=codex
      cmd=(codex exec --sandbox danger-full-access --ephemeral -)
      run_grant_if --read "${CODEX_HOME:-$HOME/.codex}"
      ;;
    *)
      program="${agent%% *}"
      cmd=(bash -c "${agent//\{prompt_file\}/$(printf '%q' "$prompt_file")}")
      ;;
  esac
  local program_bin=""
  if [ "$agent" = claude ] || [ "$agent" = codex ]; then
    program_bin="$(command -v "$program" 2>/dev/null)" || {
      $dry || run_die "$program not found on PATH"
      program_bin="$program"
    }
    cmd[0]="$program_bin"
  fi

  if $sandbox && ! command -v nono >/dev/null 2>&1; then
    run_die "nono is not installed, and runs are sandboxed with it (https://nono.sh). Install it, or pass --no-sandbox to run without one (not recommended)."
  fi

  local git_dir
  git_dir="$(cd "$repo" && cd "$(git rev-parse --git-common-dir)" && pwd -P)"
  run_program_grants "$program"
  RUN_GRANTS+=(--read "$repo" --read "$SOLIDVIBES_ROOT" --allow "$worktree" --allow "$git_dir" --allow-file "$log")
  run_grant_if --read "$HOME/.agents/skills"
  run_grant_if --read-file "$HOME/.gitconfig"
  run_grant_if --read "$HOME/.config/gh"
  run_grant_if --read "$HOME/.config/git"
  run_grant_if --allow /tmp

  # The agent reads the prompt on stdin and writes the log itself: a detached nono session
  # wires the child's stdio to its own terminal, which never sends end-of-input.
  # Unsandboxed, the launcher stays the parent (no exec): its command line names the prompt
  # file, which is how `solidvibes stop` knows a recorded process id is still this run.
  local launcher='p="$1"; l="$2"; shift 2; exec "$@" < "$p" >> "$l" 2>&1'
  local -a full
  if $sandbox; then
    full=(nono run --silent --detached --name "$session" --profile "$SOLIDVIBES_ROOT/profiles/solidvibes.json"
      "${RUN_GRANTS[@]}" -- bash -c "$launcher" launcher "$prompt_file" "$log" "${cmd[@]}")
  else
    full=(bash -c 'p="$1"; l="$2"; shift 2; "$@" < "$p" >> "$l" 2>&1' launcher "$prompt_file" "$log" "${cmd[@]}")
    echo "warning: no sandbox. The agent runs with every permission you have and approves its own actions, on your whole machine." >&2
  fi

  if $dry; then
    echo "dry run: nothing was changed"
    echo "  mode:     $mode ($skill skill, headless mode)"
    echo "  base:     $base"
    echo "  branch:   $branch"
    echo "  worktree: $worktree"
    echo "  log:      $log"
    echo "  prompt:   $prompt_file = $skill_file + \"Run this skill's Headless mode.\" + \"$input\" + \"LOG_FILE: $log\""
    if $has_remote; then
      echo "  remote:   origin; the run pushes $branch and opens a draft pull request"
    else
      echo "  remote:   none; the run commits on $branch and skips the push and the pull request"
    fi
    if $sandbox; then echo "  sandbox:  nono session $session"; else echo "  sandbox:  none (--no-sandbox)"; fi
    echo "would run:"
    echo "  git -C $(printf '%q' "$repo") worktree add -b $branch $(printf '%q' "$worktree") $base"
    echo "  cd $(printf '%q' "$worktree") && $(run_quote "${full[@]}")"
    return 0
  fi

  local exclude="$git_dir/info/exclude"
  mkdir -p "$git_dir/info"
  grep -qxF ".claude/worktrees/" "$exclude" 2>/dev/null || echo ".claude/worktrees/" >> "$exclude"
  mkdir -p "$wt_dir"
  git -C "$repo" worktree add -q -b "$branch" "$worktree" "$base"
  printf '%s\n\nRun this skill'"'"'s Headless mode.\n\n%s\nLOG_FILE: %s\n' "$(cat "$skill_file")" "$input" "$log" > "$prompt_file"
  : > "$log"

  cd "$worktree"
  if $sandbox; then
    "${full[@]}"
  else
    nohup "${full[@]}" < /dev/null > /dev/null 2>&1 &
    echo $! > "$pid_file"
  fi

  echo "started ($mode): $slug"
  echo "  worktree: $worktree"
  echo "  branch:   $branch (from $base)"
  echo "  log:      tail -f $log"
  if ! $has_remote; then echo "  no remote: the run commits on $branch and skips the push and the pull request"; fi
  if $sandbox; then echo "  session:  $session (nono ps lists it)"; else echo "  sandbox:  none (--no-sandbox)"; fi
  echo "  stop:     solidvibes stop $slug"
}
