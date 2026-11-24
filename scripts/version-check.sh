#!/usr/bin/env bash
# Fails when files people install changed since <base> but .claude-plugin/plugin.json's version did not,
# so installs never miss a change. Docs, tests, plans, CI, repo scripts and repo notes don't count.
set -euo pipefail

base="${1:?usage: scripts/version-check.sh <base-commit>}"
version_at() { git show "$1:.claude-plugin/plugin.json" 2>/dev/null | sed -n 's/.*"version": *"\([^"]*\)".*/\1/p'; }
new="$(version_at HEAD)"

if [ -f skills/stack-flutter-supabase/SKILL.md ]; then
  pack="$(sed -n 's/^version: //p' skills/stack-flutter-supabase/SKILL.md)"
  [ "$pack" = "$new" ] || { echo "version-check: skills/stack-flutter-supabase/SKILL.md says $pack, plugin.json says $new; make them match" >&2; exit 1; }
fi

if ! git cat-file -e "$base^{commit}" 2>/dev/null; then
  echo "version-check: no base commit, skipped"
  exit 0
fi

shipped="$(git diff --name-only "$base" HEAD \
  | grep -v -E '^(docs/|tests/|plans/|scripts/|\.github/)|^(README\.md|CHANGELOG\.md|AGENTS\.md|SECURITY\.md|LICENSE|\.gitignore|\.gitleaks\.toml|\.strip-allow)$' || true)"
if [ -z "$shipped" ]; then
  echo "version-check: nothing installed changed"
  exit 0
fi

old="$(version_at "$base")"
if [ "$old" = "$new" ]; then
  echo "version-check: installed files changed but .claude-plugin/plugin.json is still $new; bump it so installs pick them up:" >&2
  printf '%s\n' "$shipped" | sed 's/^/  /' >&2
  exit 1
fi
echo "version-check: $old -> $new"
