#!/usr/bin/env bash
# solidvibes handover --snapshot: replaces only its own section and keeps the rest byte for byte;
# creates the file when missing; writes nothing without the manifest or the gitignore line.
set -euo pipefail

SV="$(cd "$(dirname "$0")/.." && pwd -P)/bin/solidvibes"
T="$(mktemp -d)"
trap 'rm -rf "$T"' EXIT
T="$(cd "$T" && pwd -P)"

fail() { echo "FAIL: $*" >&2; exit 1; }

export GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_NOSYSTEM=1
export GIT_AUTHOR_NAME=test GIT_AUTHOR_EMAIL=test@example.com GIT_COMMITTER_NAME=test GIT_COMMITTER_EMAIL=test@example.com

P="$T/project"
mkdir "$P" && git init -q -b main "$P"
"$SV" init "$P" >/dev/null
(cd "$P" && git add -A && git commit -qm "first version")
H="$P/.solidvibes/handover.md"

out="$("$SV" handover --snapshot "$P")"
[ -z "$out" ] || fail "snapshot should be silent: $out"
[ "$(head -n 1 "$H")" = "## Snapshot" ] || fail "a new file holds the section only"
grep -qx "Branch: main" "$H" || fail "branch missing"
grep -q "first version" "$H" || fail "last commits missing"
[ -z "$(cd "$P" && git status --short)" ] || fail "the handover must be ignored by git"

printf '# Handover\n\n## Done\n- the login\n\n## Snapshot\nold snapshot\n\n## Next\n- tests\n' > "$H"
(cd "$P" && echo change >> AGENTS.md)
"$SV" handover --snapshot "$P"
[ "$(sed -n '1,5p' "$H")" = "$(printf '# Handover\n\n## Done\n- the login\n')" ] || fail "text before the section changed"
[ "$(tail -n 2 "$H")" = "$(printf '## Next\n- tests')" ] || fail "text after the section changed: $(cat "$H")"
grep -q "old snapshot" "$H" && fail "the old snapshot should be replaced"
grep -q "M AGENTS.md" "$H" || fail "status missing: $(cat "$H")"
[ "$(grep -c '^## Snapshot$' "$H")" = 1 ] || fail "one section only"

printf '# Handover\n\n## Done\n- x' > "$H"
"$SV" handover --snapshot "$P"
[ "$(head -n 4 "$H")" = "$(printf '# Handover\n\n## Done\n- x')" ] || fail "an appended section must keep the text"
grep -qx "## Snapshot" "$H" || fail "section not appended"

printf '# Handover\r\n\r\n## Snapshot\r\nold\r\n' > "$H"
"$SV" handover --snapshot "$P"
[ "$(grep -c '^## Snapshot' "$H")" = 1 ] || fail "a CRLF section should be replaced, not appended: $(cat "$H")"

for i in $(seq 1 40); do : > "$P/untracked-$i"; done
"$SV" handover --snapshot "$P"
grep -qx "… 11 more lines" "$H" || fail "status should stop at 30 lines: $(cat "$H")"
rm "$P"/untracked-*

N="$T/no-manifest"
mkdir "$N" && git init -q "$N" && mkdir "$N/.solidvibes" && echo handover.md > "$N/.solidvibes/.gitignore"
"$SV" handover --snapshot "$N"
[ ! -e "$N/.solidvibes/handover.md" ] || fail "wrote without a manifest"

G="$T/no-gitignore"
mkdir "$G" && git init -q "$G"
"$SV" init "$G" >/dev/null
rm "$G/.solidvibes/.gitignore"
"$SV" handover --snapshot "$G"
[ ! -e "$G/.solidvibes/handover.md" ] || fail "wrote without the gitignore line"

"$SV" handover --snapshot "$T" || fail "outside a repo it exits 0"
echo "cli_handover: ok"
