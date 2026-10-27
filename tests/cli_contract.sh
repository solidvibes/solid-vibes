#!/usr/bin/env bash
# lib/contract.sh: finds `## Factory` in AGENTS.md, reads fields, checks commands and sandbox paths.
set -euo pipefail

REPO="$(cd "$(dirname "$0")/.." && pwd -P)"
# shellcheck source=lib/contract.sh
source "$REPO/lib/contract.sh"
T="$(mktemp -d)"
trap 'rm -rf "$T"' EXIT

fail() { echo "FAIL: $*" >&2; exit 1; }
expect() { [ "$2" = "$3" ] || fail "$1: expected [$3], got [$2]"; }

mkdir -p "$T/none" "$T/proj" "$T/home/.cache" "$T/home/Application Support" "$T/sdk"
contract_file "$T/none" >/dev/null && fail "no AGENTS.md should mean no contract"
printf '# Project\n\nNo contract here.\n' > "$T/none/AGENTS.md"
contract_file "$T/none" >/dev/null && fail "AGENTS.md without ## Factory should mean no contract"

cat > "$T/proj/AGENTS.md" <<'MD'
# Project

```markdown
## Factory
- **checks** — fast: `decoy` · full: `decoy`
```

## Factory

- **layers** — page → cubit → repository
- **checks** — fast: `make lint` · full: `make lint && make test` · needs `make` on PATH
- **codegen** — none
- **stack** — `docs/stack.md` (stack-example 1.0.0)
- **harness** — `sv-harness` · levels: unit · targets: web
- **sandbox**
  - read: `$SDK_ROOT`
  - read: `${SDK_ROOT}/bin`
  - write: `~/.cache`
  - write: `~/Application Support`
  - write: `~/.missing`
  - read: `$UNSET_SOLIDVIBES_VAR/x`

## After

- **risk** — not in the contract
MD

expect "contract_file" "$(contract_file "$T/proj")" "$T/proj/AGENTS.md"
expect "layers" "$(contract_field "$T/proj" layers)" "page → cubit → repository"
expect "codegen" "$(contract_field "$T/proj" codegen)" "none"
expect "stack" "$(contract_field "$T/proj" stack)" '`docs/stack.md` (stack-example 1.0.0)'
expect "harness" "$(contract_field "$T/proj" harness)" '`sv-harness` · levels: unit · targets: web'
expect "checks fast" "$(contract_checks "$T/proj" fast)" "make lint"
expect "checks full" "$(contract_checks "$T/proj" full)" "make lint && make test"
contract_field "$T/proj" risk >/dev/null && fail "a field after the section must not count"
contract_field "$T/proj" ships >/dev/null && fail "a missing field must fail"

mkdir -p "$T/sdk/bin"
sandbox="$(HOME="$T/home" SDK_ROOT="$T/sdk" contract_sandbox "$T/proj" 2>"$T/warn")"
expect "sandbox" "$sandbox" "read $T/sdk
read $T/sdk/bin
write $T/home/.cache
write $T/home/Application Support"
grep -q 'not a directory: ~/.missing' "$T/warn" || fail "missing sandbox path should warn"
grep -q 'variable not set: $UNSET_SOLIDVIBES_VAR/x' "$T/warn" || fail "unset variable should warn"

expect "this repo's fast checks" "$(contract_checks "$REPO" fast)" \
  'bash -n bin/solidvibes lib/*.sh scripts/*.sh && bin/solidvibes lint . && scripts/strip-check.sh'
expect "this repo's sandbox" "$(contract_field "$REPO" sandbox)" "none"
# A real owner contract, read from a source repo's origin/main CLAUDE.md into a temp AGENTS.md.
# The repo comes from the environment (this repo never names it); its values are never printed.
SRC="${SOLIDVIBES_TEST_CONTRACT_REPO:-}"
if [ -z "$SRC" ] || ! git -C "$SRC" cat-file -e origin/main:CLAUDE.md 2>/dev/null; then
  echo "note: SOLIDVIBES_TEST_CONTRACT_REPO not set or has no origin/main:CLAUDE.md; real-contract parse skipped"
else
  mkdir "$T/real"
  { echo "# Project"; echo
    git -C "$SRC" show origin/main:CLAUDE.md | awk '
      /^```/ { fence = !fence }
      !fence && /^## / { on = ($0 ~ /^## Factory[ \t]*$/) }
      on { print }'
  } > "$T/real/AGENTS.md"
  contract_file "$T/real" >/dev/null || fail "real contract: no ## Factory found"
  for field in layers checks codegen run plans docs rules risk ships; do
    [ -n "$(contract_field "$T/real" "$field")" ] || fail "real contract: $field empty or missing"
  done
  contract_field "$T/real" sandbox >/dev/null || fail "real contract: no sandbox field"
  for kind in fast full; do
    [ -n "$(contract_checks "$T/real" "$kind")" ] || fail "real contract: no checks.$kind command"
  done
  contract_sandbox "$T/real" > "$T/real.sandbox" 2> "$T/real.warn" || fail "real contract: sandbox did not parse"
  [ "$(cat "$T/real.sandbox" "$T/real.warn" | wc -l)" -gt 0 ] || [ "$(contract_field "$T/real" sandbox)" = none ] \
    || fail "real contract: sandbox names no path and is not none"
  echo "real contract: $(contract_section "$T/real" | grep -c '^- \*\*') fields, $(wc -l < "$T/real.sandbox" | tr -d ' ') sandbox paths found, $(wc -l < "$T/real.warn" | tr -d ' ') skipped"
fi
echo "cli_contract: ok"
