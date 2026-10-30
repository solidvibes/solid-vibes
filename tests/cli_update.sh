#!/usr/bin/env bash
# solidvibes update: clean and dirty; upstream and default ahead/behind, no upstream, origin/main,
# main and master fallbacks; changelog from the contract's docs and the default, or none; nested
# pubspec (flutter, dart, workspace) with both fvm formats; package.json per lock and astro; supabase
# with deno.json; skipped folders; ecosystem lines omitted when nothing is found; runs with no jq on PATH.
set -euo pipefail

SV="$(cd "$(dirname "$0")/.." && pwd -P)/bin/solidvibes"
T="$(mktemp -d)"
trap 'rm -rf "$T"' EXIT
T="$(cd "$T" && pwd -P)"

fail() { echo "FAIL: $*" >&2; exit 1; }
line() { printf '%s\n' "$out" | grep "^$1: " || fail "no $1 line in: $out"; }
has() { printf '%s\n' "$out" | grep -qxF "$1" || fail "missing [$1] in: $out"; }

export GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_NOSYSTEM=1
export GIT_AUTHOR_NAME=test GIT_AUTHOR_EMAIL=test@example.com GIT_COMMITTER_NAME=test GIT_COMMITTER_EMAIL=test@example.com

commit() { echo "$2" >> "$1/file" && git -C "$1" add file && git -C "$1" commit -qm "$2"; }

git init -q --bare -b main "$T/origin.git"
git clone -q "$T/origin.git" "$T/seed" 2>/dev/null
commit "$T/seed" one
git -C "$T/seed" push -q origin main
git clone -q "$T/origin.git" "$T/repo"
R="$T/repo"

out="$("$SV" update "$R")"
[ "$(line branch)" = "branch: main, 0 ahead, 0 behind origin/main" ] || fail "branch in sync: $out"
[ "$(line default)" = "default: origin/main, this branch 0 ahead, 0 behind" ] || fail "default in sync: $out"
[ "$(line changes)" = "changes: clean" ] || fail "clean: $out"
[ "$(line unreleased)" = "unreleased: no changelog" ] || fail "no changelog: $out"
[ "$(line branches)" = "branches: 1 local" ] || fail "branches: $out"
printf '%s\n' "$out" | grep -qE '^(flutter|node|supabase):' && fail "no ecosystem lines without projects: $out"

commit "$T/seed" two && commit "$T/seed" three && git -C "$T/seed" push -q origin main
git -C "$R" fetch -q
commit "$R" local
git -C "$R" switch -q -c feature
commit "$R" f1 && commit "$R" f2
echo scratch > "$R/notes.txt"
echo more >> "$R/file"
out="$(cd "$R" && "$SV" update)"
[ "$(line branch)" = "branch: feature, no upstream" ] || fail "no upstream: $out"
[ "$(line default)" = "default: origin/main, this branch 3 ahead, 2 behind" ] || fail "default ahead/behind: $out"
[ "$(line changes)" = "changes: 2 uncommitted file(s)" ] || fail "dirty: $out"
[ "$(line branches)" = "branches: 2 local" ] || fail "two branches: $out"
git -C "$R" remote set-head origin -d
out="$("$SV" update "$R")"
[ "$(line default)" = "default: origin/main, this branch 3 ahead, 2 behind" ] || fail "origin/main fallback: $out"
git -C "$R" symbolic-ref refs/remotes/origin/HEAD refs/remotes/origin/main

git -C "$R" switch -q main 2>/dev/null || { git -C "$R" stash -q; git -C "$R" switch -q main; }
out="$("$SV" update "$R")"
[ "$(line branch)" = "branch: main, 1 ahead, 2 behind origin/main" ] || fail "upstream ahead/behind: $out"

cat > "$R/CHANGELOG.md" <<'MD'
# Changelog

## Unreleased
- One.
- Two.
  - A nested note.

## 1.0.0
- Old.
MD
out="$("$SV" update "$R")"
[ "$(line unreleased)" = "unreleased: 2 in CHANGELOG.md" ] || fail "default changelog: $out"

mkdir -p "$R/docs"
printf '## Unreleased\n- One.\n- Two.\n- Three.\n' > "$R/docs/changes.md"
cat > "$R/AGENTS.md" <<'MD'
# Project

## Factory
- **docs** — behavior: `README.md` · changelog: `docs/changes.md` under `## Unreleased`, one plain sentence
MD
out="$("$SV" update "$R")"
[ "$(line unreleased)" = "unreleased: 3 in docs/changes.md" ] || fail "changelog from the contract: $out"

L="$T/local"
git init -q -b master "$L"
commit "$L" one
git -C "$L" switch -q -c topic
commit "$L" two
out="$("$SV" update "$L")"
[ "$(line default)" = "default: master, this branch 1 ahead, 0 behind" ] || fail "master fallback: $out"
git -C "$L" branch -q main master
commit "$L" three
out="$("$SV" update "$L")"
[ "$(line default)" = "default: main, this branch 2 ahead, 0 behind" ] || fail "main before master: $out"

P="$T/projects"
git init -q -b main "$P"
mkdir -p "$P/app" "$P/packages/core" "$P/packages/ui" "$P/tool" "$P/website" "$P/admin" "$P/scripts" "$P/plain" \
  "$P/supabase/functions" "$P/backend/supabase" "$P/app/build/x" "$P/website/node_modules/dep" "$P/app/.dart_tool/x" \
  "$P/a/b/c"
printf 'name: app\ndependencies:\n  flutter:\n    sdk: flutter\n' > "$P/app/pubspec.yaml"
printf '{\n  "flutter": "3.24.0"\n}\n' > "$P/app/.fvmrc"
printf 'name: root\nworkspace:\n  - packages/core\n  - packages/ui\n' > "$P/pubspec.yaml"
printf 'name: core\nresolution: workspace\n' > "$P/packages/core/pubspec.yaml"
printf 'name: ui\nresolution: workspace\ndependencies:\n  flutter:\n    sdk: flutter\n' > "$P/packages/ui/pubspec.yaml"
mkdir -p "$P/packages/.fvm"
printf '{"flutterSdkVersion": "3.22.1", "flavors": {}}' > "$P/packages/.fvm/fvm_config.json"
printf 'name: tool\n' > "$P/tool/pubspec.yaml"
printf 'name: skipped\n' > "$P/app/build/x/pubspec.yaml"
printf 'name: skipped\n' > "$P/app/.dart_tool/x/pubspec.yaml"
printf 'name: too_deep\n' > "$P/a/b/c/pubspec.yaml"
printf '{\n  "dependencies": {\n    "astro": "^4.0.0"\n  }\n}\n' > "$P/website/package.json"
: > "$P/website/package-lock.json"
printf '{}\n' > "$P/website/node_modules/dep/package.json"
printf '{"name": "admin"}\n' > "$P/admin/package.json" && : > "$P/admin/pnpm-lock.yaml"
printf '{"name": "scripts"}\n' > "$P/scripts/package.json" && : > "$P/scripts/yarn.lock"
printf '{"name": "plain"}\n' > "$P/plain/package.json"
printf '[api]\n' > "$P/supabase/config.toml"
printf '{"imports": {}}\n' > "$P/supabase/functions/deno.json"
printf '[api]\n' > "$P/backend/supabase/config.toml"
printf '[tool]\n' > "$P/tool/config.toml"

touch -t 202001010000 "$T/marker" && find "$P" -exec touch -t 202001010000 {} +
out="$("$SV" update "$P/app")"
[ -z "$(find "$P" -newer "$T/marker")" ] || fail "update must write nothing: $(find "$P" -newer "$T/marker")"
[ "$(printf '%s\n' "$out" | grep -c '^flutter: ')" = 5 ] || fail "five pubspecs expected: $out"
has "flutter: . (dart, workspace root)"
has "flutter: app (flutter, pinned 3.24.0)"
has "flutter: packages/core (dart, workspace member, pinned 3.22.1)"
has "flutter: packages/ui (flutter, workspace member, pinned 3.22.1)"
has "flutter: tool (dart)"
[ "$(printf '%s\n' "$out" | grep -c '^node: ')" = 4 ] || fail "four package.json expected: $out"
has "node: admin (pnpm)"
has "node: plain (none)"
has "node: scripts (yarn)"
has "node: website (npm, astro)"
[ "$(printf '%s\n' "$out" | grep -c '^supabase: ')" = 2 ] || fail "two supabase folders expected: $out"
has "supabase: backend/supabase"
has "supabase: supabase (imports supabase/functions/deno.json)"
[ "$(line default)" = "default: none found" ] || fail "no default in an empty repo: $out"
[ "$(line branch)" = "branch: main, no commits" ] || fail "no commits: $out"

mkdir "$T/nojq"
for d in /bin /usr/bin "$(dirname "$(command -v git)")"; do
  for f in "$d"/*; do
    n="$(basename "$f")"
    [ "$n" = jq ] || [ -e "$T/nojq/$n" ] || [ -L "$T/nojq/$n" ] || ln -s "$f" "$T/nojq/$n"
  done
done
PATH="$T/nojq" command -v jq >/dev/null && fail "jq still on PATH"
out="$(PATH="$T/nojq" "$SV" update "$P")" || fail "update failed without jq"
has "node: website (npm, astro)"
has "flutter: app (flutter, pinned 3.24.0)"

"$SV" update "$T" >/dev/null 2>&1 && fail "outside a repo should fail"
"$SV" update "$T/missing" >/dev/null 2>&1 && fail "a missing folder should fail"

echo "cli_update: ok"
