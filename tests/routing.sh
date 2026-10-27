#!/usr/bin/env bash
# Routing eval. Owner-run: it calls a real agent once per case, so tests/run.sh skips it.
#
#   tests/routing.sh [cases-file]
#
# Makes a temp project with `solidvibes init` and a filled-in intent (a described project), then for each case in tests/routing/cases.txt
# asks the agent which route AGENTS.md sends the request to, and scores the answer.
# Prints the share of right answers and exits 1 under 90 %.
#
# Agent: $SOLIDVIBES_ROUTING_AGENT, default `claude -p`. Any command that reads the prompt
# on stdin and prints its answer. It runs inside the temp project, so it reads its AGENTS.md.
# Cost: one agent call per case.

set -uo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd -P)"
CASES="${1:-$ROOT/tests/routing/cases.txt}"
AGENT="${SOLIDVIBES_ROUTING_AGENT:-claude -p}"
THRESHOLD=90
ROUTES="interview design brainstorm brief plan several review idea release hello bye update trivial"

T="$(mktemp -d)"
trap 'rm -rf "$T"' EXIT
"$ROOT/bin/solidvibes" init --profile "$ROOT/setup/profiles/blank" "$T/project" >/dev/null || {
  echo "routing: could not set up the temp project" >&2
  exit 1
}
cat > "$T/project/docs/intent.md" <<'INTENT'
# Intent

## The problem

A family-run shop keeps customer orders and invoices on paper and loses track of who still owes money.

## Who it is for

The shop's two owners and their customers. Not for other shops.

## Never

Never share a customer's details with anyone outside the shop.
INTENT

total=0
right=0
while IFS="$(printf '\t')" read -r request expected; do
  case "$request" in ''|'#'*) continue ;; esac
  prompt="Do not do the task below and do not ask questions. Read this project's AGENTS.md, section 'How every request is handled', and docs/intent.md, which shows this project is already described. Treat the request as a change to this project unless it starts a different, new project. Say which route that section sends the request to.

Answer with exactly one word from this list and nothing else: $ROUTES.
Use 'several' when the request holds several independent ideas, 'idea' when it is written to the ideas folder with no plan, and 'trivial' when the section says to just do it or to answer directly.

Request: $request"
  answer="$(cd "$T/project" && printf '%s\n' "$prompt" | $AGENT 2>/dev/null | grep -v '^[[:space:]]*$' | tail -n 1 | tr 'A-Z' 'a-z' | tr -d '`*."[:space:]')"
  total=$((total + 1))
  if [ "$answer" = "$expected" ]; then
    right=$((right + 1))
  else
    printf 'miss  expected %-14s got %-14s %s\n' "$expected" "${answer:-<nothing>}" "$request"
  fi
done < "$CASES"

[ "$total" -gt 0 ] || { echo "routing: no cases in $CASES" >&2; exit 1; }
pct=$((right * 100 / total))
echo "routing: $right of $total right ($pct %), needs $THRESHOLD %"
[ "$pct" -ge "$THRESHOLD" ] || exit 1
