# solidvibes init [--profile <dir>] [--agents claude,codex,generic] <dir>
#   Sets up a project, or refreshes one. Two kinds of output:
#   - generated: .solidvibes/* (but the local handover.md and hello.state), docs/CONVENTIONS.md, AGENTS.md's marked blocks.
#     Rewritten every run, with a header naming the source and version. A file at a generated path that init did not make is skipped.
#   - seeded: AGENTS.md's other sections, docs/*, CHANGELOG.md. Created only if missing.
#   Plus `@AGENTS.md` in an existing CLAUDE.md, and .claude/skills/<name> links for Claude Code.
#   Idempotent: a second run changes nothing. Never deletes anything, and never writes through a link.

INIT_TOKEN="solidvibes:generated"
INIT_AGENTS_ALL="claude codex generic"

init_say() { printf '  %-10s %s\n' "$1" "$2"; }
init_count_up() { eval "INIT_N_$1=\$((INIT_N_$1 + 1))"; }

init_hash() {
  if command -v shasum >/dev/null 2>&1; then shasum -a 256 "$1"; else sha256sum "$1"; fi | cut -d' ' -f1
}

init_json_str() {
  local s="$1"
  s="${s//\\/\\\\}"
  printf '"%s"' "${s//\"/\\\"}"
}

# Prints a frontmatter value from a SKILL.md, quotes stripped.
init_fm() { # <file> <key>
  awk -v k="$2" '
    NR == 1 { if ($0 != "---") exit; next }
    $0 == "---" { exit }
    index($0, k ":") == 1 {
      v = substr($0, length(k) + 2); sub(/^[ \t]+/, "", v); sub(/[ \t\r]+$/, "", v)
      if (v ~ /^".*"$/ || v ~ /^\047.*\047$/) v = substr(v, 2, length(v) - 2)
      print v; exit
    }' "$1"
}

# Counts the lines equal to <line>, outside code fences, trailing whitespace ignored.
init_count() { # <file> <line>
  [ -f "$1" ] || { echo 0; return; }
  awk -v want="$2" '
    { line = $0; sub(/[ \t\r]+$/, "", line) }
    line ~ /^```/ { fence = !fence; next }
    !fence && line == want { n++ }
    END { print n + 0 }' "$1"
}

# Fills {{project}} and {{profile}}; a line that is only {{stack}} or {{contract}} becomes that profile file.
init_subst() { # <src> <out>
  INIT_PROJECT="$INIT_NAME" INIT_PROFILE="$INIT_PLABEL" \
  awk -v stackf="$INIT_PROFILE_DIR/stack.md" -v contractf="$INIT_PROFILE_DIR/contract.md" '
    function repl(s, from, to,   out, i) {
      out = ""
      while ((i = index(s, from)) > 0) { out = out substr(s, 1, i - 1) to; s = substr(s, i + length(from)) }
      return out s
    }
    function fill(s) { return repl(repl(s, "{{project}}", ENVIRON["INIT_PROJECT"]), "{{profile}}", ENVIRON["INIT_PROFILE"]) }
    function include(f,   l) { while ((getline l < f) > 0) print fill(l); close(f) }
    $0 == "{{stack}}" { include(stackf); next }
    $0 == "{{contract}}" { include(contractf); next }
    { print fill($0) }' "$1" > "$2"
}

# Adds the generated header to a rendered file, in the comment style its extension allows.
init_header() { # <rel> <label> <in> <out>
  local rel="$1" text="$INIT_TOKEN from $2. Made by solidvibes init; changes here are replaced the next time it runs."
  case "$rel" in
    *.md)
      awk -v h="<!-- $text -->" '
        NR == 1 && $0 == "---" { print; fm = 1; next }
        fm && $0 == "---" { print; print ""; print h; fm = 0; done = 1; next }
        fm { print; next }
        !done { print h; print ""; done = 1 }
        { print }
        END { if (!done) print h }' "$3" > "$4" ;;
    *.gitignore)
      { echo "# $text"; cat "$3"; } > "$4" ;;
    *)
      cp "$3" "$4" ;;
  esac
}

# True when a folder on the way to <rel> is a link or not a folder: writing there could land outside the project.
init_blocked() { # <rel>
  local p="" rest="$1"
  while case "$rest" in */*) true ;; *) false ;; esac; do
    p="${p:+$p/}${rest%%/*}"; rest="${rest#*/}"
    if [ -L "$INIT_DIR/$p" ] || { [ -e "$INIT_DIR/$p" ] && [ ! -d "$INIT_DIR/$p" ]; }; then return 0; fi
  done
  return 1
}

# A file is init's when it carries the header, or the last manifest lists it.
init_ours() { # <rel>
  head -n 40 "$INIT_DIR/$1" 2>/dev/null | grep -qF "$INIT_TOKEN" && return 0
  grep -qxF -- "$1" "$INIT_TMP/old-paths"
}

init_record() { # <rel> <block> <label> <version>
  printf '%s\t%s\t%s\t%s\tsha256:%s\n' "$1" "${2:--}" "$3" "$4" "$5" >> "$INIT_TMP/entries"
}

# Writes a rendered generated file: new → wrote, same → unchanged, init's → updated, someone else's → skipped.
init_generated() { # <rendered> <rel> <label> <version>
  local rendered="$1" rel="$2" dest="$INIT_DIR/$2"
  if init_blocked "$rel"; then
    init_say skipped "$rel (a folder on its path is a link or a file; left as it is)"; init_count_up skipped; return 0
  fi
  if [ -L "$dest" ] || { [ -e "$dest" ] && [ ! -f "$dest" ]; }; then
    init_say skipped "$rel (not a plain file; left as it is)"; init_count_up skipped; return 0
  fi
  if [ -f "$dest" ]; then
    if cmp -s "$rendered" "$dest"; then
      init_say unchanged "$rel"; init_count_up unchanged
    elif init_ours "$rel"; then
      cp "$rendered" "$dest"; init_say updated "$rel"; init_count_up written
    else
      init_say skipped "$rel (already exists and init did not make it; move it aside to let init write it)"
      init_count_up skipped; return 0
    fi
  else
    mkdir -p "$(dirname "$dest")"
    cp "$rendered" "$dest"; init_say wrote "$rel"; init_count_up written
  fi
  chmod 644 "$dest"
  init_record "$rel" "" "$3" "$4" "$(init_hash "$dest")"
}

# Renders <src> (substitution + header) and writes it as a generated file.
init_generate_from() { # <src> <rel> <label> <version>
  local tmp="$INIT_TMP/render"
  init_subst "$1" "$tmp.subst"
  init_header "$2" "$3" "$tmp.subst" "$tmp"
  init_generated "$tmp" "$2" "$3" "$4"
}

init_seed() { # <src> <rel>
  local dest="$INIT_DIR/$2"
  if [ -e "$dest" ] || [ -L "$dest" ]; then
    init_say kept "$2"; init_count_up kept; return 0
  fi
  if init_blocked "$2"; then
    init_say skipped "$2 (a folder on its path is a link or a file; left as it is)"; init_count_up skipped; return 0
  fi
  mkdir -p "$(dirname "$dest")"
  init_subst "$1" "$dest"
  init_say created "$2"; init_count_up created
}

# An empty folder gets a .gitkeep so git keeps it; a folder with files needs none.
init_seed_dir() { # <rel-dir>
  local dir="$INIT_DIR/$1"
  if init_blocked "$1/.gitkeep" || [ -L "$dir" ] || { [ -e "$dir" ] && [ ! -d "$dir" ]; }; then
    init_say skipped "$1/ (a link or a file; left as it is)"; init_count_up skipped; return 0
  fi
  mkdir -p "$dir"
  if [ -z "$(ls -A "$dir")" ]; then
    : > "$dir/.gitkeep"; init_say created "$1/.gitkeep"; init_count_up created
  else
    init_say kept "$1/"; init_count_up kept
  fi
}

# Splits the rendered AGENTS.md template into parts: `<file>\t<kind>\t<key>` per part in $INIT_TMP/parts.idx.
init_split_agents() { # <rendered template>
  mkdir -p "$INIT_TMP/parts"
  awk -v dir="$INIT_TMP/parts" '
    function start(kind, key) { n++; file = sprintf("%s/%02d", dir, n); print file "\t" kind "\t" key > (dir ".idx") }
    BEGIN { n = -1; start("pre", "") }
    !inblock && /^<!-- solidvibes:begin [a-z0-9-]+ -->$/ {
      name = $0; sub(/^<!-- solidvibes:begin /, "", name); sub(/ -->$/, "", name)
      start("block", name); inblock = 1; print > file; next
    }
    inblock && $0 == "<!-- solidvibes:end " name " -->" { print > file; inblock = 0; next }
    !inblock && /^## / { start("section", $0) }
    { print > file }' "$1"
  local f
  for f in "$INIT_TMP"/parts/*; do # trailing blank lines go; spacing is added on insert
    awk '{ l[NR] = $0 } END { n = NR; while (n > 0 && l[n] ~ /^[ \t]*$/) n--; for (i = 1; i <= n; i++) print l[i] }' "$f" > "$f.t"
    mv "$f.t" "$f"
  done
}

# Inserts a part before the `## Factory` heading, or appends it when there is none.
init_insert_part() { # <work> <part>
  awk -v f="$2" '
    function emit(  l) { while ((getline l < f) > 0) print l; close(f) }
    { line = $0; sub(/[ \t\r]+$/, "", line) }
    line ~ /^```/ { fence = !fence }
    !done && !fence && line == "## Factory" {
      if (NR > 1 && prev != "") print ""
      emit(); print ""; done = 1
    }
    { print; prev = line }
    END { if (!done) { if (NR > 0 && prev != "") print ""; emit() } }' "$1" > "$1.new"
  mv "$1.new" "$1"
}

init_replace_block() { # <work> <name> <part>
  awk -v b="<!-- solidvibes:begin $2 -->" -v e="<!-- solidvibes:end $2 -->" -v f="$3" '
    { line = $0; sub(/[ \t\r]+$/, "", line) }
    line ~ /^```/ && !skip { fence = !fence }
    !fence && line == b { while ((getline l < f) > 0) print l; close(f); skip = 1; next }
    skip && line == e { skip = 0; next }
    skip { next }
    { print }' "$1" > "$1.new"
  mv "$1.new" "$1"
}

# Builds the new AGENTS.md in $INIT_TMP/agents.work. Fails, writing nothing, on broken markers.
init_build_agents() {
  local tpl="$SOLIDVIBES_ROOT/setup/templates/AGENTS.md" work="$INIT_TMP/agents.work"
  local label="sv $INIT_SV_VERSION (setup/templates/AGENTS.md)" file kind key begins ends first
  init_subst "$tpl" "$INIT_TMP/agents.rendered"
  init_split_agents "$INIT_TMP/agents.rendered"

  INIT_AGENTS_EXISTS=false
  if [ -f "$INIT_DIR/AGENTS.md" ]; then
    INIT_AGENTS_EXISTS=true
    cp "$INIT_DIR/AGENTS.md" "$work"
  else
    first="$(head -n 1 "$INIT_TMP/parts.idx" | cut -f1)"
    cp "$first" "$work"
  fi

  while IFS='	' read -r file kind key; do
    [ "$kind" = block ] || continue
    begins="$(init_count "$work" "<!-- solidvibes:begin $key -->")"
    ends="$(init_count "$work" "<!-- solidvibes:end $key -->")"
    if [ "$begins" != "$ends" ] || [ "$begins" -gt 1 ]; then
      echo "error: AGENTS.md: the \"$key\" block needs exactly one begin and one end marker; fix it by hand, then run init again" >&2
      return 1
    fi
    if [ "$begins" = 1 ] && ! awk -v b="<!-- solidvibes:begin $key -->" -v e="<!-- solidvibes:end $key -->" '
        { line = $0; sub(/[ \t\r]+$/, "", line) } line == b { s = NR } line == e { t = NR } END { exit !(s < t) }' "$work"; then
      echo "error: AGENTS.md: the \"$key\" block ends before it begins; fix it by hand, then run init again" >&2
      return 1
    fi
  done < "$INIT_TMP/parts.idx"

  while IFS='	' read -r file kind key; do
    case "$kind" in
      block)
        awk -v h="<!-- $INIT_TOKEN from $label. Made by solidvibes init; changes between these markers are replaced the next time it runs. -->" \
          'NR == 1 { print; print h; next } { print }' "$file" > "$file.h"
        init_record "AGENTS.md" "$key" "sv $INIT_SV_VERSION (setup/templates/AGENTS.md)" "$INIT_SV_VERSION" "$(init_hash "$file.h")"
        if [ "$(init_count "$work" "<!-- solidvibes:begin $key -->")" = 1 ]; then
          init_replace_block "$work" "$key" "$file.h"
        else
          init_insert_part "$work" "$file.h"
          INIT_AGENTS_ADDED="${INIT_AGENTS_ADDED:+$INIT_AGENTS_ADDED, }the $key block"
        fi
        ;;
      section)
        [ "$(init_count "$work" "$key")" = 0 ] || continue
        if [ "$key" = "## Factory" ] && [ "$(init_count "$INIT_DIR/CLAUDE.md" "## Factory")" != 0 ]; then
          INIT_FACTORY_IN_CLAUDE=true
          continue
        fi
        init_insert_part "$work" "$file"
        INIT_AGENTS_ADDED="${INIT_AGENTS_ADDED:+$INIT_AGENTS_ADDED, }${key#\#\# }"
        ;;
    esac
  done < "$INIT_TMP/parts.idx"
}

init_write_agents() {
  local work="$INIT_TMP/agents.work" dest="$INIT_DIR/AGENTS.md"
  if [ "$INIT_AGENTS_SKIP" = true ]; then
    init_say skipped "AGENTS.md (a link or a folder, not a plain file; left as it is)"; init_count_up skipped
  elif [ "$INIT_AGENTS_EXISTS" = false ]; then
    cp "$work" "$dest"; init_say created "AGENTS.md"; init_count_up created
  elif cmp -s "$work" "$dest"; then
    init_say unchanged "AGENTS.md"; init_count_up unchanged
  else
    cp "$work" "$dest"
    init_say updated "AGENTS.md (${INIT_AGENTS_ADDED:+added: $INIT_AGENTS_ADDED; }refreshed the marked blocks)"
    init_count_up written
  fi
}

# .solidvibes/agents.md: the table row and section of each agent in use.
init_agents_file() {
  local out="$INIT_TMP/agents-md" a f
  {
    echo "# Agents in use"
    echo
    echo "How each agent working in this project shows visuals, asks a choice, runs sub-agents and worktrees, and finds skills. Skills say \"show a visual\" or \"start a sub-agent\"; this file says how."
    echo
    echo "| Agent | Visuals | Sub-agents | Worktrees | Skills folder it reads |"
    echo "|---|---|---|---|---|"
    for a in $INIT_AGENTS; do grep -m1 '^| ' "$SOLIDVIBES_ROOT/setup/agents/$a.md"; done
    for a in $INIT_AGENTS; do
      f="$SOLIDVIBES_ROOT/setup/agents/$a.md"
      echo
      awk '/^### / { on = 1 } on { print }' "$f"
    done
  } > "$out.body"
  init_header ".solidvibes/agents.md" "sv $INIT_SV_VERSION (setup/agents/)" "$out.body" "$out"
  init_generated "$out" ".solidvibes/agents.md" "sv $INIT_SV_VERSION (setup/agents/)" "$INIT_SV_VERSION"
}

# .solidvibes/.gitignore: the handover and the hello hash are one machine's state, never committed.
init_gitignore() {
  local out="$INIT_TMP/gitignore" label="sv $INIT_SV_VERSION"
  printf '%s\n' handover.md hello.state > "$out.body"
  init_header ".solidvibes/.gitignore" "$label" "$out.body" "$out"
  init_generated "$out" ".solidvibes/.gitignore" "$label" "$INIT_SV_VERSION"
}

init_claude_md() {
  local f="$INIT_DIR/CLAUDE.md"
  [ -e "$f" ] || [ -L "$f" ] || {
    [ -f "$INIT_DIR/CLAUDE.local.md" ] && init_say note "CLAUDE.local.md makes Claude Code skip AGENTS.md; add the line @AGENTS.md to it yourself"
    return 0
  }
  if [ -L "$f" ] || [ ! -f "$f" ]; then
    init_say skipped "CLAUDE.md (a link, not a plain file; @AGENTS.md not added)"; init_count_up skipped; return 0
  fi
  if [ "$(init_count "$f" "@AGENTS.md")" != 0 ]; then
    init_say unchanged "CLAUDE.md (already imports @AGENTS.md)"; init_count_up unchanged; return 0
  fi
  [ -s "$f" ] && [ -n "$(tail -c 1 "$f")" ] && echo >> "$f"
  printf '\n%s\n' "@AGENTS.md" >> "$f"
  init_say updated "CLAUDE.md (added @AGENTS.md, so Claude Code reads AGENTS.md too)"; init_count_up written
}

init_links() {
  local d name link target
  for d in "$INIT_DIR"/.agents/skills/*/; do
    [ -f "$d/SKILL.md" ] || continue
    name="$(basename "$d")"
    link="$INIT_DIR/.claude/skills/$name"
    target="../../.agents/skills/$name"
    if init_blocked ".claude/skills/$name"; then
      init_say skipped ".claude/skills/$name (.claude or .claude/skills is a link or a file)"; init_count_up skipped; continue
    elif [ -L "$link" ]; then
      if [ "$(readlink "$link")" = "$target" ]; then
        init_say unchanged ".claude/skills/$name → $target"; init_count_up unchanged
      else
        init_say skipped ".claude/skills/$name (a link to somewhere else already exists)"; init_count_up skipped; continue
      fi
    elif [ -e "$link" ]; then
      init_say skipped ".claude/skills/$name (a folder already exists there)"; init_count_up skipped; continue
    else
      mkdir -p "$INIT_DIR/.claude/skills"
      ln -s "$target" "$link"
      init_say linked ".claude/skills/$name → $target"; init_count_up linked
    fi
    printf '%s\t%s\n' ".claude/skills/$name" "$target" >> "$INIT_TMP/links"
  done
}

init_manifest() {
  local out="$INIT_TMP/manifest.json" a sep path block source version hash target
  sort -u "$INIT_TMP/entries" > "$INIT_TMP/entries.sorted"
  sort -u "$INIT_TMP/links" > "$INIT_TMP/links.sorted"
  {
    echo "{"
    echo "  \"generator\": \"solidvibes init\","
    echo "  \"note\": \"$INIT_TOKEN. Made by solidvibes init; replaced the next time it runs.\","
    echo "  \"sv\": $(init_json_str "$INIT_SV_VERSION"),"
    echo "  \"profile\": { \"name\": $(init_json_str "$INIT_PNAME"), \"version\": $(init_json_str "$INIT_PVERSION") },"
    printf '  "agents": ['
    sep=""
    for a in $INIT_AGENTS; do printf '%s%s' "$sep" "$(init_json_str "$a")"; sep=", "; done
    echo "],"
    echo "  \"generated\": ["
    sep=""
    while IFS='	' read -r path block source version hash; do
      printf '%s    { "path": %s' "$sep" "$(init_json_str "$path")"
      [ "$block" = - ] || printf ', "block": %s' "$(init_json_str "$block")"
      printf ', "source": %s, "version": %s, "hash": %s }' "$(init_json_str "$source")" "$(init_json_str "$version")" "$(init_json_str "$hash")"
      sep=$',\n'
    done < "$INIT_TMP/entries.sorted"
    echo
    echo "  ],"
    if [ -s "$INIT_TMP/links.sorted" ]; then
      echo "  \"links\": ["
      sep=""
      while IFS='	' read -r path target; do
        printf '%s    { "path": %s, "target": %s }' "$sep" "$(init_json_str "$path")" "$(init_json_str "$target")"
        sep=$',\n'
      done < "$INIT_TMP/links.sorted"
      echo
      echo "  ]"
    else
      echo "  \"links\": []"
    fi
    echo "}"
  } > "$out"
  init_generated "$out" ".solidvibes/manifest.json" "sv $INIT_SV_VERSION" "$INIT_SV_VERSION"
}

cli_init() {
  local profile="$SOLIDVIBES_ROOT/setup/profiles/blank" agents="claude,codex,generic" dir="" a tpl rel
  while [ $# -gt 0 ]; do
    case "$1" in
      --profile) [ $# -ge 2 ] || { echo "error: --profile needs a folder" >&2; return 1; }; profile="$2"; shift 2 ;;
      --agents) [ $# -ge 2 ] || { echo "error: --agents needs a list, e.g. claude,codex" >&2; return 1; }; agents="$2"; shift 2 ;;
      -*) echo "error: unknown option: $1" >&2; return 1 ;;
      *) [ -z "$dir" ] || { echo "error: one project folder only" >&2; return 1; }; dir="$1"; shift ;;
    esac
  done
  [ -n "$dir" ] || { echo "usage: solidvibes init [--profile <dir>] [--agents claude,codex,generic] <dir>" >&2; return 1; }

  INIT_AGENTS=""
  for a in $INIT_AGENTS_ALL; do
    case ",$agents," in *",$a,"*) INIT_AGENTS="$INIT_AGENTS $a" ;; esac
  done
  for a in $(echo "$agents" | tr ',' ' '); do
    case " $INIT_AGENTS_ALL " in *" $a "*) ;; *) echo "error: unknown agent: $a (known: $INIT_AGENTS_ALL)" >&2; return 1 ;; esac
  done
  INIT_AGENTS="${INIT_AGENTS# }"
  [ -n "$INIT_AGENTS" ] || { echo "error: --agents names no agent" >&2; return 1; }

  [ -d "$profile" ] || { echo "error: profile folder not found: $profile" >&2; return 1; }
  INIT_PROFILE_DIR="$(cd "$profile" && pwd -P)"
  for a in SKILL.md stack.md contract.md; do
    [ -f "$INIT_PROFILE_DIR/$a" ] || { echo "error: the profile has no $a: $profile" >&2; return 1; }
  done
  INIT_PNAME="$(init_fm "$INIT_PROFILE_DIR/SKILL.md" name)"
  INIT_PVERSION="$(init_fm "$INIT_PROFILE_DIR/SKILL.md" version)"
  [ -n "$INIT_PNAME" ] && [ -n "$INIT_PVERSION" ] || { echo "error: the profile's SKILL.md needs name and version in its frontmatter" >&2; return 1; }
  INIT_PLABEL="$INIT_PNAME $INIT_PVERSION"

  INIT_SV_VERSION="$(sed -n 's/^[[:space:]]*"version":[[:space:]]*"\([^"]*\)".*/\1/p' "$SOLIDVIBES_ROOT/.claude-plugin/plugin.json" | head -n 1)"
  [ -n "$INIT_SV_VERSION" ] || { echo "error: no version in .claude-plugin/plugin.json" >&2; return 1; }

  if [ -e "$dir" ] && [ ! -d "$dir" ]; then echo "error: not a folder: $dir" >&2; return 1; fi
  mkdir -p "$dir"
  INIT_DIR="$(cd "$dir" && pwd -P)"
  INIT_NAME="$(basename "$INIT_DIR")"

  INIT_TMP="$(mktemp -d)"
  # shellcheck disable=SC2064
  trap "rm -rf '$INIT_TMP'" EXIT
  : > "$INIT_TMP/entries"; : > "$INIT_TMP/links"; : > "$INIT_TMP/old-paths"
  [ -f "$INIT_DIR/.solidvibes/manifest.json" ] && \
    { grep -o '"path": "[^"]*"' "$INIT_DIR/.solidvibes/manifest.json" | sed 's/^"path": "//; s/"$//' > "$INIT_TMP/old-paths" || true; }
  INIT_N_written=0; INIT_N_unchanged=0; INIT_N_created=0; INIT_N_kept=0; INIT_N_linked=0; INIT_N_skipped=0
  INIT_AGENTS_ADDED=""; INIT_FACTORY_IN_CLAUDE=false; INIT_AGENTS_SKIP=false

  if [ -L "$INIT_DIR/AGENTS.md" ] || { [ -e "$INIT_DIR/AGENTS.md" ] && [ ! -f "$INIT_DIR/AGENTS.md" ]; }; then
    INIT_AGENTS_SKIP=true
  else
    init_build_agents || return 1
  fi

  echo "solidvibes init: $INIT_DIR (profile $INIT_PLABEL; agents: $INIT_AGENTS)"
  tpl="$SOLIDVIBES_ROOT/setup/templates"
  init_write_agents
  init_claude_md
  init_generate_from "$tpl/factory-contract.md" ".solidvibes/factory-contract.md" "sv $INIT_SV_VERSION (setup/templates/factory-contract.md)" "$INIT_SV_VERSION"
  init_agents_file
  init_gitignore

  while IFS= read -r rel; do
    case "$rel" in
      CONVENTIONS.md) init_generate_from "$tpl/docs/$rel" "docs/$rel" "sv $INIT_SV_VERSION (setup/templates/docs/$rel)" "$INIT_SV_VERSION" ;;
      */.gitkeep) init_seed_dir "docs/${rel%/.gitkeep}" ;;
      *) init_seed "$tpl/docs/$rel" "docs/$rel" ;;
    esac
  done < <(cd "$tpl/docs" && find . -type f | sed 's|^\./||' | sort)
  init_seed "$tpl/CHANGELOG.md" "CHANGELOG.md"

  case " $INIT_AGENTS " in *" claude "*) init_links ;; esac
  init_manifest

  echo "solidvibes init: done. $INIT_N_written written, $INIT_N_unchanged unchanged, $INIT_N_created created, $INIT_N_kept kept, $INIT_N_linked linked, $INIT_N_skipped skipped."
  if [ "$INIT_FACTORY_IN_CLAUDE" = true ]; then
    echo "solidvibes init: CLAUDE.md holds a ## Factory, so AGENTS.md got none. The skills read the contract from AGENTS.md only: the interview skill's setup moves it there after the owner says yes."
  fi
}
