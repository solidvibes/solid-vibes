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

# Done keeps its first 5 entries; older ones move to the top of done.md, newest first.
D="$P/.solidvibes/done.md"
printf '# Handover\n\n## Done\n- d1\n- d2\n  more of d2\n- d3\n- d4\n- d5\n- d6\n  more of d6\n\n- d7\n\n## Open\n- o1\n' > "$H"
"$SV" handover --snapshot "$P"
[ "$(grep -c '^- d' "$H")" = 5 ] || fail "Done should keep 5: $(cat "$H")"
grep -qx "  more of d2" "$H" || fail "a kept entry keeps its second line"
grep -q "d6\|d7" "$H" && fail "old entries should leave the handover: $(cat "$H")"
[ "$(sed -n '/^## Done/,/^## Open/p' "$H" | tail -n 2 | head -n 1)" = "" ] || fail "one blank line before Open: $(cat "$H")"
grep -qx -- "- o1" "$H" || fail "Open must stay"
[ "$(grep '^ *-\|^  more' "$D" | tr '\n' '|')" = "- d6|  more of d6|- d7|" ] || fail "done.md: $(cat "$D")"
printf '# Handover\n\n## Done\n- n1\n- n2\n- n3\n- n4\n- n5\n- n6\n' > "$H"
"$SV" handover --snapshot "$P"
[ "$(grep '^- ' "$D" | tr '\n' '|')" = "- n6|- d6|- d7|" ] || fail "newest first in done.md: $(cat "$D")"
[ "$(grep -c '^# Done' "$D")" = 1 ] || fail "one heading in done.md"
[ -z "$(cd "$P" && git status --short .solidvibes)" ] || fail "done.md must be ignored by git"
printf '# Handover\n\n## Done\n- a\n- b\n' > "$H"
cp "$D" "$T/done.before"
"$SV" handover --snapshot "$P"
cmp -s "$D" "$T/done.before" || fail "5 or fewer entries leave done.md alone"
sed -i.bak '/^done.md$/d' "$P/.solidvibes/.gitignore" && rm "$P/.solidvibes/.gitignore.bak"
printf '# Handover\n\n## Done\n- 1\n- 2\n- 3\n- 4\n- 5\n- 6\n' > "$H"
"$SV" handover --snapshot "$P"
[ "$(grep -c '^- ' "$H")" = 6 ] || fail "no trim unless the gitignore lists done.md"
echo done.md >> "$P/.solidvibes/.gitignore"

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
