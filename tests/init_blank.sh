#!/usr/bin/env bash
# solidvibes init: empty repo and the tiny-repo fixture (no CLAUDE.md, a CLAUDE.md, a ## Factory in
# CLAUDE.md); the contract parses and its checks run; a second run changes nothing; seeded edits
# survive; nothing is deleted; a profile's rules/ and harness are never copied; .claude/skills links.
set -euo pipefail

REPO="$(cd "$(dirname "$0")/.." && pwd -P)"
SV="$REPO/bin/solidvibes"
FIXTURE="$REPO/tests/fixtures/tiny-repo"
# shellcheck source=lib/contract.sh
source "$REPO/lib/contract.sh"
T="$(mktemp -d)"
trap 'rm -rf "$T"' EXIT
T="$(cd "$T" && pwd -P)"
export PATH="$REPO/bin:$PATH"

fail() { echo "FAIL: $*" >&2; exit 1; }
has() { grep -qF -- "$2" "$1" || fail "$1 lacks [$2]"; }
lacks() { ! grep -qF -- "$2" "$1" || fail "$1 should not have [$2]"; }
count() { grep -cxF -- "$2" "$1" || true; }

# Path, type, content hash, executable bit and link target of every entry under a folder.
snap() {
  (cd "$1" && find . -path ./.git -prune -o -print | LC_ALL=C sort | while IFS= read -r p; do
    if [ -L "$p" ]; then echo "L $p -> $(readlink "$p")"
    elif [ -f "$p" ]; then echo "F $p $(shasum -a 256 < "$p" | cut -c1-16) $([ -x "$p" ] && echo x || echo -)"
    else echo "D $p"; fi
  done)
}

init() { "$SV" init "$@" > "$T/out" 2>&1 || { cat "$T/out" >&2; fail "init $* failed"; }; }

again_unchanged() { # <dir> [init args…]
  local dir="$1" before
  shift
  before="$(snap "$dir")"
  init "$@" "$dir"
  [ "$(snap "$dir")" = "$before" ] || fail "second run changed $dir"
  grep -q ' 0 written, .* 0 created, .* 0 linked' "$T/out" || fail "second run reported writes: $(tail -1 "$T/out")"
}

checks_green() { # <dir>
  local cmd
  cmd="$(contract_checks "$1" fast)" || fail "no checks.fast in $1"
  (cd "$1" && bash -c "$cmd") >/dev/null 2>&1 || fail "checks.fast failed in $1: $cmd"
}

# 1. An empty repo.
E="$T/empty"
mkdir "$E" && git init -q "$E"
init "$E"
for f in AGENTS.md CHANGELOG.md .solidvibes/factory-contract.md .solidvibes/agents.md .solidvibes/manifest.json .solidvibes/.gitignore \
  docs/README.md docs/intent.md docs/stack.md docs/CONVENTIONS.md docs/decisions/README.md docs/direction/README.md \
  docs/how-it-works/.gitkeep docs/plans/.gitkeep docs/ideas/.gitkeep; do
  [ -f "$E/$f" ] || fail "empty repo: $f missing"
done
[ ! -e "$E/CLAUDE.md" ] || fail "init must not write a CLAUDE.md"
has "$E/AGENTS.md" "# empty"
for b in audience routing visuals; do
  [ "$(count "$E/AGENTS.md" "<!-- solidvibes:begin $b -->")" = 1 ] || fail "block $b missing"
done
has "$E/docs/README.md" "## Right now"
has "$E/CHANGELOG.md" "## Unreleased"
has "$E/docs/stack.md" "blank 0.1.0"
has "$E/docs/CONVENTIONS.md" "solidvibes:generated from sv"
head -n 1 "$E/.solidvibes/.gitignore" | grep -q '^# solidvibes:generated from sv' || fail ".solidvibes/.gitignore header"
[ "$(count "$E/.solidvibes/.gitignore" handover.md)" = 1 ] && [ "$(count "$E/.solidvibes/.gitignore" hello.state)" = 1 ] \
  || fail ".solidvibes/.gitignore lines"
jq -e '[.generated[].path] | index(".solidvibes/.gitignore") != null' "$E/.solidvibes/manifest.json" >/dev/null \
  || fail ".solidvibes/.gitignore not in the manifest"
lacks "$E/docs/intent.md" "solidvibes:generated"
[ "$(contract_file "$E")" = "$E/AGENTS.md" ] || fail "empty repo: no contract"
[ "$(contract_field "$E" stack)" = '`docs/stack.md` (blank 0.1.0)' ] || fail "stack field: $(contract_field "$E" stack)"
[ "$(contract_field "$E" harness)" = none ] || fail "harness field"
for field in layers checks codegen run plans docs rules risk ships sandbox; do
  contract_field "$E" "$field" >/dev/null || fail "empty repo: contract has no $field"
done
grep -q '{{' "$E/AGENTS.md" "$E/docs/README.md" "$E/docs/stack.md" && fail "a placeholder was left unfilled"
jq -e '.profile.name == "blank" and (.agents | length) == 3 and ([.generated[] | select(.block)] | length) == 3' \
  "$E/.solidvibes/manifest.json" >/dev/null || fail "manifest shape"
checks_green "$E"
again_unchanged "$E"

# 2. A project with AGENTS.md and a contract, no CLAUDE.md.
A="$T/tiny"
cp -R "$FIXTURE" "$A"
init "$A"
[ "$(contract_checks "$A" fast)" = 'sh -n greet.sh && sh greet.sh >/dev/null' ] || fail "the project's own contract was replaced"
[ "$(count "$A/AGENTS.md" "## Factory")" = 1 ] || fail "one ## Factory expected"
has "$A/AGENTS.md" "A fixture for \`tests/init_blank.sh\`"
has "$A/AGENTS.md" "<!-- solidvibes:begin routing -->"
has "$A/AGENTS.md" "## Working style"
[ "$(tail -n 1 "$A/AGENTS.md")" = '- **harness** — none' ] || fail "## Factory should stay last"
[ ! -e "$A/CLAUDE.md" ] || fail "init must not write a CLAUDE.md"
checks_green "$A"
again_unchanged "$A"

# Seeded edits survive; generated edits are replaced; nothing is deleted.
echo "Our own words." >> "$A/docs/intent.md"
sed -i.bak 's/^_Not written yet. The `interview` skill fills this in: what this is.*/A greeting script for testing./' "$A/AGENTS.md"
rm "$A/AGENTS.md.bak"
echo "- Greets." >> "$A/CHANGELOG.md"
echo "hand edit" >> "$A/docs/CONVENTIONS.md"
sed -i.bak 's/^Show visuals for decisions, flows and screens.*/Never mind visuals./' "$A/AGENTS.md"
rm "$A/AGENTS.md.bak"
mkdir -p "$A/.agents/skills/old-rule" "$A/docs/plans"
printf -- '---\nname: old-rule\ndescription: Use when testing.\n---\n' > "$A/.agents/skills/old-rule/SKILL.md"
echo "notes" > "$A/.solidvibes/notes.txt"
echo "plan" > "$A/docs/plans/2026-01-01-x.md"
init "$A"
has "$A/docs/intent.md" "Our own words."
has "$A/AGENTS.md" "A greeting script for testing."
has "$A/CHANGELOG.md" "- Greets."
lacks "$A/docs/CONVENTIONS.md" "hand edit"
lacks "$A/AGENTS.md" "Never mind visuals."
has "$A/AGENTS.md" "Show visuals for decisions, flows and screens."
for f in .agents/skills/old-rule/SKILL.md .solidvibes/notes.txt docs/plans/2026-01-01-x.md docs/plans/.gitkeep; do
  [ -f "$A/$f" ] || fail "init deleted $f"
done
[ "$(readlink "$A/.claude/skills/old-rule")" = ../../.agents/skills/old-rule ] || fail "a project's own skill should be linked"
again_unchanged "$A"

# 3. A project with a CLAUDE.md.
C="$T/with-claude"
cp -R "$FIXTURE" "$C"
printf '# Claude notes\n\nUse short sentences.' > "$C/CLAUDE.md"
init "$C"
has "$C/CLAUDE.md" "Use short sentences."
[ "$(count "$C/CLAUDE.md" "@AGENTS.md")" = 1 ] || fail "CLAUDE.md should import @AGENTS.md once"
[ "$(tail -n 1 "$C/CLAUDE.md")" = "@AGENTS.md" ] || fail "@AGENTS.md goes at the end"
checks_green "$C"
again_unchanged "$C"

# 4. A ## Factory in CLAUDE.md: AGENTS.md gets none, CLAUDE.md keeps it, the skill moves it later.
F="$T/factory-in-claude"
cp -R "$FIXTURE" "$F"
mv "$F/AGENTS.md" "$F/CLAUDE.md"
cp "$F/CLAUDE.md" "$T/claude-before"
init "$F"
grep -q "CLAUDE.md holds a ## Factory" "$T/out" || fail "init should say the contract sits in CLAUDE.md"
[ -f "$F/AGENTS.md" ] || fail "AGENTS.md should be created"
[ "$(count "$F/AGENTS.md" "## Factory")" = 0 ] || fail "no ## Factory may be seeded while CLAUDE.md holds one"
contract_file "$F" >/dev/null && fail "the contract is read from AGENTS.md only"
[ "$(head -c "$(wc -c < "$T/claude-before")" "$F/CLAUDE.md")" = "$(cat "$T/claude-before")" ] || fail "CLAUDE.md content changed"
[ "$(count "$F/CLAUDE.md" "## Factory")" = 1 ] || fail "init never moves the ## Factory itself"
[ "$(count "$F/CLAUDE.md" "@AGENTS.md")" = 1 ] || fail "CLAUDE.md should import @AGENTS.md"
again_unchanged "$F"

# 5. A file at a generated path that init did not make is left alone.
G="$T/own-conventions"
cp -R "$FIXTURE" "$G"
mkdir -p "$G/docs" && echo "our conventions" > "$G/docs/CONVENTIONS.md"
init "$G"
[ "$(cat "$G/docs/CONVENTIONS.md")" = "our conventions" ] || fail "init overwrote a file it did not make"
grep -q "skipped *docs/CONVENTIONS.md" "$T/out" || fail "init should report the skipped file"

# 6. A profile with rules/ and a harness: copies neither; links for Claude Code; agent choice.
P="$T/profile"
cp -R "$REPO/setup/profiles/blank" "$P"
awk '$0 == "name: blank" { print "name: stack-demo"; next } /^version:/ { print "version: 2.0.0"; print "harness: engine"; next } { print }' \
  "$P/SKILL.md" > "$P/SKILL.md.new" && mv "$P/SKILL.md.new" "$P/SKILL.md"
mkdir -p "$P/rules/demo-rule" "$P/engine"
printf -- '---\nname: demo-rule\ndescription: Use when touching greetings.\n---\n\n# Demo rule\n' > "$P/rules/demo-rule/SKILL.md"
printf '#!/usr/bin/env bash\necho harness\n' > "$P/engine/run.sh"

R="$T/with-profile"
cp -R "$FIXTURE" "$R"
mkdir -p "$R/.agents/skills/own" "$R/.claude/skills/taken"
printf -- '---\nname: own\ndescription: Use when testing.\n---\n' > "$R/.agents/skills/own/SKILL.md"
printf -- '---\nname: taken\ndescription: Use when testing.\n---\n' > "$R/.claude/skills/taken/SKILL.md"
mkdir -p "$R/.agents/skills/taken" && cp "$R/.claude/skills/taken/SKILL.md" "$R/.agents/skills/taken/"
init --profile "$P" --agents claude "$R"
[ ! -e "$R/.agents/skills/demo-rule" ] || fail "a profile's rules/ must not be copied"
[ ! -e "$R/harness" ] && [ ! -e "$R/engine" ] || fail "a profile's harness folder must not be copied"
[ "$(readlink "$R/.claude/skills/own")" = "../../.agents/skills/own" ] || fail ".claude/skills/own link"
[ -f "$R/.claude/skills/own/SKILL.md" ] || fail ".claude/skills/own does not resolve"
[ -d "$R/.claude/skills/taken" ] && [ ! -L "$R/.claude/skills/taken" ] || fail "an existing folder must not become a link"
grep -q "skipped *.claude/skills/taken" "$T/out" || fail "init should report the kept folder"
grep -q "Claude Code" "$R/.solidvibes/agents.md" || fail "agents.md: Claude row"
grep -q "^| Codex" "$R/.solidvibes/agents.md" && fail "agents.md: only the agents in use"
jq -e '[.links[].path] == [".claude/skills/own"] and .profile.name == "stack-demo"' \
  "$R/.solidvibes/manifest.json" >/dev/null || fail "manifest links or profile"
"$SV" lint "$R" >/dev/null || fail "lint fails on the project: $("$SV" lint "$R")"
checks_green "$R"
again_unchanged "$R" --profile "$P" --agents claude

# A rule an older init generated stays: init never deletes.
mkdir -p "$R/.agents/skills/demo-rule"
printf -- '---\nname: demo-rule\ndescription: Use when touching greetings.\n---\n\n<!-- solidvibes:generated from stack-demo 2.0.0 (rules/demo-rule/SKILL.md). Made by solidvibes init; changes here are replaced the next time it runs. -->\n\n# Demo rule\n' \
  > "$R/.agents/skills/demo-rule/SKILL.md"
cp "$R/.agents/skills/demo-rule/SKILL.md" "$T/demo-rule-before"
jq '.generated += [{"path": ".agents/skills/demo-rule/SKILL.md", "source": "stack-demo 2.0.0 (rules/demo-rule/SKILL.md)", "version": "2.0.0", "hash": "sha256:0"}]' \
  "$R/.solidvibes/manifest.json" > "$T/manifest" && cp "$T/manifest" "$R/.solidvibes/manifest.json"
init --profile "$P" --agents claude "$R"
cmp -s "$R/.agents/skills/demo-rule/SKILL.md" "$T/demo-rule-before" || fail "init changed or deleted an old generated rule"

X="$T/codex-only"
mkdir "$X"
init --agents codex "$X"
[ ! -e "$X/.claude" ] || fail "no .claude folder without claude"
grep -q "^| Codex" "$X/.solidvibes/agents.md" || fail "agents.md: Codex row"

# 7. Refusals: an unknown agent, broken markers (nothing written).
"$SV" init --agents nobody "$T/nope" >/dev/null 2>&1 && fail "unknown agent should fail"
B="$T/broken"
cp -R "$FIXTURE" "$B"
printf '\n<!-- solidvibes:begin routing -->\nhalf a block\n' >> "$B/AGENTS.md"
before="$(snap "$B")"
"$SV" init "$B" > "$T/out" 2>&1 && fail "broken markers should fail"
grep -q 'the "routing" block needs exactly one begin and one end marker' "$T/out" || fail "broken markers message: $(cat "$T/out")"
[ "$(snap "$B")" = "$before" ] || fail "a refused init must write nothing"

# 8. A path with spaces; links and files where folders go never lead init outside the project.
S="$T/my project"
mkdir "$S"
init "$S"
[ -f "$S/AGENTS.md" ] && [ -f "$S/docs/intent.md" ] && [ -f "$S/.solidvibes/manifest.json" ] || fail "path with spaces"
again_unchanged "$S"

O="$T/outside"
L="$T/linked"
mkdir -p "$O/sv" "$O/docs" "$L/.agents/skills/own"
printf '# Theirs\n' > "$O/agents.md"
printf -- '---\nname: own\ndescription: Use when testing.\n---\n' > "$L/.agents/skills/own/SKILL.md"
ln -s "$O/sv" "$L/.solidvibes"
ln -s "$O/docs" "$L/docs"
ln -s "$O/agents.md" "$L/AGENTS.md"
ln -s "$O" "$L/.claude"
before="$(snap "$O")"
init "$L"
[ "$(snap "$O")" = "$before" ] || fail "init wrote outside the project through a link"
grep -q "skipped *AGENTS.md" "$T/out" || fail "a linked AGENTS.md should be skipped"
mkdir -p "$T/folder-agents/AGENTS.md"
init "$T/folder-agents"
[ -z "$(ls -A "$T/folder-agents/AGENTS.md")" ] || fail "init wrote into a folder named AGENTS.md"

echo "init_blank: ok"
