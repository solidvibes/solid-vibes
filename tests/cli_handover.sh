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
grep -qx "… 26 more lines" "$H" || fail "status should stop at 15 lines: $(cat "$H")"
grep -q "^Diff:\|^Worktrees:" "$H" && fail "the snapshot holds only branch, status and commits"
rm "$P"/untracked-*

# Done keeps its first 5 entries; older ones move to the top of done/<entry month>.md, newest first.
D="$P/.solidvibes/done"
NOW="$(date +%Y-%m)"
printf '# Handover\n\n## Done\n- d1\n- d2\n  more of d2\n- d3\n- d4\n- d5\n- d6 2026-03-02\n  more of d6\n\n- d7 2999-01-01 iPhone 15 2026-03\n\n## Open\n- o1\n' > "$H"
"$SV" handover --snapshot "$P"
[ "$(grep -c '^- d' "$H")" = 5 ] || fail "Done should keep 5: $(cat "$H")"
grep -qx "  more of d2" "$H" || fail "a kept entry keeps its second line"
grep -q "d6\|d7" "$H" && fail "old entries should leave the handover: $(cat "$H")"
[ "$(sed -n '/^## Done/,/^## Open/p' "$H" | tail -n 2 | head -n 1)" = "" ] || fail "one blank line before Open: $(cat "$H")"
grep -qx -- "- o1" "$H" || fail "Open must stay"
[ "$(grep '^-\|^  more' "$D/2026-03.md" | tr '\n' '|')" = "- d6 2026-03-02|  more of d6|" ] || fail "dated entry: $(ls "$D")"
[ "$(grep '^- ' "$D/$NOW.md" | tr '\n' '|')" = "- d7 2999-01-01 iPhone 15 2026-03|" ] || fail "no past full date goes to this month: $(ls "$D")"
printf '# Handover\n\n## Done\n- n1\n- n2\n- n3\n- n4\n- n5\n- n6\n' > "$H"
"$SV" handover --snapshot "$P"
[ "$(grep '^- ' "$D/$NOW.md" | tr '\n' '|')" = "- n6|- d7 2999-01-01 iPhone 15 2026-03|" ] || fail "newest first: $(cat "$D/$NOW.md")"
[ "$(grep -c '^# Done' "$D/$NOW.md")" = 1 ] || fail "one heading per month file"
[ -z "$(cd "$P" && git status --short .solidvibes)" ] || fail "done/ must be ignored by git"
printf '# Handover\n\n## Done\n- a\n- b\n' > "$H"
cp "$D/$NOW.md" "$T/done.before"
"$SV" handover --snapshot "$P"
cmp -s "$D/$NOW.md" "$T/done.before" || fail "5 or fewer entries leave the archive alone"

# An older done.md is split into the monthly files once, after anything moved now.
rm -r "$D"
printf '# Done\n\n_old_\n\n- m1 2026-03-30\n- m2\n  more of m2\n' > "$P/.solidvibes/done.md"
printf '# Handover\n\n## Done\n- n1\n- n2\n- n3\n- n4\n- n5\n- n6\n' > "$H"
"$SV" handover --snapshot "$P"
[ ! -e "$P/.solidvibes/done.md" ] || fail "done.md should be migrated away"
[ "$(grep '^- ' "$D/2026-03.md" | tr '\n' '|')" = "- m1 2026-03-30|" ] || fail "migrated dated: $(cat "$D/2026-03.md")"
[ "$(grep '^-\|^  more' "$D/$NOW.md" | tr '\n' '|')" = "- n6|- m2|  more of m2|" ] || fail "migrated undated: $(cat "$D/$NOW.md")"
[ "$(grep -c '^- ' "$H")" = 5 ] || fail "handover keeps 5 after a migration"
rm "$H"
echo "- m3" > "$P/.solidvibes/done.md"
"$SV" handover --snapshot "$P"
grep -qx -- "- m3" "$D/$NOW.md" && [ ! -e "$P/.solidvibes/done.md" ] || fail "migrates with nothing to move"

sed -i.bak '/^done\/$/d' "$P/.solidvibes/.gitignore" && rm "$P/.solidvibes/.gitignore.bak"
printf '# Handover\n\n## Done\n- 1\n- 2\n- 3\n- 4\n- 5\n- 6\n' > "$H"
"$SV" handover --snapshot "$P"
[ "$(grep -c '^- ' "$H")" = 6 ] || fail "no trim unless the gitignore lists done/"
echo done/ >> "$P/.solidvibes/.gitignore"

# --log moves the local monthly archive into the committed docs/log/, newest on top.
L="$P/docs/log"
printf '# Done 2026-03\n\n_x_\n\n- l1\n  more of l1\n' > "$D/2026-03.md"
printf '# Work log 2026-03\n\n_x_\n\n- l0\n' > "$T/log-before" && mkdir -p "$L" && cp "$T/log-before" "$L/2026-03.md"
rm -f "$D/$NOW.md"
out="$("$SV" handover --log "$P")"
[ "$out" = "logged 1 line(s) to docs/log/2026-03.md" ] || fail "log output: $out"
[ "$(grep '^-\|^  more' "$L/2026-03.md" | tr '\n' '|')" = "- l1|  more of l1|- l0|" ] || fail "log order: $(cat "$L/2026-03.md")"
[ "$(grep -c '^# Work log' "$L/2026-03.md")" = 1 ] || fail "one heading in the log"
[ ! -e "$D/2026-03.md" ] || fail "the local month should be gone after --log"
(cd "$P" && git status --short docs/log) | grep -q 'docs/log' || fail "docs/log must not be ignored"
[ -z "$("$SV" handover --log "$P")" ] || fail "nothing to log is silent"
"$SV" handover "$P" 2>/dev/null && fail "handover needs --snapshot or --log"

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
