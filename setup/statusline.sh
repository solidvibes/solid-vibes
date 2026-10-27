#!/usr/bin/env bash
# Solid Vibes status bar for Claude Code. Reads the session JSON on stdin and prints two lines:
#   folder · branch
#   model  ▓▓▓░░░░░░░ 30%  $1.23  12m   [→ time for a fresh start: /clear]
# Bash 3.2, sed only, no jq. Installed by `solidvibes statusline --install`.

export LC_ALL=C
input="$(cat | tr -d '\n\r')"

# obj <json> <key>: the object at <key>, up to two levels of nesting kept; empty when absent or null.
O='\{([^{}]|\{([^{}]|\{[^{}]*\})*\})*\}'
obj() {
  printf '%s' "$1" | sed -nE 's/.*"'"$2"'"[[:space:]]*:[[:space:]]*('"$O"').*/\1/p'
}
# num <json> <key>: a number, or empty when absent or null.
num() {
  printf '%s' "$1" | sed -nE 's/.*"'"$2"'"[[:space:]]*:[[:space:]]*(-?[0-9][0-9.eE+-]*).*/\1/p'
}
# int <number>: its whole part, or empty when it isn't a plain decimal.
int() {
  case "$1" in ''|.*|*[!0-9.]*) ;; *) echo "${1%%.*}" ;; esac
}
# str <json> <key>: a string value.
str() {
  printf '%s' "$1" | sed -nE 's/.*"'"$2"'"[[:space:]]*:[[:space:]]*"(([^"\\]|\\.)*)".*/\1/p'
}

grey=$'\033[90m' warn=$'\033[33m' off=$'\033[0m'

cw="$(obj "$input" context_window)"
cu="$(obj "$cw" current_usage)"
top="$(printf '%s' "$cw" | sed -E 's/"current_usage"[[:space:]]*:[[:space:]]*('"$O"'|null)//')"

dir="$(str "$(obj "$input" workspace)" current_dir)"
[ -n "$dir" ] || dir="$(str "$input" cwd)"
model="$(str "$(obj "$input" model)" display_name)"
cost_obj="$(obj "$input" cost)"
cost="$(num "$cost_obj" total_cost_usd)"
ms="$(int "$(num "$cost_obj" total_duration_ms)")"
size="$(int "$(num "$top" context_window_size)")"
pct="$(int "$(num "$top" used_percentage)")"

used=""
if [ -n "$cu" ]; then
  used=0
  for k in input_tokens cache_creation_input_tokens cache_read_input_tokens; do
    n="$(int "$(num "$cu" "$k")")"
    used=$((used + ${n:-0}))
  done
fi
if [ -z "$pct" ] && [ -n "$used" ] && [ "${size:-0}" -gt 0 ]; then pct=$((used * 100 / size)); fi
if [ -z "$used" ] && [ -n "$pct" ] && [ "${size:-0}" -gt 0 ]; then used=$((pct * size / 100)); fi

line1="${dir##*/}"
if [ -n "$dir" ]; then
  branch="$(git -C "$dir" branch --show-current 2>/dev/null)"
  [ -z "$branch" ] || line1="$line1${grey} · $branch${off}"
fi

if [ -n "$pct" ]; then
  filled=$(((pct + 5) / 10))
  [ "$filled" -le 10 ] || filled=10
  bar=""
  i=0
  while [ "$i" -lt 10 ]; do
    if [ "$i" -lt "$filled" ]; then bar="${bar}▓"; else bar="${bar}░"; fi
    i=$((i + 1))
  done
  ctx="$bar $pct%"
else
  ctx="░░░░░░░░░░ –"
fi

line2="${model:-–}  $ctx  \$$(printf '%.2f' "${cost:-0}" 2>/dev/null || echo 0.00)"
if [ -n "$ms" ]; then
  m=$((ms / 60000))
  if [ "$m" -ge 60 ]; then line2="$line2  $((m / 60))h$(printf '%02d' $((m % 60)))m"; else line2="$line2  ${m}m"; fi
fi
line2="${grey}${line2}${off}"
if { [ -n "$used" ] && [ "$used" -gt 400000 ]; } || { [ -n "$pct" ] && [ "$pct" -ge 80 ]; }; then
  line2="$line2  ${warn}→ time for a fresh start: /clear${off}"
fi

printf '%s\n%s\n' "$line1" "$line2"
