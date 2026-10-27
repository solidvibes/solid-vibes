#!/usr/bin/env bash
# solidvibes install, in a temp HOME: links every sv and sv-pro skill, is idempotent, replaces only
# its own links, and leaves a real folder or a foreign link alone. Same for sv-pro's sv-harness
# and `install nono`.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd -P)"
SV="$ROOT/bin/solidvibes"
T="$(mktemp -d)"
trap 'rm -rf "$T"' EXIT
T="$(cd "$T" && pwd -P)"

fail() { echo "FAIL: $*" >&2; exit 1; }
expect() { printf '%s\n' "$out" | grep -qF -- "$1" || fail "missing [$1] in: $out"; }

export HOME="$T/home"
unset XDG_CONFIG_HOME
mkdir -p "$HOME"
S="$HOME/.agents/skills"

# A stand-in sv-pro with one skill.
PRO="$T/pro"
mkdir -p "$PRO/.claude-plugin" "$PRO/skills/harness"
printf '{ "name": "sv-pro" }\n' > "$PRO/.claude-plugin/plugin.json"
printf -- '---\nname: harness\ndescription: Use when x.\n---\n' > "$PRO/skills/harness/SKILL.md"
export SOLIDVIBES_PRO_ROOT="$PRO"

out="$("$SV" install)" || fail "install failed: $out"
expect "skipped   $HOME/.local/bin/sv-harness: sv-pro has no bin/sv-harness yet"
[ ! -e "$HOME/.local/bin/sv-harness" ] || fail "no sv-harness to link yet"
mkdir -p "$PRO/bin" && printf '#!/usr/bin/env bash\n' > "$PRO/bin/sv-harness" && chmod +x "$PRO/bin/sv-harness"
out="$("$SV" install)" || fail "install failed: $out"
expect "linked    $HOME/.local/bin/sv-harness"
expect "note: $HOME/.local/bin is not on your PATH"
export PATH="$HOME/.local/bin:$PATH"
[ "$(readlink "$HOME/.local/bin/sv-harness")" = "$PRO/bin/sv-harness" ] || fail "sv-harness not linked"
for d in "$ROOT"/skills/*/; do
  n="$(basename "$d")"
  [ "$(readlink "$S/$n")" = "$ROOT/skills/$n" ] || fail "$n not linked: $out"
  [ -f "$S/$n/SKILL.md" ] || fail "$n link does not resolve"
done
[ "$(readlink "$S/harness")" = "$PRO/skills/harness" ] || fail "sv-pro skill not linked"

out="$("$SV" install)" || fail "second install failed: $out"
if printf '%s\n' "$out" | grep -qv '^ok '; then fail "second install should change nothing: $out"; fi

# An old version's link is ours and gets updated; a real folder and a foreign link stay.
OLD="$T/old-sv"
mkdir -p "$OLD/.claude-plugin" "$OLD/skills/brief"
printf '{ "name": "sv" }\n' > "$OLD/.claude-plugin/plugin.json"
rm "$S/brief" && ln -s "$OLD/skills/brief" "$S/brief"
rm "$S/plan" && mkdir "$S/plan" && echo mine > "$S/plan/SKILL.md"
mkdir -p "$T/elsewhere/review"
rm "$S/review" && ln -s "$T/elsewhere/review" "$S/review"
out="$("$SV" install 2>&1)" && fail "install should report what it left alone: $out"
expect "updated   $S/brief"
expect "left alone $S/plan"
expect "left alone $S/review"
[ "$(readlink "$S/brief")" = "$ROOT/skills/brief" ] || fail "own link not updated"
[ "$(cat "$S/plan/SKILL.md")" = mine ] && [ ! -L "$S/plan" ] || fail "a real folder was touched"
[ "$(readlink "$S/review")" = "$T/elsewhere/review" ] || fail "a foreign link was touched"
[ -d "$OLD/skills/brief" ] && [ -d "$T/elsewhere/review" ] || fail "install deleted a link target"
rm "$S/plan/SKILL.md" "$S/review" && rmdir "$S/plan"

# A real file at ~/.local/bin/sv-harness stays.
rm "$HOME/.local/bin/sv-harness" && echo mine > "$HOME/.local/bin/sv-harness"
out="$("$SV" install 2>&1)" && fail "install should report the real sv-harness file: $out"
expect "left alone $HOME/.local/bin/sv-harness"
[ "$(cat "$HOME/.local/bin/sv-harness")" = mine ] || fail "a real sv-harness file was overwritten"
rm "$HOME/.local/bin/sv-harness"

# A link of ours whose skill is gone is reported and stays.
ln -s "$ROOT/skills/gone-skill" "$S/gone-skill"
out="$("$SV" install 2>&1)" || true
expect "dangling  $S/gone-skill"
[ -L "$S/gone-skill" ] || fail "a dangling link was removed"
rm "$S/gone-skill"

# A link of ours to an sv-harness that is gone is reported and stays.
mv "$PRO/bin/sv-harness" "$T/sv-harness.away"
rm "$HOME/.local/bin/sv-harness" && ln -s "$PRO/bin/sv-harness" "$HOME/.local/bin/sv-harness"
out="$("$SV" install 2>&1)" || true
expect "dangling  $HOME/.local/bin/sv-harness"
[ -L "$HOME/.local/bin/sv-harness" ] || fail "a dangling sv-harness link was removed"

# nono profile: default folder, then XDG_CONFIG_HOME; a real file stays.
out="$("$SV" install nono)" || fail "install nono failed: $out"
[ "$(readlink "$HOME/.config/nono/profiles/solidvibes.json")" = "$ROOT/profiles/solidvibes.json" ] || fail "profile not linked"
out="$("$SV" install nono)" || fail "second install nono failed: $out"
expect "ok "
mkdir -p "$T/xdg/nono/profiles" && echo '{}' > "$T/xdg/nono/profiles/solidvibes.json"
out="$(XDG_CONFIG_HOME="$T/xdg" "$SV" install nono 2>&1)" && fail "a real profile file should be left alone"
[ "$(cat "$T/xdg/nono/profiles/solidvibes.json")" = '{}' ] || fail "a real profile file was overwritten"

out="$("$SV" install bogus 2>&1)" && fail "an unknown target should fail"
cd "$T"
