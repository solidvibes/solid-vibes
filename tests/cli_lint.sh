#!/usr/bin/env bash
# solidvibes lint: passes a good skill, names each broken rule, checks JSON manifests.
set -euo pipefail

SV="$(cd "$(dirname "$0")/.." && pwd -P)/bin/solidvibes"
T="$(mktemp -d)"
trap 'rm -rf "$T"' EXIT

fail() { echo "FAIL: $*" >&2; exit 1; }

mkdir -p "$T/repo/.claude-plugin"
echo '{"name": "x"}' > "$T/repo/.claude-plugin/plugin.json"
mkdir -p "$T/repo/skills/good" "$T/repo/skills/folded"
printf -- '---\nname: good\ndescription: "Plan a change. Use when the user says plan this."\n---\n' > "$T/repo/skills/good/SKILL.md"
printf -- '---\nname: folded\ndescription: >\n  Review a diff.\n  Use when asked for a review.\n---\n' > "$T/repo/skills/folded/SKILL.md"

out="$("$SV" lint "$T/repo")" || fail "good repo should pass: $out"
[ "$out" = "lint: ok (2 skills, 1 manifests)" ] || fail "unexpected summary: $out"

mkdir -p "$T/repo/skills/wrong" "$T/repo/skills/nodesc" "$T/repo/skills/notrigger" "$T/repo/skills/long" "$T/repo/skills/paths/references"
printf -- '---\nname: other\ndescription: Use when x.\n---\n' > "$T/repo/skills/wrong/SKILL.md"
printf -- '---\nname: nodesc\n---\n' > "$T/repo/skills/nodesc/SKILL.md"
printf -- '---\nname: notrigger\ndescription: Does things.\n---\n' > "$T/repo/skills/notrigger/SKILL.md"
printf -- '---\nname: long\ndescription: Use when %s\n---\n' "$(printf 'a%.0s' $(seq 1 1100))" > "$T/repo/skills/long/SKILL.md"
printf -- '---\nname: paths\ndescription: Use when y.\n---\nRead ~/.claude/commands/x.md\n' > "$T/repo/skills/paths/SKILL.md"
printf 'line one\nsee /Users/someone/secret-project\n' > "$T/repo/skills/paths/references/notes.md"
echo '{"name": ' > "$T/repo/.claude-plugin/marketplace.json"
printf 'Hand off to the `folded` skill, then the `ghost` skill.\nThe `harness` skill and the `stack-x` skill are exempt.\n' > "$T/repo/skills/good/notes.md"
mkdir -p "$T/repo/setup/templates"
printf '<!-- solidvibes:begin routing -->\n| The request | What happens |\n|---|---|\n| Small | `brief`, then `phantom` |\n| Trivial | just do it |\n<!-- solidvibes:end routing -->\n' > "$T/repo/setup/templates/AGENTS.md"

out="$("$SV" lint "$T/repo")" && fail "broken repo should fail"
expect_line() { printf '%s\n' "$out" | grep -qF -- "$1" || fail "missing [$1] in: $out"; }
expect_line 'skills/wrong/SKILL.md: name "other" does not match its folder "wrong"'
expect_line 'skills/nodesc/SKILL.md: frontmatter has no description'
expect_line 'skills/notrigger/SKILL.md: description has no "Use when" trigger'
expect_line 'skills/long/SKILL.md: description is 1109 characters, over 1024'
expect_line 'skills/paths/SKILL.md:5: owner path'
expect_line 'skills/paths/references/notes.md:2: owner path'
expect_line '.claude-plugin/marketplace.json: JSON does not parse'
expect_line 'skills/good/notes.md:1: names the skill "ghost", which does not exist in skills/'
expect_line 'setup/templates/AGENTS.md:4: names the skill "phantom"'
expect_line 'lint: 9 problem(s)'
printf '%s\n' "$out" | grep -qE '"(folded|brief|harness|stack-x)"' && fail "existing or exempt skills must pass"
printf '%s\n' "$out" | grep -q 'someone' && fail "lint must not print matched values"

"$SV" lint "$T/missing" 2>/dev/null && fail "missing dir should fail"
echo "cli_lint: ok"
