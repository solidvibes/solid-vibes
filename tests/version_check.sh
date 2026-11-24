#!/usr/bin/env bash
# scripts/version-check.sh on a temp repo: installed changes need a version bump; docs-only changes don't;
# the Flutter stack skill's version line must match plugin.json.
set -euo pipefail

REPO="$(cd "$(dirname "$0")/.." && pwd -P)"
T="$(mktemp -d)"
trap 'rm -rf "$T"' EXIT

fail() { echo "FAIL: $*" >&2; exit 1; }

export GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_NOSYSTEM=1
export GIT_AUTHOR_NAME=test GIT_AUTHOR_EMAIL=test@example.com GIT_COMMITTER_NAME=test GIT_COMMITTER_EMAIL=test@example.com

cd "$T"
git init -q
mkdir -p .claude-plugin skills/a docs
echo '{ "name": "x", "version": "1.0.0" }' > .claude-plugin/plugin.json
echo "rule" > skills/a/SKILL.md
git add -A && git commit -qm base
base="$(git rev-parse HEAD)"
check() { bash "$REPO/scripts/version-check.sh" "$1"; }

echo "notes" > docs/x.md
git add -A && git commit -qm docs
check "$base" >/dev/null || fail "a docs-only change should pass"

echo "new rule" >> skills/a/SKILL.md
git add -A && git commit -qm skill
out="$(check "$base" 2>&1)" && fail "a skill change without a bump should fail"
printf '%s\n' "$out" | grep -q "skills/a/SKILL.md" || fail "should list the changed file: $out"

sed -i.bak 's/1.0.0/1.0.1/' .claude-plugin/plugin.json && rm .claude-plugin/plugin.json.bak
git add -A && git commit -qm bump
check "$base" >/dev/null || fail "a skill change with a bump should pass"

check 0000000000000000000000000000000000000000 >/dev/null || fail "a missing base should be skipped"

mkdir -p skills/stack-flutter-supabase
printf -- '---\nversion: 1.0.0\n---\n' > skills/stack-flutter-supabase/SKILL.md
git add -A && git commit -qm stack
check HEAD >/dev/null 2>&1 && fail "a stack version line that differs from plugin.json should fail"
sed -i.bak 's/1.0.0/1.0.1/' skills/stack-flutter-supabase/SKILL.md && rm skills/stack-flutter-supabase/SKILL.md.bak
check HEAD >/dev/null || fail "a matching stack version line should pass"

echo ok
