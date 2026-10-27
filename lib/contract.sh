# Factory contract parser. Sourced, never run.
# The contract is the `## Factory` section of a project's AGENTS.md:
# one bullet per field, `- **field** — value`; `sandbox` has `- read: <path>` / `- write: <path>` sub-bullets.

# Prints the path of the AGENTS.md that holds the contract, or fails.
contract_file() {
  local f="$1/AGENTS.md"
  [ -f "$f" ] && contract_section "$1" | grep -q . && echo "$f"
}

# Prints the `## Factory` section's lines, outside code fences, without the heading.
contract_section() {
  [ -f "$1/AGENTS.md" ] || return 1
  awk '
    /^```/ { fence = !fence; next }
    fence { next }
    /^## / { factory = ($0 ~ /^## Factory[ \t]*$/); next }
    factory { print }
  ' "$1/AGENTS.md"
}

# Prints a field's value. Fails when the field is missing.
contract_field() {
  local dir="$1" field="$2" out
  out="$(contract_section "$dir" | awk -v f="$field" '
    index($0, "- **" f "**") == 1 {
      found = 1
      v = substr($0, length("- **" f "**") + 1)
      sub(/^[ \t]*(—|--|-)?[ \t]*/, "", v)
      print v
      exit
    }
    END { exit !found }
  ')" || return 1
  printf '%s\n' "$out"
}

# Prints the fast or full checks command: the code span after `fast:` or `full:`.
contract_checks() {
  local value
  value="$(contract_field "$1" checks)" || return 1
  case "$value" in
    *"$2: \`"*) ;;
    *) return 1 ;;
  esac
  value="${value#*"$2: \`"}"
  printf '%s\n' "${value%%\`*}"
}

# Expands a leading ~ and $VAR / ${VAR}. Fails on an unset variable.
contract_expand() {
  local p="$1" out="" match name
  case "$p" in
    "~") p="$HOME" ;;
    "~/"*) p="$HOME/${p#\~/}" ;;
  esac
  while [[ "$p" =~ \$\{?([A-Za-z_][A-Za-z0-9_]*)\}? ]]; do
    match="${BASH_REMATCH[0]}"
    name="${BASH_REMATCH[1]}"
    [ -n "${!name:-}" ] || return 1
    out="$out${p%%"$match"*}${!name}"
    p="${p#*"$match"}"
  done
  printf '%s\n' "$out$p"
}

# Prints `read <dir>` / `write <dir>` per sandbox sub-bullet, expanded.
# A missing directory or unset variable is skipped with a warning on stderr.
contract_sandbox() {
  local kind raw path
  while read -r kind raw; do
    if ! path="$(contract_expand "$raw")"; then
      echo "warning: sandbox $kind path skipped, variable not set: $raw" >&2
      continue
    fi
    if [ ! -d "$path" ]; then
      echo "warning: sandbox $kind path skipped, not a directory: $raw" >&2
      continue
    fi
    printf '%s %s\n' "$kind" "$path"
  done < <(contract_section "$1" | awk '
    /^- / { sandbox = ($0 ~ /^- \*\*sandbox\*\*/); next }
    sandbox && /^[ \t]+- (read|write):/ {
      sub(/^[ \t]+- /, ""); gsub(/`/, "")
      kind = $0; sub(/:.*/, "", kind)
      path = $0; sub(/^[^:]*:[ \t]*/, "", path); sub(/[ \t]+$/, "", path)
      print kind, path
    }')
}
