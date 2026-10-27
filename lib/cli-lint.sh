# solidvibes lint <dir>
#   Every SKILL.md: frontmatter `name` equals its folder; `description` present, at most
#   1024 characters, with a "Use when" trigger; no ~/.claude or /Users/ paths in the skill's files.
#   Every JSON manifest (.claude-plugin/*.json, .solidvibes/*.json) parses.
#   Every skill named in skills/ ("the `x` skill" in any .md, the routing table of the AGENTS.md
#   template) exists in skills/ here or in Solid Vibes itself; `harness` and `stack-*` are exempt.

LINT_PROBLEMS=0

lint_problem() {
  echo "$1: $2"
  LINT_PROBLEMS=$((LINT_PROBLEMS + 1))
}

# Prints `name<TAB>…` and `description<TAB>…` from a SKILL.md's frontmatter.
lint_frontmatter() {
  awk '
    function clean(v) {
      sub(/^[ \t]+/, "", v); sub(/[ \t]+$/, "", v)
      if (v ~ /^".*"$/ || v ~ /^\047.*\047$/) v = substr(v, 2, length(v) - 2)
      return v
    }
    NR == 1 { if ($0 != "---") exit; next }
    $0 == "---" { exit }
    /^[A-Za-z_-]+:/ {
      key = $0; sub(/:.*/, "", key)
      val = $0; sub(/^[^:]*:/, "", val); val = clean(val)
      if (val ~ /^[>|][-+]?$/) val = ""
      v[key] = val; cur = key; next
    }
    /^[ \t]/ && cur != "" {
      line = clean($0)
      v[cur] = (v[cur] == "") ? line : v[cur] " " line
    }
    END {
      if ("name" in v) print "name\t" v["name"]
      if ("description" in v) print "description\t" v["description"]
    }
  ' "$1"
}

lint_skill() {
  local file="$1" rel="$2" folder fm name desc hits
  folder="$(basename "$(dirname "$file")")"
  fm="$(lint_frontmatter "$file")"
  name="$(printf '%s\n' "$fm" | sed -n 's/^name	//p')"
  desc="$(printf '%s\n' "$fm" | sed -n 's/^description	//p')"

  if [ -z "$name" ]; then
    lint_problem "$rel" "frontmatter has no name"
  elif [ "$name" != "$folder" ]; then
    lint_problem "$rel" "name \"$name\" does not match its folder \"$folder\""
  fi
  if [ -z "$desc" ]; then
    lint_problem "$rel" "frontmatter has no description"
  else
    [ "${#desc}" -le 1024 ] || lint_problem "$rel" "description is ${#desc} characters, over 1024"
    case "$(printf '%s' "$desc" | tr '[:upper:]' '[:lower:]')" in
      *"use when"*) ;;
      *) lint_problem "$rel" "description has no \"Use when\" trigger" ;;
    esac
  fi

  hits="$(cd "$(dirname "$file")" && grep -rnIE '~/\.claude|/Users/' . 2>/dev/null | cut -d: -f1,2 || true)"
  while IFS= read -r hit; do
    [ -n "$hit" ] || continue
    lint_problem "$(dirname "$rel")/${hit#./}" "owner path (~/.claude or /Users/)"
  done <<< "$hits"
}

lint_json() {
  local file="$1" rel="$2"
  if command -v jq >/dev/null 2>&1; then
    jq empty "$file" >/dev/null 2>&1 || lint_problem "$rel" "JSON does not parse"
  elif command -v python3 >/dev/null 2>&1; then
    python3 -c 'import json, sys; json.load(open(sys.argv[1]))' "$file" >/dev/null 2>&1 \
      || lint_problem "$rel" "JSON does not parse"
  else
    echo "warning: neither jq nor python3 found; $rel not checked" >&2
  fi
}

# Prints `file:line<TAB>name` for each skill named under <dir>/skills and <dir>/setup.
lint_named_skills() { # <dir>
  local tpl="setup/templates/AGENTS.md"
  (cd "$1" && grep -rnoE '[Tt]he `[a-z0-9-]+` skill' --include='*.md' skills setup 2>/dev/null \
    | sed -E 's/^([^:]*:[0-9]+):.*`([a-z0-9-]+)`.*/\1	\2/' || true)
  [ -f "$1/$tpl" ] || return 0
  awk -v f="$tpl" '
    $0 == "<!-- solidvibes:begin routing -->" { on = 1; next }
    $0 == "<!-- solidvibes:end routing -->" { on = 0 }
    on && /^\|/ {
      cell = $0; sub(/\|[ \t]*$/, "", cell); sub(/.*\|/, "", cell)
      while (match(cell, /`[a-z0-9-]+`/)) {
        print f ":" NR "\t" substr(cell, RSTART + 1, RLENGTH - 2)
        cell = substr(cell, RSTART + RLENGTH)
      }
    }' "$1/$tpl"
}

lint_skills_exist() { # <dir>
  local where name
  [ -d "$1/skills" ] || return 0
  while IFS='	' read -r where name; do
    [ -n "$name" ] || continue
    case "$name" in harness|stack-*) continue ;; esac
    [ -f "$1/skills/$name/SKILL.md" ] || [ -f "$SOLIDVIBES_ROOT/skills/$name/SKILL.md" ] \
      || lint_problem "$where" "names the skill \"$name\", which does not exist in skills/"
  done < <(lint_named_skills "$1" | sort -u)
}

cli_lint() {
  local dir="${1:-}" skills=0 manifests=0 file rel
  [ -n "$dir" ] || { echo "usage: solidvibes lint <dir>" >&2; return 1; }
  [ -d "$dir" ] || { echo "error: not a directory: $dir" >&2; return 1; }
  dir="$(cd "$dir" && pwd -P)"

  while IFS= read -r file; do
    [ -n "$file" ] || continue
    rel="${file#"$dir"/}"
    lint_skill "$file" "$rel"
    skills=$((skills + 1))
  done < <(find "$dir" \( -name .git -o -name node_modules -o -path "$dir/tests/.tmp" \) -prune \
    -o -type f -name SKILL.md -print | sort)

  lint_skills_exist "$dir"

  for file in "$dir"/.claude-plugin/*.json "$dir"/.solidvibes/*.json; do
    [ -f "$file" ] || continue
    lint_json "$file" "${file#"$dir"/}"
    manifests=$((manifests + 1))
  done

  if [ "$LINT_PROBLEMS" -gt 0 ]; then
    echo "lint: $LINT_PROBLEMS problem(s)"
    return 1
  fi
  echo "lint: ok ($skills skills, $manifests manifests)"
}
