# solidvibes doctor [dir]
#   Read-only health check of a project; never fixes. Checks:
#   - the Factory contract in AGENTS.md parses and has every field
#   - generated files and AGENTS.md blocks still match their hash in .solidvibes/manifest.json
#   - the contract's harness: none, command missing, or `status --json` answering
#   - every .claude/skills link resolves
#   - no `## Factory` left in CLAUDE.md
#   Exit 1 when anything is a problem.

DOCTOR_FIELDS="layers checks codegen run plans docs rules risk ships sandbox stack harness"
DOCTOR_PROBLEMS=0

doctor_ok() { printf '  ok       %s\n' "$1"; }
doctor_note() { printf '  note     %s\n' "$1"; }
doctor_problem() {
  printf '  problem  %s\n' "$1"
  DOCTOR_PROBLEMS=$((DOCTOR_PROBLEMS + 1))
}

doctor_hash() {
  if command -v shasum >/dev/null 2>&1; then shasum -a 256; else sha256sum; fi | cut -d' ' -f1
}

# Counts `## Factory` headings outside code fences.
doctor_factory_count() { # <file>
  awk '
    { line = $0; sub(/[ \t\r]+$/, "", line) }
    line ~ /^```/ { fence = !fence; next }
    !fence && line == "## Factory" { n++ }
    END { print n + 0 }' "$1"
}

doctor_contract() {
  local dir="$1" field missing=""
  echo "contract"
  if [ ! -f "$dir/AGENTS.md" ]; then
    doctor_problem "no AGENTS.md; run solidvibes init"
    return
  fi
  if ! contract_file "$dir" >/dev/null; then
    doctor_problem "AGENTS.md has no ## Factory; the interview skill drafts one"
    return
  fi
  for field in $DOCTOR_FIELDS; do
    contract_field "$dir" "$field" >/dev/null || missing="$missing $field"
  done
  if [ -n "$missing" ]; then
    doctor_problem "the contract has no:$missing (spec: .solidvibes/factory-contract.md)"
  else
    doctor_ok "AGENTS.md ## Factory has every field"
  fi
  if contract_field "$dir" checks >/dev/null; then
    for field in fast full; do
      contract_checks "$dir" "$field" >/dev/null || doctor_problem "checks has no $field: \`<command>\`"
    done
  fi
}

doctor_manifest() {
  local dir="$1" manifest="$1/.solidvibes/manifest.json" line path block hash actual n=0 before="$DOCTOR_PROBLEMS"
  echo "generated files"
  if [ ! -f "$manifest" ]; then
    doctor_problem "no .solidvibes/manifest.json; run solidvibes init"
    return
  fi
  while IFS= read -r line; do
    case "$line" in *'"path": '*'"hash": '*) ;; *) continue ;; esac
    path="$(printf '%s' "$line" | sed 's/.*"path": "\([^"]*\)".*/\1/')"
    hash="$(printf '%s' "$line" | sed 's/.*"hash": "sha256:\([0-9a-f]*\)".*/\1/')"
    block=""
    case "$line" in *'"block": '*) block="$(printf '%s' "$line" | sed 's/.*"block": "\([^"]*\)".*/\1/')" ;; esac
    n=$((n + 1))
    if [ ! -f "$dir/$path" ]; then
      doctor_problem "$path is missing; solidvibes init writes it again"
      continue
    fi
    if [ -n "$block" ]; then
      actual="$(awk -v b="<!-- solidvibes:begin $block -->" -v e="<!-- solidvibes:end $block -->" '
        $0 == b { on = 1; found = 1 } on { print } on && $0 == e { on = 0 }
        END { exit !found }' "$dir/$path" | doctor_hash)"
      if ! grep -qxF "<!-- solidvibes:begin $block -->" "$dir/$path"; then
        doctor_problem "$path: the $block block is gone; solidvibes init adds it again"
      elif [ "$actual" != "$hash" ]; then
        doctor_problem "$path: the $block block was edited by hand; solidvibes init replaces it, so move the change outside the markers"
      fi
    else
      actual="$(doctor_hash < "$dir/$path")"
      [ "$actual" = "$hash" ] || doctor_problem "$path was edited by hand; solidvibes init replaces it, so move the change into a seeded file or the project's own skills"
    fi
  done < "$manifest"
  [ "$DOCTOR_PROBLEMS" != "$before" ] || doctor_ok "all $n generated entries match the manifest"
}

doctor_harness() {
  local dir="$1" value cmd path out code=0
  echo "harness"
  value="$(contract_field "$dir" harness 2>/dev/null)" || { doctor_note "no harness field in the contract"; return; }
  if [ "$value" = none ]; then
    doctor_ok "harness: none (verify uses the contract's checks and run)"
    return
  fi
  cmd="$(printf '%s' "$value" | tr -d '`' | awk '{ print $1 }')"
  path="$(cd "$dir" && command -v "$cmd" 2>/dev/null || true)"
  if [ -z "$path" ]; then
    doctor_problem "$cmd not installed: run \`solidvibes install\`"
    return
  fi
  out="$(cd "$dir" && "$path" status --json 2>/dev/null)" || code=$?
  if [ "$code" -ne 0 ]; then
    doctor_problem "$cmd status --json exited $code"
  else
    case "$(printf '%s' "$out" | tr -d '[:space:]' | cut -c1)" in
      '{'|'[') doctor_ok "$cmd status --json answers" ;;
      *) doctor_problem "$cmd status --json printed no JSON" ;;
    esac
  fi
}

doctor_links() {
  local dir="$1" link n=0 before="$DOCTOR_PROBLEMS"
  echo "agent links"
  if [ ! -d "$dir/.claude/skills" ]; then
    doctor_ok "no .claude/skills folder"
    return
  fi
  for link in "$dir"/.claude/skills/* "$dir"/.claude/skills/.[!.]*; do
    [ -L "$link" ] || continue
    n=$((n + 1))
    [ -e "$link" ] || doctor_problem ".claude/skills/$(basename "$link") points to $(readlink "$link"), which does not exist"
  done
  [ "$DOCTOR_PROBLEMS" != "$before" ] || doctor_ok "all $n .claude/skills links resolve"
}

doctor_claude_md() {
  local dir="$1"
  echo "CLAUDE.md"
  if [ ! -f "$dir/CLAUDE.md" ]; then
    doctor_ok "none (Claude Code reads AGENTS.md)"
  elif [ "$(doctor_factory_count "$dir/CLAUDE.md")" != 0 ]; then
    doctor_problem "CLAUDE.md holds a ## Factory; the skills read it from AGENTS.md only (the interview skill moves it on your yes)"
  else
    doctor_ok "no ## Factory in CLAUDE.md"
  fi
}

cli_doctor() {
  local dir="${1:-.}"
  [ -d "$dir" ] || { echo "error: not a directory: $dir" >&2; return 1; }
  dir="$(cd "$dir" && pwd -P)"
  # shellcheck source=lib/contract.sh
  source "$SOLIDVIBES_ROOT/lib/contract.sh"

  echo "solidvibes doctor: $dir"
  doctor_contract "$dir"
  doctor_manifest "$dir"
  doctor_harness "$dir"
  doctor_links "$dir"
  doctor_claude_md "$dir"

  if [ "$DOCTOR_PROBLEMS" -gt 0 ]; then
    echo "doctor: $DOCTOR_PROBLEMS problem(s)"
    return 1
  fi
  echo "doctor: ok"
}
