#!/usr/bin/env bash
# The status bar script: sample JSON → expected lines, null current_usage, a 200k window, 410k used
# → nudge, all with no jq on PATH. `statusline --check/--install` in a temp HOME: never writes
# settings, never copies over a foreign statusLine; `hello --hook` refreshes only an installed copy.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd -P)"
SV="$ROOT/bin/solidvibes"
T="$(mktemp -d)"
trap 'rm -rf "$T"' EXIT
T="$(cd "$T" && pwd -P)"

fail() { echo "FAIL: $*" >&2; exit 1; }

export HOME="$T/home" XDG_DATA_HOME="$T/data" CLAUDE_CONFIG_DIR="$T/claude"
export GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_NOSYSTEM=1
mkdir -p "$HOME"

# A PATH with only what the script needs, so jq can't be found.
B="$T/bin"
mkdir "$B"
for c in cat tr sed git; do ln -s "$(command -v "$c")" "$B/$c"; done
BASH_BIN="$(command -v bash)"
PATH="$B" command -v jq >/dev/null 2>&1 && fail "jq still on the test PATH"

esc=$'\033'
bar() { printf '%s' "$1" | PATH="$B" "$BASH_BIN" "$ROOT/setup/statusline.sh" | sed "s/${esc}\[[0-9;]*m//g"; }

P="$T/my-app"
mkdir "$P" && git init -q -b main "$P"

out="$(bar '{"cwd":"'"$P"'","model":{"id":"x","display_name":"Opus"},"workspace":{"current_dir":"'"$P"'","repo":{"host":"example.com","owner":"o","name":"n"}},"cost":{"total_cost_usd":1.234,"total_duration_ms":4500000},"context_window":{"total_input_tokens":60000,"context_window_size":200000,"used_percentage":30,"current_usage":{"input_tokens":40000,"output_tokens":900,"cache_creation_input_tokens":5000,"cache_read_input_tokens":15000}},"rate_limits":{"five_hour":{"used_percentage":95}}}')"
[ "$out" = "my-app · main
Opus  ▓▓▓░░░░░░░ 30%  \$1.23  1h15m" ] || fail "sample: $out"

out="$(bar '{"model":{"display_name":"Opus"},"workspace":{"current_dir":"'"$P"'"},"cost":{"total_cost_usd":0,"total_duration_ms":2000},"context_window":{"context_window_size":200000,"used_percentage":null,"current_usage":null}}')"
[ "$out" = "my-app · main
Opus  ░░░░░░░░░░ –  \$0.00  0m" ] || fail "null current_usage: $out"

out="$(bar '{"model":{"display_name":"Sonnet"},"workspace":{"current_dir":"'"$T"'/elsewhere"},"cost":{"total_cost_usd":0.5,"total_duration_ms":600000},"context_window":{"context_window_size":200000,"current_usage":{"input_tokens":1000,"cache_read_input_tokens":169000}}}')"
[ "$out" = "elsewhere
Sonnet  ▓▓▓▓▓▓▓▓▓░ 85%  \$0.50  10m  → time for a fresh start: /clear" ] || fail "200k window, no used_percentage: $out"

out="$(bar '{"model":{"display_name":"Opus"},"workspace":{"current_dir":"'"$P"'"},"cost":{"total_cost_usd":2,"total_duration_ms":60000},"context_window":{"context_window_size":1000000,"used_percentage":41,"current_usage":{"input_tokens":10000,"cache_creation_input_tokens":0,"cache_read_input_tokens":400000}}}')"
printf '%s\n' "$out" | sed -n 2p | grep -qF "41%  \$2.00  1m  → time for a fresh start: /clear" || fail "410k should nudge: $out"
out="$(bar '{"model":{"display_name":"Opus"},"context_window":{"context_window_size":1000000,"used_percentage":39,"current_usage":{"input_tokens":390000}}}')"
printf '%s\n' "$out" | grep -q "fresh start" && fail "390k in a 1M window should not nudge: $out"

out="$(bar '{ "model" : { "display_name" : "Opus 4.5 (1M context)" }, "workspace" : { "current_dir" : "'"$T"'/a b" }, "cost" : { "total_cost_usd" : 1.5e-7, "total_duration_ms" : 1.2e5 }, "context_window" : { "context_window_size" : 1000000, "used_percentage" : 30.7, "current_usage" : { "input_tokens" : 10, "cache_creation" : { "ephemeral_5m_input_tokens" : 1 }, "cache_read_input_tokens" : 5 } } }')"
[ "$out" = "a b
Opus 4.5 (1M context)  ▓▓▓░░░░░░░ 30%  \$0.00" ] || fail "spaces, nesting, decimals: $out"
err="$(printf '%s' '{"context_window":{"context_window_size":2e5,"used_percentage":3e1}}' | PATH="$B" "$BASH_BIN" "$ROOT/setup/statusline.sh" 2>&1 >/dev/null)"
[ -z "$err" ] || fail "scientific numbers must not error: $err"
out="$(printf '%s' '{"cost":{"total_cost_usd":1.234}}' | LC_ALL=de_DE.UTF-8 PATH="$B" "$BASH_BIN" "$ROOT/setup/statusline.sh" | sed "s/${esc}\[[0-9;]*m//g")"
printf '%s\n' "$out" | grep -qF "\$1.23" || fail "foreign locale: $out"

D="$XDG_DATA_HOME/solidvibes/statusline.sh"
S="$CLAUDE_CONFIG_DIR/settings.json"

out="$("$SV" statusline --check)"
printf '%s\n' "$out" | grep -qx "settings: $S" || fail "check names the settings file: $out"
printf '%s\n' "$out" | grep -qx "statusLine: none" || fail "check, no settings: $out"
printf '%s\n' "$out" | grep -qxF "entry: \"statusLine\": { \"type\": \"command\", \"command\": \"$D\", \"padding\": 0 }" || fail "entry: $out"
[ ! -e "$D" ] && [ ! -e "$S" ] || fail "check must write nothing"

"$SV" statusline --decline >/dev/null
out="$("$SV" statusline --check)"
printf '%s\n' "$out" | grep -qx "statusLine: declined" || fail "declined: $out"
printf '%s\n' "$out" | grep -q "^entry:" && fail "no entry after a no: $out"
[ ! -e "$S" ] || fail "decline must never write settings"

out="$("$SV" statusline --install)"
cmp -s "$ROOT/setup/statusline.sh" "$D" && [ -x "$D" ] || fail "install copies the script"
[ ! -e "$S" ] || fail "install must never write settings"
[ ! -e "$XDG_DATA_HOME/solidvibes/declined" ] || fail "install forgets a no"
printf '%s\n' "$out" | grep -qx "statusLine: none" || fail "after install: $out"

mkdir -p "$CLAUDE_CONFIG_DIR"
printf '{\n  "statusLine": { "type": "command", "command": "%s" }\n}\n' "$D" > "$S"
out="$("$SV" statusline --check)"
printf '%s\n' "$out" | grep -qx "statusLine: Solid Vibes" || fail "ours: $out"
printf '%s\n' "$out" | grep -q "^entry:" && fail "no entry when one is set: $out"

printf '{ "statusLine": { "type": "command", "command": "my-bar" } }\n' > "$S"
rm "$D"
out="$("$SV" statusline --install)"
printf '%s\n' "$out" | grep -qx "statusLine: set, not ours; leave it alone" || fail "other: $out"
[ ! -e "$D" ] || fail "install must not copy over a foreign statusLine"
grep -q '"my-bar"' "$S" || fail "settings changed"

Q="$T/project"
mkdir "$Q" && git init -q "$Q"
"$SV" init "$Q" >/dev/null
echo '{"source":"startup"}' | "$SV" hello --hook "$Q" >/dev/null
[ ! -e "$D" ] || fail "hook must not install a copy that isn't there"
mkdir -p "$(dirname "$D")" && echo old > "$D"
echo '{"source":"startup"}' | "$SV" hello --hook "$T/my-app" >/dev/null
[ "$(cat "$D")" = old ] || fail "hook must not refresh outside sv projects"
echo '{"source":"startup"}' | "$SV" hello --hook "$Q" >/dev/null
cmp -s "$ROOT/setup/statusline.sh" "$D" || fail "hook refreshes an installed copy"

echo "cli_statusline: ok"
