#!/usr/bin/env bash
# build-denylist — collect owner values from source repos into the strip check's local denylist
#
#   scripts/build-denylist.sh <repo>…
#
# Reads each repo's origin/main only (git grep / git log on that ref, never the working tree; run
# `git fetch` in each first). Never reads `.env*` paths or any `config/*.json`.
# Categories: email, person, project-ref, bundle-id, team-id, device-id, slack, product.
# Writes $SOLIDVIBES_DENYLIST (default ~/.config/solidvibes/strip-denylist.txt), mode 600, one
# `<category> <value>` per line, keeping the lines already there. Prints counts per category only,
# never a value. The values are candidates: read the file once and delete what is not yours.

set -euo pipefail
umask 077

[ $# -gt 0 ] || { echo "usage: scripts/build-denylist.sh <repo>…" >&2; exit 1; }
OUT="${SOLIDVIBES_DENYLIST:-$HOME/.config/solidvibes/strip-denylist.txt}"
REF=origin/main
SKIP=(':(exclude,glob)**/.env*' ':(exclude,glob)**/.env*/**' ':(exclude,glob)**/config/*.json')
GENERIC=' app apps admin tools tool website site web core shared common example sample demo test tests docs server client mobile api backend frontend functions supabase harness flutter package packages main lib scripts config monorepo '

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
: > "$TMP/found"

# Prints the lines of origin/main that match an ERE, outside the skipped paths.
lines() { # <repo> <grep flags…> <ERE> [pathspec…]
  local repo="$1"
  shift
  git -C "$repo" grep -h -I "$@" 2>/dev/null || true
}
tree_lines() { # <repo> <ERE> [-i]
  local repo="$1" ere="$2"
  shift 2
  lines "$repo" "$@" -E -e "$ere" "$REF" -- . "${SKIP[@]}"
}
tokens() { grep -oE '[A-Za-z0-9_-]+' || true; }
add() { while IFS= read -r v; do if [ -n "$v" ]; then printf '%s %s\n' "$1" "$v"; fi; done >> "$TMP/found"; }

collect() { # <repo>
  local repo="$1" top name
  tree_lines "$repo" '[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}' -o > "$TMP/emails"
  git -C "$repo" log "$REF" --format='%ae%n%ce' >> "$TMP/emails"
  grep -oE '^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$' "$TMP/emails" \
    | grep -viE '^(noreply|no-reply|git)@|@(.*\.)?example\.(com|org|net)$|noreply\.github\.com$|\.(png|jpe?g|gif|svg|webp)$' \
    | add email || true

  git -C "$repo" log "$REF" --format='%an%n%cn' \
    | grep -viE '\[bot\]|^github$|^claude' | add person || true

  tree_lines "$repo" 'supabase|project.?(ref|id)' -i | tokens | grep -xE '[a-z]{20}' | add project-ref || true

  tree_lines "$repo" 'bundle.?id|BUNDLE_IDENTIFIER|applicationId|app_identifier|package_name|namespace' -i \
    | grep -oE '[A-Za-z][A-Za-z0-9_-]*(\.[A-Za-z0-9_-]+){2,}' \
    | grep -vE '^com\.(example|android)\.|^androidx?\.|\.(kts|gradle|dart|json|md|swift|plist|xml|ya?ml|ts|js|sh|rb|kt|java)$' \
    | add bundle-id || true
  tree_lines "$repo" 'group\.[A-Za-z0-9_-]+\.' -o | grep -E '^group\.[A-Za-z0-9_-]+(\.[A-Za-z0-9_-]+)+$' \
    | grep -v '^group\.com\.example\.' | add bundle-id || true

  tree_lines "$repo" 'DEVELOPMENT_TEAM|team.?id|TeamIdentifier' -i | tokens \
    | grep -xE '[A-Z0-9]{10}' | grep -E '[0-9]' | grep -E '[A-Z]' | add team-id || true

  tree_lines "$repo" 'simctl|udid|device|simulator|-d ' -i \
    | grep -oE '[0-9A-F]{8}-[0-9A-F]{4}-[0-9A-F]{4}-[0-9A-F]{4}-[0-9A-F]{12}' | add device-id || true

  tree_lines "$repo" 'slack' -i > "$TMP/slack"
  { grep -oE '#[a-z0-9][a-z0-9_-]{1,79}' "$TMP/slack" || true
    tokens < "$TMP/slack" | grep -xE '[CDGUW]0[A-Z0-9]{7,10}' || true; } | add slack

  top="$(cd "$repo" && pwd -P)"
  { basename "$top"
    git -C "$repo" remote get-url origin 2>/dev/null | sed -E 's#\.git$##; s#.*[/:]##' || true
    lines "$repo" -E -e '^name:[[:space:]]*[A-Za-z0-9_-]+' "$REF" -- '**/pubspec.yaml' 'pubspec.yaml' "${SKIP[@]}" \
      | sed -E 's/^name:[[:space:]]*//; s/[[:space:]].*//' || true
    lines "$repo" -E -e '^  "name":[[:space:]]*"[^"]+"' "$REF" -- '**/package.json' 'package.json' "${SKIP[@]}" \
      | sed -E 's/.*"name":[[:space:]]*"([^"]+)".*/\1/' || true
    lines "$repo" -A1 -e '<key>CFBundleDisplayName</key>' "$REF" -- '**/Info.plist' "${SKIP[@]}" \
      | grep -oE '<string>[^<$]+</string>' | sed -E 's#</?string>##g' || true
    lines "$repo" -o -E -e 'android:label="[^"@$]+"' "$REF" -- '**/AndroidManifest.xml' "${SKIP[@]}" \
      | sed -E 's/android:label="//; s/"$//' || true
  } | while IFS= read -r name; do
    name="${name#@*/}"
    [ "${#name}" -ge 4 ] || continue
    case "$GENERIC" in *" $(printf '%s' "$name" | tr '[:upper:]' '[:lower:]') "*) continue ;; esac
    printf '%s\n' "$name"
  done | add product
}

n=0
for repo in "$@"; do
  n=$((n + 1))
  if ! git -C "$repo" rev-parse --verify -q "$REF^{commit}" >/dev/null 2>&1; then
    echo "build-denylist: repo #$n has no $REF; skipped" >&2
    continue
  fi
  collect "$repo"
  echo "build-denylist: repo #$n read from $REF"
done

mkdir -p "$(dirname "$OUT")"
{ [ -f "$OUT" ] && cat "$OUT"; sort -u "$TMP/found"; } | awk '!seen[$0]++' > "$TMP/out"
mv "$TMP/out" "$OUT"
chmod 600 "$OUT"

for category in email person project-ref bundle-id team-id device-id slack product; do
  printf '  %-12s %s\n' "$category" "$(awk -v c="$category" '$1 == c' "$OUT" | wc -l | tr -d ' ')"
done
shown="$OUT"
case "$OUT" in "$HOME"/*) shown="~/${OUT#"$HOME"/}" ;; esac
echo "build-denylist: wrote $shown (mode 600). Read it once and delete any line that is not yours."
