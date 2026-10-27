#!/usr/bin/env bash
# Runs every tests/*.sh but this one and routing.sh (owner-run: it needs a real agent). Each test uses its own temp dir and cleans up.
set -uo pipefail

cd "$(dirname "$0")/.."
failed=0
for t in tests/*.sh; do
  [ "$t" = tests/run.sh ] && continue
  [ "$t" = tests/routing.sh ] && continue
  if out="$(bash "$t" 2>&1)"; then
    echo "pass  $t"
  else
    echo "FAIL  $t"
    printf '%s\n' "$out" | sed 's/^/      /'
    failed=$((failed + 1))
  fi
done
[ "$failed" -eq 0 ] || { echo "$failed test file(s) failed"; exit 1; }
echo "all tests passed"
