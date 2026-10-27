#!/usr/bin/env bash
# solidvibes run / stop with stub agents and a stub nono: dry runs with and without a remote change
# nothing, a run refuses without nono, and real runs start the stub in a fresh worktree. No real agent runs.
set -euo pipefail

SV="$(cd "$(dirname "$0")/.." && pwd -P)/bin/solidvibes"
T="$(mktemp -d)"
trap 'rm -rf "$T"' EXIT
T="$(cd "$T" && pwd -P)"

fail() { echo "FAIL: $*" >&2; exit 1; }
expect() { printf '%s\n' "$out" | grep -qF -- "$1" || fail "missing [$1] in: $out"; }
refute() { if printf '%s\n' "$out" | grep -qF -- "$1"; then fail "unexpected [$1] in: $out"; fi; }

export GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_NOSYSTEM=1
export GIT_AUTHOR_NAME=test GIT_AUTHOR_EMAIL=test@example.com GIT_COMMITTER_NAME=test GIT_COMMITTER_EMAIL=test@example.com
export HOME="$T/home"
mkdir -p "$HOME/cache"

# Stubs: any call leaves a mark. Only the stub nono and the custom agent are ever started.
STUB="$T/stub"
mkdir -p "$STUB"
for p in claude codex; do
  printf '#!/bin/sh\ntouch "%s/%s-called"\n' "$T" "$p" > "$STUB/$p"
done
printf '#!/bin/sh\nif [ "$1" = run ]; then printf "%%s\\n" "$@" > "%s/nono-args"; fi\n' "$T" > "$STUB/nono"
chmod +x "$STUB"/*
BASE_PATH="/usr/bin:/bin:/usr/sbin:/sbin"
export PATH="$STUB:$BASE_PATH"

R="$T/repo"
git init -q -b main "$R"
cd "$R"
cat > AGENTS.md <<'EOF'
# Demo

## Factory

- **checks** — fast: `true` · full: `true`
- **sandbox**
  - write: `~/cache`
  - read: `$NOT_SET_ANYWHERE/sdk`
  - write: `~`
  - write: `~/cache/..`
EOF
mkdir -p docs/plans
printf '# Tiny plan\n' > docs/plans/2026-01-01-tiny.md
git add -A && git commit -qm init

snap() { (cd "$R" && git for-each-ref; git worktree list; git status --porcelain --ignored; cat "$(git rev-parse --git-common-dir)/info/exclude" 2>/dev/null; find .claude 2>/dev/null) || true; }

# Dry run, no remote: base is the local default branch, push and PR are skipped.
before="$(snap)"
out="$("$SV" run --dry-run docs/plans/2026-01-01-tiny.md 2>&1)" || fail "dry run failed: $out"
[ "$(snap)" = "$before" ] || fail "a dry run changed the repo"
expect "dry run: nothing was changed"
expect "mode:     plan (go skill, headless mode)"
expect "base:     main"
expect "branch:   auto/2026-01-01-tiny"
expect "worktree: $R/.claude/worktrees/2026-01-01-tiny"
expect "PLAN_FILE: $R/.claude/worktrees/2026-01-01-tiny/docs/plans/2026-01-01-tiny.md"
expect "remote:   none; the run commits on auto/2026-01-01-tiny and skips the push and the pull request"
expect "worktree add -b auto/2026-01-01-tiny"
expect "nono run --silent --detached --name sv-2026-01-01-tiny --profile"
expect "profiles/solidvibes.json"
expect "--allow $HOME/cache"
expect "$STUB/claude -p --dangerously-skip-permissions --output-format text"
expect "variable not set"
expect "too broad to grant: $HOME"
refute "--allow $HOME "
refute "NOT_SET_ANYWHERE/sdk --"
[ ! -e "$T/claude-called" ] && [ ! -e "$T/nono-args" ] || fail "a dry run started something"

out="$("$SV" run --dry-run --agent codex "Fix the Greeting, please!" 2>&1)" || fail "task dry run failed: $out"
expect "mode:     task (brief skill, headless mode)"
expect "TASK: Fix the Greeting, please!"
expect "-fix-the-greeting-please"
expect "$STUB/codex exec --sandbox danger-full-access --ephemeral -"
[ ! -e "$T/codex-called" ] || fail "a dry run started codex"

# Refusals: no nono, a missing path, an uncommitted plan, no contract.
out="$(PATH="$BASE_PATH" "$SV" run --dry-run "a task" 2>&1)" && fail "should refuse without nono: $out"
expect "nono is not installed"
expect "--no-sandbox"
out="$(PATH="$BASE_PATH" "$SV" run --dry-run --no-sandbox "a task" 2>&1)" || fail "--no-sandbox should not need nono: $out"
expect "sandbox:  none (--no-sandbox)"
expect "warning: no sandbox"
refute "nono run"
out="$("$SV" run --dry-run docs/plans/missing.md 2>&1)" && fail "a missing plan path should fail"
expect "looks like a path"
printf '# New\n' > docs/plans/new.md
out="$("$SV" run --dry-run docs/plans/new.md 2>&1)" && fail "an uncommitted plan should fail"
expect "is not committed on main"
rm docs/plans/new.md

# With a remote: base is origin/HEAD, the run pushes and opens a PR.
git init -q --bare -b main "$T/origin.git"
git remote add origin "$T/origin.git"
git push -q origin main
git remote set-head origin main
before="$(snap)"
out="$("$SV" run --dry-run docs/plans/2026-01-01-tiny.md 2>&1)" || fail "dry run with remote failed: $out"
[ "$(snap)" = "$before" ] || fail "a dry run with a remote changed the repo"
expect "base:     origin/main"
expect "remote:   origin; the run pushes auto/2026-01-01-tiny and opens a draft pull request"
expect "worktree add -b auto/2026-01-01-tiny"
git remote remove origin

# A sandboxed run hands the stub nono the profile, the session name and the grants.
out="$("$SV" run docs/plans/2026-01-01-tiny.md 2>&1)" || fail "sandboxed run failed: $out"
expect "started (plan): 2026-01-01-tiny"
expect "no remote: the run commits on auto/2026-01-01-tiny"
[ -d "$R/.claude/worktrees/2026-01-01-tiny" ] || fail "no worktree"
[ "$(git -C "$R/.claude/worktrees/2026-01-01-tiny" branch --show-current)" = auto/2026-01-01-tiny ] || fail "wrong branch"
grep -qxF ".claude/worktrees/" "$(git rev-parse --git-common-dir)/info/exclude" || fail "worktrees not excluded"
[ -z "$(git status --porcelain)" ] || fail "the run left the main checkout dirty"
args="$(cat "$T/nono-args")"
for a in --detached sv-2026-01-01-tiny "$R/.claude/worktrees/2026-01-01-tiny" "$HOME/cache" "$STUB/claude"; do
  printf '%s\n' "$args" | grep -qxF -- "$a" || fail "nono missing [$a]: $args"
done
grep -qF "Run this skill's Headless mode." "$R/.claude/worktrees/2026-01-01-tiny.prompt.md" || fail "prompt lacks the mode line"
grep -qxF "LOG_FILE: $R/.claude/worktrees/2026-01-01-tiny.log" "$R/.claude/worktrees/2026-01-01-tiny.prompt.md" || fail "prompt lacks the log path"
out="$("$SV" run docs/plans/2026-01-01-tiny.md 2>&1)" && fail "a second run of one plan should refuse"
expect "already exists"

# An unsandboxed custom agent gets the prompt on stdin; stop ends it.
out="$("$SV" run --no-sandbox --agent 'cat > {prompt_file}.seen; exec sleep 30' "say hello" 2>&1)" || fail "custom run failed: $out"
slug="$(printf '%s\n' "$out" | sed -n 's/^started (task): //p')"
[ -n "$slug" ] || fail "no slug in: $out"
pid="$(cat "$R/.claude/worktrees/$slug.pid")"
for _ in 1 2 3 4 5 6 7 8 9 10; do [ -s "$R/.claude/worktrees/$slug.prompt.md.seen" ] && break; sleep 0.3; done
grep -qxF "TASK: say hello" "$R/.claude/worktrees/$slug.prompt.md.seen" || fail "the agent did not get the prompt"
out="$(cd "$R/.claude/worktrees/$slug" && "$SV" stop "$slug" 2>&1)" || fail "stop failed: $out"
expect "stopping unsandboxed run $slug"
! kill -0 "$pid" 2>/dev/null || fail "the run is still alive"
[ -d "$R/.claude/worktrees/$slug" ] && [ -f "$R/.claude/worktrees/$slug.log" ] || fail "stop removed the worktree or log"
out="$("$SV" stop nothing-here 2>&1)" && fail "stopping an unknown run should fail"

# stop never kills a process that is not the run: a reused process id, a bad id, a path as name.
sleep 30 & other=$!
echo "$other" > "$R/.claude/worktrees/$slug.pid"
out="$("$SV" stop "$slug" 2>&1)" || fail "stop of a finished run failed: $out"
expect "left alone"
kill -0 "$other" 2>/dev/null || fail "stop killed an unrelated process"
{ kill "$other"; wait "$other"; } 2>/dev/null || true
echo "-1" > "$R/.claude/worktrees/$slug.pid"
out="$("$SV" stop "$slug" 2>&1)" && fail "a bad process id should fail"
expect "does not hold a process id"
out="$("$SV" stop "../$slug" 2>&1)" && fail "a path as run name should fail"
expect "not a run name"

# No contract on the base branch.
git rm -q AGENTS.md && git commit -qm "drop contract"
out="$("$SV" run --dry-run "a task" 2>&1)" && fail "should refuse without a contract"
expect "no ## Factory section in AGENTS.md on main"

[ ! -e "$T/claude-called" ] && [ ! -e "$T/codex-called" ] || fail "a real agent stub was started"
cd "$T"
