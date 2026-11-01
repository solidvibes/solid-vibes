# solidvibes disk [--tsv] [--projects <dir>]
#   What takes space on this computer, read-only.
# solidvibes disk --clean <id>… [--projects <dir>]
#   Re-scans the categories the ids name, re-checks every guard, deletes only those ids.
#
# Ids are stable strings (gradle, sim:<udid>, runtime:<image-uuid>…), never row numbers.
# Classes: safe (the tools rebuild it), your-call (loses data or tools, or a big re-download),
# keep (shown, never deleted). Each tool's own command first; plain removal only through
# disk_remove, which refuses anything not strictly under $HOME. A failure is reported and
# never retried another way: no rm after a tool fails, no sudo, no chmod.
# docs/how-it-works/cleanup.md has the categories and guards.

# shellcheck source=/dev/null
source "$SOLIDVIBES_ROOT/lib/cli-worktrees.sh"

DISK_IDLE_MIN=60
DISK_UNITS="worktrees deriveddata build gradle pub npm cocoapods swiftpm homebrew sims avd devicesupport archives ollama"
DISK_ROWS=""      # id item kb class note
DISK_TARGETS=""   # id path, for the plain removals
DISK_NOTES=""
DISK_PROJECTS=""
DISK_SIMCTL=""
DISK_AVDMANAGER=""
DISK_DEVICES=""   # udid runtime type state available kb name
DISK_IMAGES=""    # uuid runtime kb deletable
DISK_SELECTED=""
DISK_GONE=""      # udids deleted in this call

disk_row() { DISK_ROWS+="$1	$2	$3	$4	${5:--}"$'\n'; }
disk_target() { DISK_TARGETS+="$1	$2"$'\n'; }
disk_field() { ID="$1" awk -F'\t' -v c="$2" '$1 == ENVIRON["ID"] { print $c; exit }' <<< "$DISK_ROWS"; }
disk_has() { case $'\n'"$1" in *$'\n'"$2"$'\n'*) return 0 ;; esac; return 1; }
disk_darwin() { [ "$(uname -s)" = Darwin ]; }
disk_plain_name() { case "$1" in *$'\n'*|*$'\t'*) return 1 ;; esac; }
disk_idle() { [ -z "$(find "$1" -mmin -"$DISK_IDLE_MIN" -print 2>/dev/null | head -n 1)" ]; }
disk_age() { wt_human_age $((WT_NOW - $(wt_mtime "$1"))); }
disk_free() { df -Pk "$HOME" | awk 'NR == 2 { print $4 "\t" $NF }'; }
disk_short() { printf '%s' "${1##*.}"; }  # com.apple.CoreSimulator.SimRuntime.iOS-18-0 → iOS-18-0

# The one plain removal. The path must be absolute, not a symlink, and its canonical parent plus
# its name must lie strictly under the canonical $HOME.
disk_safe_path() {
  local home parent base
  case "${HOME:-}" in ""|/) return 1 ;; esac
  case "$1" in /*) ;; *) return 1 ;; esac
  [ ! -L "$1" ] && [ -e "$1" ] || return 1
  base="$(basename "$1")"
  case "$base" in .|..|/) return 1 ;; esac
  home="$(cd "$HOME" 2>/dev/null && pwd -P)" || return 1
  parent="$(cd "$(dirname "$1")" 2>/dev/null && pwd -P)" || return 1
  case "$parent/$base" in "$home"/?*) return 0 ;; esac
  return 1
}

disk_remove() {
  disk_safe_path "$1" || { echo "refused, not a folder inside your home: $1"; return 1; }
  rm -rf -- "$1" 2>&1 | sed -n '1p'
  [ ! -e "$1" ]
}

# simctl's pretty-printed -j output (one key per line) → TSV. No python3, jq or plutil needed.
#   devices   udid runtime type state available kb name
#   runtimes  runtime version ,type,type,
#   images    uuid runtime kb deletable
disk_simctl_read() {
  awk -v mode="$1" '
    function unq(s) {
      sub(/,$/, "", s)
      if (s ~ /^".*"$/) { s = substr(s, 2, length(s) - 2); gsub(/\\\//, "/", s); gsub(/\\"/, "\"", s) }
      return s
    }
    function nz(s) { return s == "" ? "-" : s }
    function emit() {
      if (mode == "devices")
        printf "%s\t%s\t%s\t%s\t%s\t%s\t%s\n", nz(f["udid"]), nz(key[2]), nz(f["deviceTypeIdentifier"]), nz(f["state"]),
          nz(f["isAvailable"]), (f["dataPathSize"] == "" ? "-" : sprintf("%.0f", f["dataPathSize"] / 1024)), nz(f["name"])
      else if (mode == "runtimes")
        printf "%s\t%s\t%s\n", nz(f["identifier"]), nz(f["version"]), types ","
      else
        printf "%s\t%s\t%.0f\t%s\n", (f["identifier"] == "" ? key[1] : f["identifier"]), nz(f["runtimeIdentifier"]),
          f["sizeBytes"] / 1024, nz(f["deletable"])
    }
    BEGIN {
      E = (mode == "devices") ? 4 : (mode == "runtimes") ? 3 : 2
      top = (mode == "devices") ? "devices" : (mode == "runtimes") ? "runtimes" : ""
    }
    {
      s = $0; sub(/^[ \t]+/, "", s); sub(/[ \t\r]+$/, "", s); k = ""
      if (s ~ /^"[^"]*" : /) { k = s; sub(/" : .*/, "", k); k = substr(k, 2); sub(/^"[^"]*" : /, "", s) }
      if (s == "{" || s == "[") {
        key[d++] = k
        if (d == E) { split("", f); types = "" }
        next
      }
      if (s == "}" || s == "}," || s == "]" || s == "],") {
        if (--d == E - 1 && (top == "" || key[1] == top)) emit()
        next
      }
      if (k == "") next
      if (d == E) f[k] = unq(s)
      else if (mode == "runtimes" && d == E + 2 && key[E] == "supportedDeviceTypes" && k == "identifier") types = types "," unq(s)
    }'
}

disk_scan_worktrees() {
  local d n
  [ -n "$DISK_PROJECTS" ] || return 0
  wt_init
  WT_CLEAN=false
  for d in "$DISK_PROJECTS"/*/; do
    if [ -d "$d.git" ]; then wt_sweep "${d%/}"; fi
  done
  n="$(printf '%s' "$WT_ROWS" | awk -F'\t' '$10 == "remove"' | wc -l | tr -d ' ')"
  [ "$n" -gt 0 ] || return 0
  disk_row worktrees "finished worktrees" "$WT_REMOVABLE_KB" safe "$n removable"
}

disk_scan_deriveddata() {
  local root="$HOME/Library/Developer/Xcode/DerivedData" d kb total=0 n=0 skipped=0 note=""
  disk_darwin && [ -d "$root" ] || return 0
  for d in "$root"/*/; do
    d="${d%/}"
    [ -d "$d" ] && [ ! -L "$d" ] && disk_plain_name "$d" || continue
    if ! disk_idle "$d"; then skipped=$((skipped + 1)); continue; fi
    kb="$(wt_size_kb "$d")"
    total=$((total + kb)); n=$((n + 1))
    disk_target deriveddata "$d"
  done
  [ "$n" -gt 0 ] || return 0
  if [ "$skipped" -gt 0 ]; then note="skipped $skipped active folder(s)"; fi
  disk_row deriveddata "Xcode DerivedData ($n folder(s))" "$total" safe "$note"
}

# Guards 1-3 of build output: git ignores it, nothing in it is tracked, no .git in it or between it
# and the repo (a nested repo or worktree is never build output).
disk_build_output() { # <repo> <relative folder>
  local repo="$1" rel="$2" p
  git -C "$repo" check-ignore -q -- "$rel" || return 1
  [ -z "$(git -C "$repo" ls-files -- "$rel")" ] || return 1
  [ -z "$(find "$repo/$rel" -name .git -print 2>/dev/null | head -n 1)" ] || return 1
  p="$(dirname "$rel")"
  while [ "$p" != . ]; do
    [ ! -e "$repo/$p/.git" ] || return 1
    p="$(dirname "$p")"
  done
}

disk_repo_idle() {
  [ -e "$1/.git/index" ] || return 0
  [ $((WT_NOW - $(wt_mtime "$1/.git/index"))) -ge $((DISK_IDLE_MIN * 60)) ]
}

disk_scan_repo() {
  local repo="$1" name f rel kb total=0 n=0 skipped=0 here=false note="" b
  local -a names=()
  name="$(basename "$repo")"
  for b in $WT_BUILD_DIRS; do names+=(-o -name "$b"); done
  case "$WT_HERE/" in "$(wt_real_path "$repo")/"*) here=true ;; esac
  while IFS= read -r f; do
    [ -n "$f" ] && disk_plain_name "$f" && [ ! -L "$f" ] || continue
    rel="${f#"$repo"/}"
    disk_build_output "$repo" "$rel" || continue
    if $here || ! disk_idle "$f" || ! disk_repo_idle "$repo"; then skipped=$((skipped + 1)); continue; fi
    kb="$(wt_size_kb "$f")"
    total=$((total + kb)); n=$((n + 1))
    disk_target "build:$name" "$f"
  done < <(find "$repo" -mindepth 1 -maxdepth 4 -name .git -prune -o -type d \( "${names[@]:1}" \) -print -prune 2>/dev/null)
  [ "$n" -gt 0 ] || return 0
  if [ "$skipped" -gt 0 ]; then note="skipped $skipped active folder(s)"; fi
  disk_row "build:$name" "$name build output ($n folder(s))" "$total" safe "$note"
}

disk_scan_build() {
  local d
  [ -n "$DISK_PROJECTS" ] || return 0
  for d in "$DISK_PROJECTS"/*/; do
    if [ -d "$d.git" ]; then disk_scan_repo "${d%/}"; fi
  done
}

disk_scan_gradle() {
  local dir="${GRADLE_USER_HOME:-$HOME/.gradle}/caches"
  [ -d "$dir" ] || return 0
  disk_target gradle "$dir"
  disk_row gradle "Gradle caches" "$(wt_size_kb "$dir")" safe
}

disk_scan_pub() {
  local dir="${PUB_CACHE:-$HOME/.pub-cache}"
  [ -d "$dir" ] || return 0
  command -v dart >/dev/null 2>&1 || command -v flutter >/dev/null 2>&1 || return 0
  disk_row pub "Dart and Flutter package cache" "$(wt_size_kb "$dir")" your-call "includes dart pub global tools"
}

disk_scan_npm() {
  local dir
  command -v npm >/dev/null 2>&1 || return 0
  dir="$(npm config get cache 2>/dev/null)" || dir=""
  dir="${dir:-$HOME/.npm}/_cacache"
  [ -d "$dir" ] || return 0
  disk_row npm "npm cache" "$(wt_size_kb "$dir")" safe
}

disk_scan_cocoapods() {
  local dir="$HOME/Library/Caches/CocoaPods"
  disk_darwin && [ -d "$dir" ] && command -v pod >/dev/null 2>&1 || return 0
  disk_row cocoapods "CocoaPods cache" "$(wt_size_kb "$dir")" safe
}

disk_scan_swiftpm() {
  local dir="$HOME/Library/Caches/org.swift.swiftpm"
  disk_darwin && [ -d "$dir" ] || return 0
  disk_target swiftpm "$dir"
  disk_row swiftpm "SwiftPM cache" "$(wt_size_kb "$dir")" safe
}

disk_scan_homebrew() { # brew prints e.g. "This operation would free approximately 1.2GB of disk space."
  local kb
  command -v brew >/dev/null 2>&1 || return 0
  kb="$(brew cleanup -n --prune=all 2>/dev/null | awk '
    /would free approximately/ {
      for (i = 1; i < NF; i++) if ($i == "approximately") s = $(i + 1)
      n = s + 0; u = s; sub(/^[0-9.]+/, "", u)
      m = (u == "KB") ? 1000 : (u == "MB") ? 1e6 : (u == "GB") ? 1e9 : (u == "TB") ? 1e12 : 1
      printf "%.0f", n * m / 1024
    }')" || kb=""
  [ -n "$kb" ] && [ "$kb" -gt 0 ] || return 0
  disk_row homebrew "Homebrew downloads" "$kb" safe "old versions of installed tools included"
}

disk_scan_sims() {
  local runtimes newest udid rt type state avail kb name note class users n=0 total=0 latest
  local uuid del
  disk_darwin && command -v xcrun >/dev/null 2>&1 || return 0
  DISK_SIMCTL="$(xcrun --find simctl 2>/dev/null)" || return 0
  [ -n "$DISK_SIMCTL" ] || return 0
  DISK_DEVICES="$("$DISK_SIMCTL" list -j devices 2>/dev/null | disk_simctl_read devices)" || DISK_DEVICES=""
  runtimes="$("$DISK_SIMCTL" list -j runtimes 2>/dev/null | disk_simctl_read runtimes)" || runtimes=""
  DISK_IMAGES="$("$DISK_SIMCTL" runtime list -j 2>/dev/null | disk_simctl_read images)" || DISK_IMAGES=""

  # Per device type, the newest runtime that lists it. Never assume the newest runtime supports every type.
  newest="$(printf '%s\n' "$runtimes" | awk -F'\t' '
    function newer(a, b,  x, y, i) {
      split(a, x, "."); split(b, y, ".")
      for (i = 1; i <= 3; i++) if (x[i] + 0 != y[i] + 0) return x[i] + 0 > y[i] + 0
      return 0
    }
    NF == 3 { n = split($3, t, ",")
      for (i = 1; i <= n; i++) if (t[i] != "" && (!(t[i] in v) || newer($2, v[t[i]]))) { v[t[i]] = $2; r[t[i]] = $1 } }
    END { for (k in r) print k "\t" r[k] }')"

  while IFS=$'\t' read -r udid rt type state avail kb name; do
    [ -n "$udid" ] && [ "$avail" != true ] || continue
    if [ "$kb" = - ]; then kb="$(wt_size_kb "$HOME/Library/Developer/CoreSimulator/Devices/$udid")"; fi
    n=$((n + 1)); total=$((total + kb))
  done <<< "$DISK_DEVICES"
  if [ "$n" -gt 0 ]; then disk_row sim-unavailable "$n unavailable simulator(s)" "$total" safe "runtime gone"; fi

  while IFS=$'\t' read -r udid rt type state avail kb name; do
    [ -n "$udid" ] && [ "$avail" = true ] || continue
    if [ "$kb" = - ]; then kb="$(wt_size_kb "$HOME/Library/Developer/CoreSimulator/Devices/$udid")"; fi
    latest="$(T="$type" awk -F'\t' '$1 == ENVIRON["T"] { print $2 }' <<< "$newest")"
    if [ -z "$latest" ]; then note="$(disk_short "$type"), no runtime lists this type"
    elif [ "$latest" = "$rt" ]; then note="$(disk_short "$type"), newest runtime for type"
    else note="$(disk_short "$type"), newer runtime $(disk_short "$latest")"
    fi
    class=your-call
    if [ "$state" = Booted ]; then class=keep; note="running, $note"; fi
    disk_row "sim:$udid" "$name, $(disk_short "$rt")" "$kb" "$class" "$note"
  done <<< "$DISK_DEVICES"

  while IFS=$'\t' read -r uuid rt kb del; do
    [ -n "$uuid" ] || continue
    users="$(R="$rt" awk -F'\t' '$2 == ENVIRON["R"]' <<< "$DISK_DEVICES" | wc -l | tr -d ' ')"
    note="used by $users simulator(s)"
    class=your-call
    if [ "$del" != true ]; then class=keep; note="$note, not deletable"; fi
    disk_row "runtime:$uuid" "$(disk_short "$rt") runtime" "$kb" "$class" "$note"
  done <<< "$DISK_IMAGES"
}

disk_find_avdmanager() {
  local sdk
  if command -v avdmanager >/dev/null 2>&1; then command -v avdmanager; return 0; fi
  for sdk in "${ANDROID_HOME:-}" "${ANDROID_SDK_ROOT:-}" "$HOME/Library/Android/sdk" "$HOME/Android/Sdk"; do
    if [ -n "$sdk" ] && [ -x "$sdk/cmdline-tools/latest/bin/avdmanager" ]; then
      echo "$sdk/cmdline-tools/latest/bin/avdmanager"; return 0
    fi
  done
  return 1
}

disk_scan_avd() {
  local root="${ANDROID_AVD_HOME:-$HOME/.android/avd}" d name class note lock
  [ -d "$root" ] || return 0
  DISK_AVDMANAGER="$(disk_find_avdmanager)" || return 0
  for d in "$root"/*.avd/; do
    d="${d%/}"
    [ -d "$d" ] && disk_plain_name "$d" || continue
    name="$(basename "$d" .avd)"
    class=your-call; note=""
    for lock in "$d"/*.lock; do
      if [ -e "$lock" ]; then class=keep; note=running; break; fi
    done
    disk_row "avd:$name" "$name emulator" "$(wt_size_kb "$d")" "$class" "$note"
  done
}

disk_scan_devicesupport() {
  local root="$HOME/Library/Developer/Xcode/iOS DeviceSupport" d base id newest="" m newest_m=-1
  disk_darwin && [ -d "$root" ] || return 0
  for d in "$root"/*/; do
    d="${d%/}"
    [ -d "$d" ] || continue
    m="$(wt_mtime "$d")"
    if [ "$m" -gt "$newest_m" ]; then newest_m="$m"; newest="$d"; fi
  done
  for d in "$root"/*/; do
    d="${d%/}"
    [ -d "$d" ] && [ ! -L "$d" ] && disk_plain_name "$d" || continue
    base="$(basename "$d")"
    id="$(printf '%s' "$base" | sed -n 's/.*(\([A-Za-z0-9]*\)).*/\1/p')"
    if [ -z "$id" ] || [ -n "$(disk_field "devicesupport:$id" 1)" ]; then
      id="$(printf '%s' "$base" | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9]/-/g')"
    fi
    id="devicesupport:$id"
    if [ "$d" = "$newest" ]; then
      disk_row "$id" "iOS DeviceSupport $base" "$(wt_size_kb "$d")" keep newest
    else
      disk_target "$id" "$d"
      disk_row "$id" "iOS DeviceSupport $base" "$(wt_size_kb "$d")" your-call "untouched $(disk_age "$d")"
    fi
  done
}

disk_scan_archives() {
  local dir="$HOME/Library/Developer/Xcode/Archives"
  disk_darwin && [ -d "$dir" ] || return 0
  disk_row archives "Xcode Archives" "$(wt_size_kb "$dir")" keep "needed to read crash reports"
}

disk_scan_ollama() {
  local dir="$HOME/.ollama/models"
  [ -d "$dir" ] || return 0
  disk_row ollama "Ollama models" "$(wt_size_kb "$dir")" keep
}

disk_scan() { # <unit>…
  local u
  for u in $DISK_UNITS; do
    case " $* " in *" $u "*) "disk_scan_$u" ;; esac
  done
}

disk_unit() {
  case "$1" in
    worktrees|deriveddata|gradle|pub|npm|cocoapods|swiftpm|homebrew|archives|ollama) echo "$1" ;;
    build:*) echo build ;;
    sim:*|sim-unavailable|runtime:*) echo sims ;;
    avd:*) echo avd ;;
    devicesupport:*) echo devicesupport ;;
    *) echo none ;;
  esac
}

disk_phase() {
  case "$1" in
    worktrees) echo 1 ;;
    deriveddata|build:*) echo 2 ;;
    sim:*) echo 4 ;;
    sim-unavailable) echo 5 ;;
    runtime:*) echo 6 ;;
    avd:*) echo 7 ;;
    devicesupport:*) echo 8 ;;
    *) echo 3 ;;
  esac
}

# Runs a tool; on failure prints `failed <id>: <first line of its error>`.
disk_run() { # <id> <cmd>…
  local id="$1" err code=0
  shift
  err="$("$@" 2>&1 >/dev/null </dev/null)" || code=$?
  [ "$code" -ne 0 ] || return 0
  err="$(printf '%s\n' "$err" | sed -n '/[^[:space:]]/{p;q;}')"
  echo "failed $id: ${err:-exit $code}"
  return 1
}

disk_remove_targets() { # <id>
  local id="$1" tid p out ok=0
  while IFS=$'\t' read -r tid p; do
    [ "$tid" = "$id" ] || continue
    if ! out="$(disk_remove "$p")"; then
      echo "failed $id: ${out:-could not remove $p}"
      ok=1
    fi
  done <<< "$DISK_TARGETS"
  return "$ok"
}

disk_clean_worktrees() {
  local d
  wt_init
  WT_CLEAN=true
  for d in "$DISK_PROJECTS"/*/; do
    if [ -d "$d.git" ]; then wt_sweep "${d%/}"; fi
  done
  if [ "$WT_FAILED" -gt 0 ]; then
    echo "failed worktrees: $WT_FAILED could not be removed; see the lines above"
    return 1
  fi
}

disk_clean_runtime() { # <id>
  local id="$1" uuid="${1#runtime:}" rt users others
  rt="$(U="$uuid" awk -F'\t' '$1 == ENVIRON["U"] { print $2 }' <<< "$DISK_IMAGES")"
  users="$(R="$rt" G="$DISK_GONE" awk -F'\t' '
    BEGIN { n = split(ENVIRON["G"], g, " "); for (i = 1; i <= n; i++) gone[g[i]] = 1 }
    $2 == ENVIRON["R"] && !($1 in gone)' <<< "$DISK_DEVICES" | wc -l | tr -d ' ')"
  others="$(R="$rt" U="$uuid" S="$DISK_SELECTED" awk -F'\t' '
    BEGIN { n = split(ENVIRON["S"], s, "\n"); for (i = 1; i <= n; i++) sel[s[i]] = 1 }
    $2 == ENVIRON["R"] && $1 != ENVIRON["U"] && !(("runtime:" $1) in sel)' <<< "$DISK_IMAGES" | wc -l | tr -d ' ')"
  if [ "$users" -gt 0 ] && [ "$others" -eq 0 ]; then
    echo "kept $id: used by $users simulator(s)"
    return 1
  fi
  disk_run "$id" "$DISK_SIMCTL" runtime delete "$uuid"
}

disk_clean_one() { # <id>
  local id="$1"
  case "$id" in
    worktrees) disk_clean_worktrees ;;
    deriveddata|build:*|swiftpm|devicesupport:*) disk_remove_targets "$id" ;;
    gradle)
      if command -v gradle >/dev/null 2>&1; then gradle --stop >/dev/null 2>&1 || true; fi
      if pgrep -f GradleDaemon >/dev/null 2>&1; then
        echo "skipped gradle: Gradle is running; stop it and try again"
        return 1
      fi
      disk_remove_targets gradle ;;
    pub)
      if command -v dart >/dev/null 2>&1; then disk_run pub dart pub cache clean --force
      else disk_run pub flutter pub cache clean -f
      fi ;;
    npm) disk_run npm npm cache clean --force ;;
    cocoapods) disk_run cocoapods pod cache clean --all ;;
    homebrew) disk_run homebrew brew cleanup --prune=all ;;
    sim:*)
      disk_run "$id" "$DISK_SIMCTL" delete "${id#sim:}" || return 1
      DISK_GONE+=" ${id#sim:}" ;;
    sim-unavailable)
      disk_run "$id" "$DISK_SIMCTL" delete unavailable || return 1
      DISK_GONE+=" $(awk -F'\t' '$5 != "true" { printf "%s ", $1 }' <<< "$DISK_DEVICES")" ;;
    runtime:*) disk_clean_runtime "$id" ;;
    avd:*) disk_run "$id" "$DISK_AVDMANAGER" delete avd -n "${id#avd:}" ;;
  esac
}

disk_clean() { # <id>…
  local id units="" class bad=false failed=0 phase before after
  for id in "$@"; do units+=" $(disk_unit "$id")"; done
  # shellcheck disable=SC2086
  disk_scan $units

  for id in "$@"; do
    class="$(disk_field "$id" 4)"
    if [ -z "$class" ]; then echo "refused $id: not found" >&2; bad=true
    elif [ "$class" = keep ]; then echo "refused $id: keep ($(disk_field "$id" 5))" >&2; bad=true
    elif ! disk_has "$DISK_SELECTED" "$id"; then DISK_SELECTED+="$id"$'\n'
    fi
  done
  if $bad; then echo "nothing deleted" >&2; return 1; fi

  before="$(disk_free | cut -f1)"
  for phase in 1 2 3 4 5 6 7 8; do
    while IFS= read -r id; do
      [ -n "$id" ] && [ "$(disk_phase "$id")" = "$phase" ] || continue
      if disk_clean_one "$id" </dev/null; then
        echo "removed $id  $(wt_human "$(disk_field "$id" 3)")"
      else
        failed=$((failed + 1))
      fi
    done <<< "$DISK_SELECTED"
  done
  after="$(disk_free | cut -f1)"
  echo "free before $(wt_human "$before"), after $(wt_human "$after"), freed $(wt_human $((after > before ? after - before : 0)))"
  [ "$failed" -eq 0 ]
}

disk_list() { # <tsv true|false>
  local id item kb class note total=0 cleanable=0 free vol
  # shellcheck disable=SC2086
  disk_scan $DISK_UNITS
  IFS=$'\t' read -r free vol <<< "$(disk_free)"
  if [ "$1" = true ]; then
    printf 'id\titem\tkb\tclass\tnote\n'
    printf '%s' "$DISK_ROWS"
    printf '%s' "$DISK_NOTES" | sed 's/^/# note\t/'
    printf '# free\t%s\t%s\n' "$free" "$vol"
    return 0
  fi
  printf '%s' "$DISK_NOTES"
  if [ -z "$DISK_ROWS" ]; then
    echo "nothing found to clean"
  else
    while IFS=$'\t' read -r id item kb class note; do
      [ -n "$id" ] || continue
      printf '%s\t%s\t%s\t%s\t%s\n' "$id" "$item" "$(wt_human "$kb")" "$class" "$note"
    done <<< "$DISK_ROWS" | { printf 'ID\tITEM\tSIZE\tCLASS\tNOTE\n'; cat; } | column -t -s $'\t'
    total="$(awk -F'\t' '{ t += $3 } END { printf "%.0f", t }' <<< "$DISK_ROWS")"
    cleanable="$(awk -F'\t' '$4 != "keep" { t += $3 } END { printf "%.0f", t }' <<< "$DISK_ROWS")"
  fi
  echo
  echo "free $(wt_human "$free") on $vol"
  echo "total $(wt_human "$total"), cleanable $(wt_human "$cleanable") — solidvibes disk --clean <id>… deletes those rows"
}

cli_disk() {
  local tsv=false clean=false
  local -a ids=()
  while [ $# -gt 0 ]; do
    case "$1" in
      --tsv) tsv=true ;;
      --clean) clean=true ;;
      --projects)
        [ $# -ge 2 ] || { echo "error: --projects needs a folder" >&2; return 1; }
        DISK_PROJECTS="$2"; shift ;;
      -*) echo "error: unknown option: $1" >&2; return 1 ;;
      *) ids+=("$1") ;;
    esac
    shift
  done
  if ! $clean && [ "${#ids[@]}" -gt 0 ]; then echo "error: ids need --clean" >&2; return 1; fi
  if $clean && [ "${#ids[@]}" -eq 0 ]; then echo "error: --clean needs at least one id from solidvibes disk" >&2; return 1; fi

  DISK_PROJECTS="${DISK_PROJECTS:-${SOLIDVIBES_PROJECTS_DIR:-}}"
  if [ -n "$DISK_PROJECTS" ]; then
    [ -d "$DISK_PROJECTS" ] || { echo "error: not a directory: $DISK_PROJECTS" >&2; return 1; }
    DISK_PROJECTS="$(cd "$DISK_PROJECTS" && pwd -P)"
  else
    DISK_NOTES+="projects folder not set: worktrees and build output skipped (pass --projects <dir> or set SOLIDVIBES_PROJECTS_DIR)"$'\n'
  fi
  wt_init

  if $clean; then disk_clean "${ids[@]}"; else disk_list "$tsv"; fi
}
