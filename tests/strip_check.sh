#!/usr/bin/env bash
# scripts/strip-check.sh on a temp copy of this repo: clean without a denylist; planted secrets,
# owner paths and denylist values fail with file, line and category only; exemptions; history.
set -euo pipefail

REPO="$(cd "$(dirname "$0")/.." && pwd -P)"
T="$(mktemp -d)"
trap 'rm -rf "$T"' EXIT

fail() { echo "FAIL: $*" >&2; exit 1; }

export GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_NOSYSTEM=1
export GIT_AUTHOR_NAME=test GIT_AUTHOR_EMAIL=test@example.com GIT_COMMITTER_NAME=test GIT_COMMITTER_EMAIL=test@example.com
export SOLIDVIBES_DENYLIST="$T/no-denylist.txt"

C="$T/copy"
mkdir "$C"
(cd "$REPO" && git ls-files -co --exclude-standard | while IFS= read -r f; do [ -f "$f" ] && echo "$f"; done) \
  | (cd "$REPO" && xargs tar cf -) | (cd "$C" && tar xf -)
cd "$C"

out="$(scripts/strip-check.sh 2>&1)" || fail "a clean copy should pass: $out"
printf '%s\n' "$out" | grep -q "denylist not found, skipped" || fail "should say the denylist was skipped: $out"

KEY="ghp_$(LC_ALL=C tr -dc 'A-Za-z0-9' < /dev/urandom | head -c 36 || true)"
OWNER="jdoe$RANDOM"
SUPA="sb_""secret_$RANDOM"
mkdir -p docs
{
  echo "notes"
  echo "token = \"$KEY\""
  echo "see /Users/$OWNER/projects/app"
  echo "mail $OWNER@corp.test, fine: someone@example.com, noreply@example.org"
  echo "key $SUPA"
  echo "jwt eyJ""hbGciOiJIUzI1NiJ9.e30.x"
  echo "ref https://abcdefghijklmnopqrst.supabase.co"
  echo "slack #C0""1ABCDE23F"
  echo "brand Zephyrquill app"
} > docs/leak.md

check() { # <expect-rc> <args…>; sets out
  local rc=0
  out="$(scripts/strip-check.sh "${@:2}" 2>&1)" || rc=$?
  [ "$rc" = "$1" ] || fail "expected exit $1, got $rc: $out"
  for v in "$KEY" "$OWNER" "$SUPA" abcdefghijklmnopqrst Zephyrquill zephyrquill; do
    printf '%s\n' "$out" | grep -qF -- "$v" && fail "output leaks a matched value: $out"
  done
  printf '%s\n' "$out" | grep -v '^strip-check: ' | grep -vqE '^[^ ]+:[0-9]+: [a-z-]+(:[a-z0-9-]+)?( \(history, (commit|blob) [0-9a-f]{7}\))?$' \
    && fail "a hit line names more than file, line and category: $out"
  return 0
}
has() { printf '%s\n' "$out" | grep -qxF -- "$1" || fail "missing [$1] in: $out"; }
hasnt() { printf '%s\n' "$out" | grep -qF -- "$1" && fail "unexpected [$1] in: $out"; return 0; }

check 1
has "docs/leak.md:2: secret:github-pat"
has "docs/leak.md:3: owner-path"
has "docs/leak.md:4: email"
has "docs/leak.md:5: supabase-key"
has "docs/leak.md:6: jwt"
has "docs/leak.md:7: project-ref"
has "docs/leak.md:8: slack-id"
hasnt "docs/leak.md:9:"
printf '%s\n' "$out" | grep -q "denylist not found, skipped" || fail "should say the denylist was skipped: $out"

printf '# owner only\nproduct Zephyrquill\n' > "$T/denylist.txt"
chmod 600 "$T/denylist.txt"
SOLIDVIBES_DENYLIST="$T/denylist.txt" check 1
has "docs/leak.md:9: denylist:product"

echo "token = \"$KEY\" # gitleaks:allow" > docs/inline.md
echo "docs/leak.md:github-pat:2" > .gitleaksignore
echo "see /Users/$OWNER/x" > "docs/odd:name.md"
check 1
has "docs/inline.md:1: secret:github-pat"
has ".gitleaksignore:1: gitleaks-ignore"
has "docs/odd:name.md:1: owner-path"
rm docs/inline.md .gitleaksignore "docs/odd:name.md"

printf 'docs/leak.md:owner-path  # test\ndocs/leak.md:secret  # test\n' >> .strip-allow
check 1
hasnt "docs/leak.md:3:"
hasnt "docs/leak.md:2:"
has "docs/leak.md:4: email"

printf 'docs/  # test\n' >> .strip-allow
check 0
cp "$REPO/.strip-allow" .strip-allow

git init -q -b main .
git add -A && git commit -qm leak
git rm -q docs/leak.md && git commit -qm "remove leak"
check 0
check 1 --history
printf '%s\n' "$out" | grep -qE '^docs/leak.md:2: secret:github-pat \(history, commit [0-9a-f]{7}\)$' || fail "history secret not named: $out"
printf '%s\n' "$out" | grep -qE '^docs/leak.md:3: owner-path \(history, blob [0-9a-f]{7}\)$' || fail "history owner path not named: $out"
echo "strip_check: ok"
