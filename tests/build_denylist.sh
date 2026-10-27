#!/usr/bin/env bash
# scripts/build-denylist.sh: reads origin/main only, never .env* or config/*.json, prints no value,
# writes a mode-600 file in the strip check's format and keeps lines already there.
# The fake values are assembled at run time so this file itself holds none.
set -euo pipefail

REPO="$(cd "$(dirname "$0")/.." && pwd -P)"
T="$(mktemp -d)"
trap 'rm -rf "$T"' EXIT

fail() { echo "FAIL: $*" >&2; exit 1; }
ref() { printf "$1%.0s" 1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16 17 18 19 20; }
at=@

good_mail="dev${at}widget.test"; good_ref="$(ref q)"
env_mail="env${at}widget.test"; env_ref="$(ref v)"
cfg_mail="cfg${at}widget.test"; cfg_ref="$(ref w)"
ahead_mail="ahead${at}widget.test"; tree_mail="tree${at}widget.test"
device="0A1B2C3D-4E5F-4A6B-8C7D-9E0F1A2B3C4D"

S="$T/src"
mkdir -p "$S/lib" "$S/ios" "$S/scripts" "$S/docs" "$S/config" "$S/app/config" "$S/app" "$S/web"
git -C "$S" init -q
git -C "$S" config user.name "Pat Builder"
git -C "$S" config user.email "pat${at}widget.test"
printf 'name: widgetly\n' > "$S/pubspec.yaml"
printf '// supabase https://%s.supabase.co\nconst mail = "%s";\n' "$good_ref" "$good_mail" > "$S/lib/main.dart"
printf 'PRODUCT_BUNDLE_IDENTIFIER = com.acme.widget;\nDEVELOPMENT_TEAM = AB12CD34EF;\n' > "$S/ios/project.pbxproj"
printf 'flutter run -d %s\n' "$device" > "$S/scripts/run.sh"
printf 'Post in the Slack channel #widget-launch.\n' > "$S/docs/team.md"
printf 'MAIL=%s\nSUPABASE_REF=%s\n' "$env_mail" "$env_ref" > "$S/.env"
printf 'MAIL=%s\nSUPABASE_REF=%s\n' "$env_mail" "$env_ref" > "$S/app/.env.dev"
printf 'MAIL=%s\n' "$env_mail" > "$S/web/.env.production"
printf '{"supabase": "%s", "mail": "%s"}\n' "$cfg_ref" "$cfg_mail" > "$S/config/x.json"
printf '{"supabase": "%s", "mail": "%s"}\n' "$cfg_ref" "$cfg_mail" > "$S/app/config/dev.json"
git -C "$S" add -A && git -C "$S" commit -qm one
git -C "$S" update-ref refs/remotes/origin/main HEAD
printf '%s\n' "$ahead_mail" > "$S/lib/ahead.dart"
git -C "$S" add -A && git -C "$S" commit -qm "not on origin/main"
printf '%s\n' "$tree_mail" >> "$S/lib/main.dart"

D="$T/deny/list.txt"
mkdir "$T/norepo"
out="$(HOME="$T" SOLIDVIBES_DENYLIST="$D" "$REPO/scripts/build-denylist.sh" "$S" "$T/norepo" 2>&1)" || fail "script failed: $out"
[ -f "$D" ] || fail "no denylist written"
[ "$(ls -l "$D" | cut -c1-10)" = "-rw-------" ] || fail "denylist mode is not 600"
printf '%s\n' "$out" | grep -q 'repo #2 has no origin/main' || fail "a repo without origin/main should be named by number: $out"

has() { grep -qxF -- "$1" "$D" || fail "denylist lacks [$1]"; }
has "email $good_mail"
has "email pat${at}widget.test"
has "person Pat Builder"
has "project-ref $good_ref"
has "bundle-id com.acme.widget"
has "team-id AB12CD34EF"
has "device-id $device"
has "slack #widget-launch"
has "product widgetly"

for v in "$env_mail" "$env_ref" "$cfg_mail" "$cfg_ref" "$ahead_mail" "$tree_mail"; do
  grep -qF -- "$v" "$D" && fail "denylist holds a value from a skipped path, the working tree or a later commit"
done
for v in "$good_mail" "$good_ref" com.acme.widget AB12CD34EF "$device" widget-launch widgetly "Pat Builder" "$T"; do
  printf '%s\n' "$out" | grep -qF -- "$v" && fail "output printed a value"
done
printf '%s\n' "$out" | grep -qE '^  email +2$' || fail "counts per category expected: $out"

printf '# mine\nproduct handmade\n' > "$T/keep"
cat "$D" >> "$T/keep"
cp "$T/keep" "$D"
SOLIDVIBES_DENYLIST="$D" "$REPO/scripts/build-denylist.sh" "$S" > /dev/null
has "product handmade"
[ "$(sort "$D" | uniq -d)" = "" ] || fail "a second run duplicated lines"
[ "$(ls -l "$D" | cut -c1-10)" = "-rw-------" ] || fail "mode lost on rewrite"

# The strip check reads the file: a value from it in a scanned folder is a hit, named by category only.
mkdir "$T/scan"
printf 'Built for widgetly.\n' > "$T/scan/a.md"
scan="$(SOLIDVIBES_DENYLIST="$D" "$REPO/scripts/strip-check.sh" "$T/scan" 2>&1)" && fail "strip check should hit"
printf '%s\n' "$scan" | grep -q 'a.md:1: denylist:product' || fail "strip check hit not named: $scan"
echo "build_denylist: ok"
