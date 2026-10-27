#!/usr/bin/env bash
# solidvibes worktrees --clean removes only a merged, clean, idle worktree; a local handover and
# hello.state do not keep it.
set -euo pipefail

SV="$(cd "$(dirname "$0")/.." && pwd -P)/bin/solidvibes"
T="$(mktemp -d)"
trap 'rm -rf "$T"' EXIT
T="$(cd "$T" && pwd -P)"

fail() { echo "FAIL: $*" >&2; exit 1; }

export GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_NOSYSTEM=1
export GIT_AUTHOR_NAME=test GIT_AUTHOR_EMAIL=test@example.com GIT_COMMITTER_NAME=test GIT_COMMITTER_EMAIL=test@example.com
unset SOLIDVIBES_PROJECTS_DIR

R="$T/repo"
git init -q -b main "$R"
cd "$R"
mkdir .solidvibes && printf 'handover.md\nhello.state\n' > .solidvibes/.gitignore
echo '*.env' > .gitignore
echo one > file && git add file .gitignore .solidvibes && git commit -qm one

git worktree add -q -b merged "$T/wt-merged"
(cd "$T/wt-merged" && echo two >> file && git commit -qam two)
echo "## Snapshot" > "$T/wt-merged/.solidvibes/handover.md"
echo abc > "$T/wt-merged/.solidvibes/hello.state"
git merge -q --ff-only merged

git worktree add -q -b env "$T/wt-env" merged
echo "## Snapshot" > "$T/wt-env/.solidvibes/handover.md"
echo KEY=1 > "$T/wt-env/local.env"

git worktree add -q -b unmerged "$T/wt-unmerged"
(cd "$T/wt-unmerged" && echo three >> file && git commit -qam three)

git worktree add -q -b dirty "$T/wt-dirty"
echo scratch > "$T/wt-dirty/notes.txt"

git worktree add -q -b active "$T/wt-active"

age() { # make every worktree but wt-active look idle for days
  local n
  for n in wt-merged wt-unmerged wt-dirty wt-env; do
    touch -t 202001010000 "$R/.git/worktrees/$n/index" "$R/.git/worktrees/$n/logs/HEAD"
  done
}

age
table="$("$SV" worktrees)"
verdict() { printf '%s\n' "$table" | grep -E "(^|[[:space:]/])$1[[:space:]]" | sed 's/.*  //'; }
[ "$(verdict wt-merged)" = remove ] || fail "wt-merged should be removable: $table"
[ "$(verdict wt-unmerged)" = "keep: not done" ] || fail "wt-unmerged: $table"
[ "$(verdict wt-dirty)" = "keep: changes" ] || fail "wt-dirty: $table"
[ "$(verdict wt-active)" = "keep: active" ] || fail "wt-active: $table"
[ "$(verdict wt-env)" = "keep: ignored files" ] || fail "only the two local files are disposable: $table"

age
out="$("$SV" worktrees --clean)"
printf '%s\n' "$out" | grep -q "removed repo/" || fail "nothing removed: $out"
[ ! -d "$T/wt-merged" ] || fail "wt-merged still exists"
[ -d "$T/wt-unmerged" ] && [ -d "$T/wt-dirty" ] && [ -d "$T/wt-active" ] || fail "a kept worktree was removed"
[ -f "$T/wt-dirty/notes.txt" ] || fail "untracked file lost"
git show-ref -q --verify refs/heads/merged || fail "branches are never deleted"
[ -f "$T/wt-env/local.env" ] || fail "an ignored file was lost"
[ "$(git worktree list | wc -l | tr -d ' ')" = 5 ] || fail "expected main + 4 worktrees"

out="$("$SV" worktrees --clean)"
[ "$out" = "worktrees: nothing to clean" ] || fail "second clean should find nothing: $out"

cd "$T"
"$SV" worktrees >/dev/null 2>&1 && fail "outside a repo with no path should fail"
out="$(SOLIDVIBES_PROJECTS_DIR="$T" "$SV" worktrees)"
printf '%s\n' "$out" | grep -q "wt-unmerged" || fail "SOLIDVIBES_PROJECTS_DIR should find child repos: $out"
echo "cli_worktrees: ok"
