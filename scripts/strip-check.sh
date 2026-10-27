#!/usr/bin/env bash
# strip-check — refuse a commit that carries secrets or owner data
#
#   scripts/strip-check.sh [--history] [dir]     dir defaults to this repo
#
# 1. gitleaks over the files (and every commit with --history), config .gitleaks.toml.
# 2. Generic patterns: owner paths, emails outside example.com / noreply@, 20-letter
#    lowercase refs, Supabase keys, JWTs, Slack ids.
# 3. The local denylist ($SOLIDVIBES_DENYLIST, default ~/.config/solidvibes/strip-denylist.txt),
#    never committed: one `<category> <value>` per line, # for comments. Skipped when absent.
# With --history, 2 and 3 also run over every blob in the history.
#
# Exemptions: .strip-allow, one `<path-glob>[:<category>]  # reason` per line.
# Output names file, line and category, never the matched value.

set -euo pipefail

HISTORY=false
if [ "${1:-}" = "--history" ]; then
  HISTORY=true
  shift
fi
ROOT="$(cd "${1:-$(dirname "$0")/..}" && pwd -P)"
DENYLIST="${SOLIDVIBES_DENYLIST:-$HOME/.config/solidvibes/strip-denylist.txt}"

command -v gitleaks >/dev/null 2>&1 || {
  echo "strip-check: gitleaks is not installed (https://github.com/gitleaks/gitleaks); cannot check for secrets" >&2
  exit 1
}

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
cd "$ROOT"

IS_GIT=false
if git rev-parse --git-dir >/dev/null 2>&1; then IS_GIT=true; fi
if [ "$HISTORY" = true ] && [ "$IS_GIT" = false ]; then
  echo "strip-check: --history needs a git repo" >&2
  exit 1
fi

# The files a commit could carry: tracked and untracked, minus ignored.
if [ "$IS_GIT" = true ]; then
  git ls-files -co --exclude-standard | while IFS= read -r f; do [ -f "$f" ] && echo "$f"; done | sort -u > "$TMP/files"
else
  find . -name .git -prune -o -type f -print | sed 's|^\./||' | sort > "$TMP/files"
fi

ALLOW=()
if [ -f .strip-allow ]; then
  while IFS= read -r line; do
    line="${line%%#*}"
    line="$(printf '%s' "$line" | tr -d '[:space:]')"
    [ -n "$line" ] && ALLOW+=("$line")
  done < .strip-allow
fi

allowed() { # <path> <category>
  local entry pat cat
  for entry in ${ALLOW[@]+"${ALLOW[@]}"}; do
    pat="${entry%%:*}"
    cat=""
    case "$entry" in *:*) cat="${entry#*:}" ;; esac
    case "$pat" in */) pat="$pat*" ;; esac
    # shellcheck disable=SC2254
    case "$1" in
      $pat) if [ -z "$cat" ] || [ "$2" = "$cat" ] || [ "${2#"$cat":}" != "$2" ]; then return 0; fi ;;
    esac
  done
  return 1
}

# Every finding goes here as `path<TAB>line<TAB>category<TAB>note`.
: > "$TMP/hits"

TEMPLATE="$TMP/gitleaks.tmpl"
printf '%s\n' '{{range .}}{{.File}}	{{.StartLine}}	{{.RuleID}}	{{.Commit}}' '{{end}}' > "$TEMPLATE"

gitleaks_run() { # <dir|git> <out>
  local config=()
  [ -f .gitleaks.toml ] && config=(--config .gitleaks.toml)
  # Exemptions live in .strip-allow only: inline gitleaks:allow is ignored, a .gitleaksignore is a hit.
  gitleaks "$1" . ${config[@]+"${config[@]}"} --no-banner --redact --log-level error --exit-code 0 \
    --ignore-gitleaks-allow \
    --report-format template --report-template "$TEMPLATE" --report-path "$2"
}

grep -E '(^|/)\.gitleaksignore$' "$TMP/files" | sed 's/$/	1	gitleaks-ignore	/' >> "$TMP/hits" || true

gitleaks_run dir "$TMP/gitleaks-dir"
while IFS='	' read -r file line rule _; do
  [ -n "$file" ] || continue
  file="${file#./}"
  grep -qxF -- "$file" "$TMP/files" || continue
  printf '%s\t%s\tsecret:%s\t\n' "$file" "$line" "$rule" >> "$TMP/hits"
done < "$TMP/gitleaks-dir"

if [ "$HISTORY" = true ]; then
  gitleaks_run git "$TMP/gitleaks-git"
  while IFS='	' read -r file line rule commit; do
    [ -n "$file" ] || continue
    printf '%s\t%s\tsecret:%s\t (history, commit %s)\n' "$file" "$line" "$rule" "${commit:0:7}" >> "$TMP/hits"
  done < "$TMP/gitleaks-git"
fi

# Prints `name<TAB>line<TAB>match` for each match of an ERE (or -F patterns) in the listed files.
grep_files() { # <list> <grep args…>
  local list="$1"
  shift
  [ -s "$list" ] || return 0
  # --null ends the name with NUL, so a ':' in a file name never shifts the match into view.
  tr '\n' '\0' < "$list" | xargs -0 grep -HnoI --null "$@" -- 2>/dev/null \
    | tr '\0' '\t' | sed 's/^\([^	]*\)	\([0-9]*\):/\1	\2	/' || true
}

# Scans files for the generic patterns and the denylist; prints `name<TAB>line<TAB>category`.
scan() { # <list>
  local name line match local_part domain category
  grep_files "$1" -E '/Users/[A-Za-z0-9._-]+|~/StudioProjects' | cut -f1,2 | sed 's/$/	owner-path/'
  grep_files "$1" -E '[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}' \
    | while IFS='	' read -r name line match; do
        local_part="${match%%@*}"
        domain="${match#*@}"
        case "$domain" in example.com|*.example.com) continue ;; esac
        case "$local_part" in noreply|git) continue ;; esac
        printf '%s\t%s\temail\n' "$name" "$line"
      done
  grep_files "$1" -E '(^|[^A-Za-z0-9_-])[a-z]{20}([^A-Za-z0-9_-]|$)' | cut -f1,2 | sed 's/$/	project-ref/'
  grep_files "$1" -E 'sb_(secret|publishable)_' | cut -f1,2 | sed 's/$/	supabase-key/'
  grep_files "$1" -E 'eyJ[A-Za-z0-9_-]{10,}' | cut -f1,2 | sed 's/$/	jwt/'
  grep_files "$1" -E '(^|[^A-Za-z0-9_-])[CDGUW]0[A-Z0-9]{7,10}([^A-Za-z0-9_-]|$)' | cut -f1,2 | sed 's/$/	slack-id/'

  [ -f "$DENYLIST" ] || return 0
  for category in $(awk '!/^[ \t]*(#|$)/ && NF >= 2 { print $1 }' "$DENYLIST" | sort -u); do
    awk -v c="$category" '$1 == c && NF >= 2 { sub(/^[ \t]*[^ \t]+[ \t]+/, ""); sub(/[ \t]+$/, ""); print }' \
      "$DENYLIST" > "$TMP/deny-$category"
    grep_files "$1" -iF -f "$TMP/deny-$category" | cut -f1,2 | sed "s/\$/	denylist:$category/"
  done
}

scan "$TMP/files" | sed 's/$/	/' >> "$TMP/hits"

if [ "$HISTORY" = true ]; then
  mkdir "$TMP/blobs"
  git rev-list --objects --all \
    | git cat-file --batch-check='%(objecttype) %(objectname) %(rest)' \
    | awk '$1 == "blob" && !seen[$2]++ { sub(/^blob /, ""); print }' > "$TMP/blob-paths"
  while read -r sha _; do
    git cat-file blob "$sha" > "$TMP/blobs/$sha"
  done < "$TMP/blob-paths"
  (cd "$TMP/blobs" && ls) > "$TMP/blob-list" || true
  (cd "$TMP/blobs" && scan "$TMP/blob-list") \
    | awk -F'\t' -v OFS='\t' '
        NR == FNR { sha = $0; sub(/ .*/, "", sha); path = $0; sub(/^[^ ]* /, "", path); p[sha] = path; next }
        { print p[$1], $2, $3, " (history, blob " substr($1, 1, 7) ")" }
      ' "$TMP/blob-paths" - >> "$TMP/hits"
fi

if [ -f "$DENYLIST" ]; then
  DENY_NOTE="denylist checked"
else
  DENY_NOTE="denylist not found, skipped (owner-only step)"
fi

COUNT=0
while IFS='	' read -r file line category note; do
  allowed "$file" "$category" && continue
  echo "$file:$line: $category$note"
  COUNT=$((COUNT + 1))
done < <(sort -u "$TMP/hits")

if [ "$COUNT" -gt 0 ]; then
  echo "strip-check: $COUNT hit(s); $DENY_NOTE. Remove them, or exempt a path in .strip-allow with a reason." >&2
  exit 1
fi
echo "strip-check: clean ($(wc -l < "$TMP/files" | tr -d ' ') files$([ "$HISTORY" = true ] && echo ", history"); $DENY_NOTE)"
