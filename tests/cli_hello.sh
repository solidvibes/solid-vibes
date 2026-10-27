#!/usr/bin/env bash
# solidvibes hello: docs hash same after --checked, changed after a decision edit, same after a plan
# edit; handover age; CI missing and present; setup differs when the manifest's sv is older; the hook
# is silent without a manifest.
set -euo pipefail

SV="$(cd "$(dirname "$0")/.." && pwd -P)/bin/solidvibes"
T="$(mktemp -d)"
trap 'rm -rf "$T"' EXIT
T="$(cd "$T" && pwd -P)"

fail() { echo "FAIL: $*" >&2; exit 1; }
line() { printf '%s\n' "$out" | grep "^$1: " || fail "no $1 line in: $out"; }

export GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_NOSYSTEM=1

P="$T/project"
mkdir "$P" && git init -q "$P"
"$SV" init "$P" >/dev/null

out="$("$SV" hello "$P")"
[ "$(line handover)" = "handover: none" ] || fail "handover: $out"
line setup | grep -q '^setup: same ' || fail "fresh setup should be same: $out"
[ "$(line ci)" = "ci: none" ] || fail "ci: $out"
[ "$(line docs)" = "docs: unchecked" ] || fail "docs before any check: $out"
[ ! -e "$P/.solidvibes/hello.state" ] || fail "hello without --checked must write nothing"

out="$("$SV" hello --checked "$P")"
[ "$(line docs)" = "docs: same" ] || fail "same after --checked: $out"

: > "$P/docs/decisions/.DS_Store"
out="$("$SV" hello "$P")"
[ "$(line docs)" = "docs: same" ] || fail "a .DS_Store is outside the hash: $out"

echo "A plan." > "$P/docs/plans/2026-01-01-x.md"
out="$(cd "$P/docs" && "$SV" hello)"
[ "$(line docs)" = "docs: same" ] || fail "a plan edit is outside the hash: $out"

echo "We chose X." > "$P/docs/decisions/2026-01-01-x.md"
out="$("$SV" hello "$P")"
[ "$(line docs)" = "docs: changed" ] || fail "a decision edit should change the hash: $out"
"$SV" hello --checked "$P" >/dev/null
printf '\n## Packs\n- flutter\n' >> "$P/docs/stack.md"
out="$("$SV" hello "$P")"
[ "$(line docs)" = "docs: changed" ] || fail "a stack.md edit should change the hash: $out"

printf '# Handover\n' > "$P/.solidvibes/handover.md"
touch -t "$(date -v-3H +%Y%m%d%H%M 2>/dev/null || date -d '-3 hours' +%Y%m%d%H%M)" "$P/.solidvibes/handover.md"
out="$("$SV" hello "$P")"
[ "$(line handover)" = "handover: present, 3h old" ] || fail "handover age: $out"

mkdir -p "$P/.github/workflows" && echo "on: pull_request" > "$P/.github/workflows/ci.yml"
out="$("$SV" hello "$P")"
[ "$(line ci)" = "ci: present (1 workflow file(s))" ] || fail "ci present: $out"

sed -i.bak 's/^  "sv": "[^"]*"/  "sv": "0.0.1"/' "$P/.solidvibes/manifest.json" && rm "$P/.solidvibes/manifest.json.bak"
out="$("$SV" hello "$P")"
line setup | grep -q '^setup: differs (project: sv 0.0.1,' || fail "older manifest should differ: $out"

out="$(echo '{"source":"startup"}' | "$SV" hello --hook "$P")"
printf '%s\n' "$out" | grep -qx "# Handover" || fail "hook should print the handover: $out"
printf '%s\n' "$out" | grep -qx "Say hello for the full check." || fail "hook startup reminder: $out"
out="$(echo '{"source":"compact"}' | "$SV" hello --hook "$P")"
printf '%s\n' "$out" | grep -q "Say hello" && fail "reminder only on startup: $out"

N="$T/plain"
mkdir "$N" && git init -q "$N"
out="$(echo '{"source":"startup"}' | "$SV" hello --hook "$N")"
[ -z "$out" ] || fail "hook must be silent without a manifest: $out"
[ -z "$(ls -A "$N" | grep -v '^\.git$')" ] || fail "hook wrote into a project without a manifest"
echo '{}' | "$SV" hello --hook "$T/missing" || fail "hook must never fail"

echo "cli_hello: ok"
