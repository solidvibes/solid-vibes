#!/usr/bin/env bash
# solidvibes disk lists what takes space; --clean deletes only the named ids, through each tool's own
# command or the removal guard bounded by $HOME. A fake HOME and stub tools: nothing real is touched.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd -P)"
SV="$ROOT/bin/solidvibes"
T="$(mktemp -d)"
trap 'rm -rf "$T"' EXIT
T="$(cd "$T" && pwd -P)"
cd "$T"

fail() { echo "FAIL: $*" >&2; exit 1; }

unset PUB_CACHE GRADLE_USER_HOME npm_config_cache HOMEBREW_CACHE ANDROID_HOME ANDROID_SDK_ROOT ANDROID_AVD_HOME \
  SOLIDVIBES_PROJECTS_DIR UNAME GRADLE_RUNNING
export GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_NOSYSTEM=1
export GIT_AUTHOR_NAME=test GIT_AUTHOR_EMAIL=test@example.com GIT_COMMITTER_NAME=test GIT_COMMITTER_EMAIL=test@example.com
export HOME="$T/home" STUBS="$T/stubs" LOG="$T/log" FX="$ROOT/tests/fixtures/disk"
export PATH="$STUBS:/usr/bin:/bin"

U=00000000-0000-0000-0000-0000000000
L="$HOME/Library"
P="$HOME/projects"
R="$P/example-app"

stub() { # <name> <body>; every call is logged
  printf '#!/bin/sh\necho "%s $*" >> "$LOG"\n%s\n' "$1" "$2" > "$STUBS/$1"
  chmod +x "$STUBS/$1"
}
mkdir -p "$STUBS"
printf '#!/bin/sh\necho "${UNAME:-Darwin}"\n' > "$STUBS/uname"
printf '#!/bin/sh\necho "$STUBS/simctl"\n' > "$STUBS/xcrun"
chmod +x "$STUBS/uname" "$STUBS/xcrun"
stub simctl 'case "$*" in
  "list -j devices") cat "$FX/devices.json" ;;
  "list -j runtimes") cat "$FX/runtimes.json" ;;
  "runtime list -j") cat "$FX/images.json" ;;
  "delete '"${U}"'06") echo "Unable to delete: NSCocoaErrorDomain 513" >&2; exit 1 ;;
esac'
stub avdmanager ''
stub dart ''
stub flutter ''
stub npm '[ "$*" = "config get cache" ] && echo "$HOME/.npm"; exit 0'
stub pod ''
stub brew '[ "$*" = "cleanup -n --prune=all" ] && echo "==> This operation would free approximately 1.5GB of disk space."; exit 0'
stub gradle ''
stub pgrep '[ -n "${GRADLE_RUNNING:-}" ]'

sv() { "$BASH" "$SV" disk "$@"; }
old() { find "$@" -exec touch -t 202001010000 {} +; }
blob() { mkdir -p "$1" && head -c 8192 /dev/zero > "$1/blob"; }
row() { printf '%s\n' "$tsv" | awk -F'\t' -v id="$1" '$1 == id'; }
col() { row "$1" | cut -f"$2"; }
logged() { grep -qF -- "$1" "$LOG"; }
line_of() { grep -nF -- "$1" "$LOG" | head -n 1 | cut -d: -f1; }

mkhome() { # keeps the projects folder
  mkdir -p "$HOME"
  find "$HOME" -mindepth 1 -maxdepth 1 ! -name projects -exec rm -rf {} +
  blob "$L/Developer/Xcode/DerivedData/Old-abc"
  blob "$L/Developer/Xcode/DerivedData/Fresh-def"
  blob "$HOME/.gradle/caches"
  blob "$HOME/.pub-cache"
  blob "$HOME/.npm/_cacache"
  blob "$L/Caches/CocoaPods"
  blob "$L/Caches/org.swift.swiftpm"
  local n
  for n in 01 02 03 04 05 06 07 08; do blob "$L/Developer/CoreSimulator/Devices/$U$n"; done
  blob "$HOME/.android/avd/Pixel_Example.avd"
  blob "$HOME/.android/avd/Busy_Example.avd"
  touch "$HOME/.android/avd/Busy_Example.avd/hardware-qemu.ini.lock"
  blob "$L/Developer/Xcode/iOS DeviceSupport/iPhone99,1 98.0 (98A100)"
  blob "$L/Developer/Xcode/iOS DeviceSupport/iPhone99,1 99.0 (99A100)"
  blob "$L/Developer/Xcode/Archives"
  blob "$HOME/.ollama/models"
  old "$HOME"
  touch "$L/Developer/Xcode/DerivedData/Fresh-def/blob" "$L/Developer/Xcode/iOS DeviceSupport/iPhone99,1 99.0 (99A100)"
}

mkprojects() {
  rm -rf "$P" "$T/wts"
  git init -q -b main "$R"
  printf 'build/\nnode_modules/\n' > "$R/.gitignore"
  echo one > "$R/file"
  blob "$R/ios/build"
  git -C "$R" add .gitignore file
  git -C "$R" add -f ios/build/blob
  git -C "$R" commit -qm one
  blob "$R/build/out"
  blob "$R/node_modules/plain"
  blob "$R/.dart_tool"  # not in .gitignore, so not build output
  git init -q "$R/vendor/nested"
  blob "$R/vendor/nested/build"  # belongs to the nested repo
  mkdir -p "$R/node_modules/dep/.git"
  git -C "$R" worktree add -q -b merged "$T/wts/merged"
  old "$R"
  git init -q -b main "$P/example-web"
  echo 'build/' > "$P/example-web/.gitignore"
  blob "$P/example-web/build"
}

mkhome
mkprojects

# The list
tsv="$(sv --tsv --projects "$P")"
[ "$(printf '%s\n' "$tsv" | head -n 1)" = "$(printf 'id\titem\tkb\tclass\tnote')" ] || fail "tsv header: $tsv"
printf '%s\n' "$tsv" | awk -F'\t' 'NR > 1 && !/^#/ && $3 !~ /^[0-9]+$/ { bad = 1 } END { exit bad }' || fail "kb must be whole KiB: $tsv"
printf '%s\n' "$tsv" | grep -q '^# free	[0-9]' || fail "tsv free line: $tsv"
[ "$(col homebrew 3)" = 1464844 ] || fail "homebrew size from brew's estimate: $(row homebrew)"
[ "$(col build:example-app 4)" = safe ] || fail "build row: $tsv"
col build:example-app 2 | grep -q "(1 folder(s))" || fail "only build/ qualifies (ios/build is tracked, node_modules holds a .git, .dart_tool is not ignored, vendor/nested is its own repo): $(row build:example-app)"
[ -z "$(row build:example-web)" ] || fail "a build folder touched now is not counted: $tsv"
col deriveddata 5 | grep -q "skipped 1 active" || fail "deriveddata note: $(row deriveddata)"
[ "$(col worktrees 4)" = safe ] || fail "worktrees row: $tsv"
[ "$(col pub 4)" = your-call ] || fail "pub is your-call: $(row pub)"
[ "$(col "sim:${U}03" 4)" = keep ] && col "sim:${U}03" 5 | grep -q running || fail "a booted simulator is kept: $(row "sim:${U}03")"
[ "$(col "sim:${U}01" 5)" = "iPhone-Example, newest runtime for type" ] || fail "sim 01: $(row "sim:${U}01")"
[ "$(col "sim:${U}02" 5)" = "iPhone-Example-Pro, newer runtime iOS-99-0" ] || fail "sim 02: $(row "sim:${U}02")"
[ "$(col "sim:${U}04" 5)" = "iPad-Example, newer runtime iOS-99-0" ] || fail "sim 04: $(row "sim:${U}04")"
[ "$(col "sim:${U}08" 5)" = "iPad-Example, newest runtime for type" ] || fail "sim 08: $(row "sim:${U}08")"
[ -z "$(row "sim:${U}05")" ] && [ -n "$(row sim-unavailable)" ] || fail "an unavailable simulator rolls into sim-unavailable: $tsv"
[ "$(col "runtime:${U}a1" 5)" = "used by 1 simulator(s)" ] || fail "runtime a1: $(row "runtime:${U}a1")"
[ "$(col "runtime:${U}c1" 4)" = keep ] || fail "a runtime that can't be deleted is kept: $(row "runtime:${U}c1")"
[ "$(col avd:Busy_Example 4)" = keep ] && [ "$(col avd:Busy_Example 5)" = running ] || fail "a locked emulator is kept: $tsv"
[ "$(col avd:Pixel_Example 4)" = your-call ] || fail "avd row: $tsv"
[ "$(col devicesupport:99A100 4)" = keep ] && [ "$(col devicesupport:98A100 4)" = your-call ] || fail "devicesupport: $tsv"
[ "$(col archives 4)" = keep ] && [ "$(col ollama 4)" = keep ] || fail "archives and ollama are kept: $tsv"
table="$(sv --projects "$P")"
printf '%s\n' "$table" | grep -q "^ID  *ITEM  *SIZE  *CLASS  *NOTE" || fail "table header: $table"
printf '%s\n' "$table" | grep -q "^free .* on " && printf '%s\n' "$table" | grep -q "^total .*, cleanable " || fail "table summary: $table"
[ "$(printf '%s\n' "$table" | sed -n '/^ID /,/^$/p' | grep -cv '^[a-z]')" = 2 ] || fail "every table line is a row: $table"

# Refusals delete nothing
: > "$LOG"
if out="$(sv --clean archives 2>&1)"; then fail "archives is keep: $out"; fi
if out="$(sv --clean nosuch 2>&1)"; then fail "unknown id: $out"; fi
if out="$(sv --clean gradle nosuch 2>&1)"; then fail "one unknown id refuses the call: $out"; fi
printf '%s\n' "$out" | grep -q "nothing deleted" || fail "refusal message: $out"
if out="$(sv --clean "sim:${U}03" 2>&1)"; then fail "a booted simulator is refused: $out"; fi
if out="$(sv --clean avd:Busy_Example 2>&1)"; then fail "a running emulator is refused: $out"; fi
if out="$(sv --clean devicesupport:99A100 2>&1)"; then fail "the newest DeviceSupport is refused: $out"; fi
! grep -qE "delete|clean|--stop" "$LOG" || fail "a refused call ran a deleting tool: $(cat "$LOG")"
[ -d "$HOME/.gradle/caches" ] && [ -d "$L/Developer/Xcode/Archives" ] && [ -d "$L/Developer/Xcode/iOS DeviceSupport/iPhone99,1 99.0 (99A100)" ] \
  || fail "a refused call removed a folder"

# Build output and DerivedData
touch "$R/.git/index"
tsv="$(sv --tsv --projects "$P")"
[ -z "$(row build:example-app)" ] || fail "a repo whose index changed within the hour is skipped: $(row build:example-app)"
old "$R/.git/index"
tsv="$(cd "$R/ios" && sv --tsv --projects "$P")"
[ -z "$(row build:example-app)" ] || fail "the repo you stand in is skipped: $(row build:example-app)"
out="$(sv --clean build:example-app deriveddata --projects "$P" 2>&1)" || fail "build clean: $out"
[ ! -e "$R/build" ] || fail "build/ should be gone"
[ -f "$R/ios/build/blob" ] || fail "a build folder with a tracked file must survive"
[ -d "$R/node_modules/plain" ] || fail "a folder holding a nested .git must survive"
[ -f "$R/.dart_tool/blob" ] || fail "a folder git does not ignore must survive"
[ -f "$R/vendor/nested/build/blob" ] || fail "build output of a nested repo must survive"
[ -d "$P/example-web/build" ] || fail "an unselected repo was touched"
[ ! -e "$L/Developer/Xcode/DerivedData/Old-abc" ] && [ -d "$L/Developer/Xcode/DerivedData/Fresh-def" ] \
  || fail "deriveddata removes only the idle folders"

# Caches go through their own tools
: > "$LOG"
sv --clean pub npm cocoapods homebrew > /dev/null
logged "dart pub cache clean --force" && logged "npm cache clean --force" && logged "pod cache clean --all" \
  && logged "brew cleanup --prune=all" || fail "native cache commands: $(cat "$LOG")"
[ -d "$HOME/.pub-cache" ] && [ -d "$HOME/.npm/_cacache" ] || fail "the CLI removed a cache itself"
rm "$STUBS/dart"
: > "$LOG"
sv --clean pub > /dev/null
logged "flutter pub cache clean -f" || fail "flutter is the fallback for pub: $(cat "$LOG")"
stub dart ''

# Gradle: stop, then skip if a daemon still runs
: > "$LOG"
if out="$(GRADLE_RUNNING=1 sv --clean gradle)"; then fail "a running daemon should fail: $out"; fi
printf '%s\n' "$out" | grep -q "running" || fail "gradle running message: $out"
logged "gradle --stop" && [ -d "$HOME/.gradle/caches" ] || fail "gradle caches should stay while it runs"
sv --clean gradle > /dev/null
[ ! -e "$HOME/.gradle/caches" ] || fail "gradle caches should be gone"

# Runtimes in use are refused; simulators go first
: > "$LOG"
if out="$(sv --clean "runtime:${U}a1")"; then fail "a runtime in use should be refused: $out"; fi
printf '%s\n' "$out" | grep -q "kept runtime:${U}a1: used by 1 simulator" || fail "runtime refusal: $out"
! logged "runtime delete" || fail "a refused runtime was deleted"
: > "$LOG"
sv --clean "runtime:${U}a1" "sim:${U}07" > /dev/null
[ "$(line_of "simctl delete ${U}07")" -lt "$(line_of "simctl runtime delete ${U}a1")" ] || fail "simulators before runtimes: $(cat "$LOG")"
: > "$LOG"
sv --clean "runtime:${U}b1" > /dev/null
logged "simctl runtime delete ${U}b1" || fail "another image of the runtime stays, so b1 can go"
: > "$LOG"
if out="$(sv --clean "runtime:${U}b1" "runtime:${U}b2")"; then fail "both images with users left: $out"; fi
! logged "runtime delete" || fail "both images of a used runtime were deleted"

# A failing tool is reported, the rest still runs, nothing falls back to rm
: > "$LOG"
if out="$(sv --clean "sim:${U}06" "sim:${U}01" sim-unavailable)"; then fail "a failed delete should exit 1: $out"; fi
printf '%s\n' "$out" | grep -q "^failed sim:${U}06: Unable to delete: NSCocoaErrorDomain 513" || fail "failure line: $out"
printf '%s\n' "$out" | grep -q "^removed sim:${U}01" && logged "simctl delete unavailable" || fail "the others still run: $out"
[ -d "$L/Developer/CoreSimulator/Devices/${U}06" ] || fail "no fallback removal after a failed simctl"
printf '%s\n' "$out" | grep -q "^free before .*, after .*, freed " || fail "freed summary: $out"

# Emulators and DeviceSupport
: > "$LOG"
sv --clean avd:Pixel_Example devicesupport:98A100 > /dev/null
logged "avdmanager delete avd -n Pixel_Example" || fail "avdmanager: $(cat "$LOG")"
[ -d "$HOME/.android/avd/Pixel_Example.avd" ] || fail "the CLI removed an emulator itself"
[ ! -e "$L/Developer/Xcode/iOS DeviceSupport/iPhone99,1 98.0 (98A100)" ] || fail "old DeviceSupport should be gone"
mkdir -p "$L/Android/sdk/cmdline-tools/latest/bin"
mv "$STUBS/avdmanager" "$L/Android/sdk/cmdline-tools/latest/bin/avdmanager"
tsv="$(sv --tsv)"
[ -n "$(row avd:Pixel_Example)" ] || fail "avdmanager is found in the default SDK folder: $tsv"
mv "$L/Android/sdk/cmdline-tools/latest/bin/avdmanager" "$STUBS/avdmanager"

# The removal guard
mkdir -p "$T/outside"
mv "$L/Caches/org.swift.swiftpm" "$T/outside/swiftpm"
ln -s "$T/outside/swiftpm" "$L/Caches/org.swift.swiftpm"
if out="$(sv --clean swiftpm)"; then fail "a symlinked cache must be refused: $out"; fi
[ -f "$T/outside/swiftpm/blob" ] && [ -L "$L/Caches/org.swift.swiftpm" ] || fail "symlink target touched"
blob "$T/outside/gradle/caches"
old "$T/outside"
if out="$(GRADLE_USER_HOME="$T/outside/gradle" sv --clean gradle)"; then fail "a cache outside HOME must be refused: $out"; fi
[ -f "$T/outside/gradle/caches/blob" ] || fail "a folder outside HOME was removed"
guard="$(SOLIDVIBES_ROOT="$ROOT" "$BASH" -c '
  set -euo pipefail
  source "$SOLIDVIBES_ROOT/lib/cli-disk.sh"
  for p in "$HOME" "$HOME/" "$HOME/.android/.." "$HOME/../outside" "$HOME/../outside/gradle/caches" .android /; do
    if disk_safe_path "$p"; then echo "allowed $p"; fi
  done
  disk_safe_path "$HOME/.android" || echo "refused a plain folder"
  HOME=/ disk_safe_path /tmp && echo "allowed with HOME=/"
  HOME= disk_safe_path "$PWD/home/.android" && echo "allowed with empty HOME"
  (cd "$HOME" && disk_safe_path .android) && echo "allowed a relative path"
  true')"
[ -z "$guard" ] || fail "removal guard: $guard"

# Worktrees reuse the sweep; branches stay; a failed removal exits 1
tsv="$(sv --tsv --projects "$P")"
[ -n "$(row worktrees)" ] || fail "worktrees row: $tsv"
sv --clean worktrees --projects "$P" > /dev/null
[ ! -e "$T/wts/merged" ] || fail "the merged worktree should be gone"
git -C "$R" show-ref -q --verify refs/heads/merged || fail "branches are never deleted"
git -C "$R" worktree add -q -b stuck "$T/wts/stuck"
old "$R/.git/worktrees/stuck"
mkdir "$R/.git/worktrees/stuck/modules"  # git refuses to remove a worktree with submodules
if out="$(sv --clean worktrees --projects "$P" 2>&1)"; then fail "a failed worktree removal should exit 1: $out"; fi
printf '%s\n' "$out" | grep -q "^failed worktrees" || fail "worktree failure line: $out"
[ -d "$T/wts/stuck" ] || fail "wt stuck should still exist"

# Off macOS and without a projects folder
mkhome
tsv="$(UNAME=Linux sv --tsv)"
for id in deriveddata cocoapods swiftpm sim-unavailable "sim:${U}01" "runtime:${U}a1" devicesupport:98A100 archives; do
  [ -z "$(row "$id")" ] || fail "no $id row off macOS: $tsv"
done
[ -n "$(row gradle)" ] && [ -n "$(row npm)" ] && [ -n "$(row ollama)" ] || fail "cross-platform rows still show off macOS: $tsv"
printf '%s\n' "$tsv" | grep -q "^# note	projects folder not set" || fail "the projects note: $tsv"
[ -z "$(row worktrees)" ] && [ -z "$(printf '%s\n' "$tsv" | grep '^build:')" ] || fail "no project rows without a projects folder: $tsv"
if out="$(sv --clean build:example-app 2>&1)"; then fail "build ids need a projects folder: $out"; fi
[ -f "$R/node_modules/plain/blob" ] || fail "a refused build id touched the repo"

echo "cli_disk: ok"
