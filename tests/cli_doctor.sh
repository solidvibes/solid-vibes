#!/usr/bin/env bash
# solidvibes doctor: a clean project passes; hand edits to generated files and blocks, a broken
# .claude/skills link, a ## Factory in CLAUDE.md and a missing harness are reported; doctor changes nothing.
set -euo pipefail

SV="$(cd "$(dirname "$0")/.." && pwd -P)/bin/solidvibes"
T="$(mktemp -d)"
trap 'rm -rf "$T"' EXIT

fail() { echo "FAIL: $*" >&2; exit 1; }
expect_line() { printf '%s\n' "$out" | grep -qF -- "$1" || fail "missing [$1] in: $out"; }
snap() { (cd "$1" && find . -print | LC_ALL=C sort | while IFS= read -r p; do
  if [ -L "$p" ]; then echo "L $p $(readlink "$p")"; elif [ -f "$p" ]; then echo "F $p $(shasum -a 256 < "$p")"; else echo "D $p"; fi
done); }

P="$T/proj"
"$SV" init "$P" > /dev/null
out="$("$SV" doctor "$P")" || fail "a fresh project should pass: $out"
expect_line "doctor: ok"
expect_line "harness: none"
printf '# Notes\n\n```\n## Factory\n```\n' > "$P/CLAUDE.md"
out="$("$SV" doctor "$P")" || fail "a fenced ## Factory in CLAUDE.md is not a contract: $out"

# Hand edits, a broken link and a contract left in CLAUDE.md.
echo "my own rule" >> "$P/docs/CONVENTIONS.md"
awk '/<!-- solidvibes:begin routing -->/ { print; print "an edit"; next } { print }' "$P/AGENTS.md" > "$T/a" && cp "$T/a" "$P/AGENTS.md"
mkdir -p "$P/.agents/skills/kept" "$P/.claude/skills"
printf -- '---\nname: kept\ndescription: Use when x.\n---\n' > "$P/.agents/skills/kept/SKILL.md"
ln -s ../../.agents/skills/kept "$P/.claude/skills/kept"
ln -s ../../.agents/skills/gone "$P/.claude/skills/gone"
printf '\n## Factory\n\n- **checks** — fast: `true`\n' >> "$P/CLAUDE.md"
rm "$P/.solidvibes/factory-contract.md"

before="$(snap "$P")"
out="$("$SV" doctor "$P")" && fail "problems should fail: $out"
[ "$(snap "$P")" = "$before" ] || fail "doctor changed the project"
expect_line "problem  docs/CONVENTIONS.md was edited by hand"
expect_line "problem  AGENTS.md: the routing block was edited by hand"
expect_line "problem  .solidvibes/factory-contract.md is missing"
expect_line "problem  .claude/skills/gone points to ../../.agents/skills/gone, which does not exist"
expect_line "problem  CLAUDE.md holds a ## Factory; the skills read it from AGENTS.md only (the interview skill moves it on your yes)"
expect_line "doctor: 5 problem(s)"
printf '%s\n' "$out" | grep -q 'skills/kept' && fail "a working link is not a problem"

# Harness: a command on PATH that answers status --json, then one that is not installed.
Q="$T/harness"
"$SV" init "$Q" > /dev/null
mkdir "$T/bin"
printf '#!/usr/bin/env bash\n[ "$1 $2" = "status --json" ] && echo "{\\"levels\\": []}"\n' > "$T/bin/sv-harness"
chmod +x "$T/bin/sv-harness"
sed 's/^- \*\*harness\*\* — none$/- **harness** — `sv-harness` · levels: unit · targets: web/' "$Q/AGENTS.md" > "$T/a" && cp "$T/a" "$Q/AGENTS.md"
out="$(PATH="$T/bin:$PATH" "$SV" doctor "$Q")" || fail "a working harness should pass: $out"
expect_line "sv-harness status --json answers"
rm "$T/bin/sv-harness"
out="$(PATH="$T/bin:/usr/bin:/bin" "$SV" doctor "$Q")" && fail "a missing harness should fail"
expect_line 'problem  sv-harness not installed: run `solidvibes install`'

# No contract, no manifest.
mkdir "$T/bare"
out="$("$SV" doctor "$T/bare")" && fail "a bare folder should fail"
expect_line "problem  no AGENTS.md"
expect_line "problem  no .solidvibes/manifest.json"
echo "cli_doctor: ok"
