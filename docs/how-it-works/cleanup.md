# Cleanup

**Status:** Planned. The CLI is built and tested here; the `cleanup` skill is not built yet.

> Free disk space on the owner's computer. The CLI finds what takes space and does every delete, with its own guards; the skill (to come) explains each item in plain words and asks which ones go. Agent-typed `rm` is never the way: Claude Code denies it, and it has no guards.

## The CLI

```
solidvibes disk [--tsv] [--projects <dir>]          list, read-only
solidvibes disk --clean <id>… [--projects <dir>]    delete those ids, then print freed space
```

`--projects` defaults to `$SOLIDVIBES_PROJECTS_DIR`. With neither, worktrees and build output are skipped and one note line says so. Off macOS, the Xcode, simulator, CocoaPods and SwiftPM categories are skipped. A category whose tool or folder is absent prints no row.

**Output.** A table with `ID  ITEM  SIZE  CLASS  NOTE`, then `free <size> on <volume>` and `total <size>, cleanable <size>`. `--tsv` prints the header `id	item	kb	class	note`, the same rows with sizes in KiB, then `# note	<text>` lines and `# free	<kb>	<volume>`. NOTE holds facts only ("skipped 1 active folder(s)", "running", "used by 2 simulator(s)"); an empty note is `-`.

**Ids** are stable strings, never row numbers, so a rescan between list and clean can't shift what gets deleted.

**Classes**
- `safe`: a cache or build output the tools rebuild by themselves. Cost: time or a download.
- `your-call`: loses something only rebuilt by hand (simulator apps and data, emulators, globally activated Dart tools) or a large re-download (runtimes, DeviceSupport).
- `keep`: shown so the picture is complete; `--clean` refuses it.

## Categories

| id | What | Class | Deleted with |
|---|---|---|---|
| `worktrees` | removable total of the [worktree sweep](../../lib/cli-worktrees.sh) over `--projects` | safe | the sweep itself: same rules, no `--force`, branches kept |
| `deriveddata` | `~/Library/Developer/Xcode/DerivedData/*` with nothing modified in the last 60 min | safe | plain removal per folder |
| `build:<repo>` | per main checkout directly under `--projects`: `build .dart_tool node_modules Pods .gradle .cxx` folders to depth 4 that pass the build guards | safe | plain removal per folder (not `flutter clean`, which would skip the guards) |
| `gradle` | `$GRADLE_USER_HOME/caches` (default `~/.gradle`) | safe | `gradle --stop` if on PATH; skipped while `pgrep -f GradleDaemon` finds one; else plain removal |
| `pub` | `$PUB_CACHE` (default `~/.pub-cache`) | your-call: also removes `dart pub global activate` tools | `dart pub cache clean --force`, else `flutter pub cache clean -f` |
| `npm` | `_cacache` in `npm config get cache` | safe | `npm cache clean --force` |
| `cocoapods` | `~/Library/Caches/CocoaPods` | safe | `pod cache clean --all` |
| `swiftpm` | `~/Library/Caches/org.swift.swiftpm` | safe | plain removal |
| `homebrew` | what `brew cleanup -n --prune=all` would free, old versions included | safe | `brew cleanup --prune=all` |
| `sim-unavailable` | simulators whose runtime is gone | safe | `simctl delete unavailable` |
| `sim:<udid>` | each available simulator; ITEM: name and runtime; NOTE: device type and whether its runtime is the newest that lists that type | your-call; `keep` unless shut down ("running" when Booted) | `simctl delete <udid>` |
| `runtime:<image-uuid>` | each image from `simctl runtime list -j`; NOTE: how many simulators use its runtime | your-call; `keep` when not deletable, or when the simulator list could not be read in full | `simctl runtime delete <image-uuid>` |
| `avd:<name>` | each `$ANDROID_AVD_HOME/<name>.avd` (default `~/.android/avd`) | your-call; `keep` ("running") while a `*.lock` is in it | `avdmanager delete avd -n <name>` |
| `devicesupport:<build>` | each `~/Library/Developer/Xcode/iOS DeviceSupport/*`; the id is the build number in the name's parentheses, else a slug; a folder whose id is already taken gets no row | your-call; the most recently modified is `keep` | plain removal |
| `archives` | `~/Library/Developer/Xcode/Archives` | keep | never: needed to read crash reports of shipped builds |
| `ollama` | `~/.ollama/models` | keep | never |

`simctl` comes from `xcrun --find simctl`. `avdmanager` from PATH, else `cmdline-tools/latest/bin` under `$ANDROID_HOME`, `$ANDROID_SDK_ROOT`, `~/Library/Android/sdk` or `~/Android/Sdk`. Docker is not scanned.

**Reading simctl JSON.** A fresh Mac has no python3 or jq, and Linux has no `plutil`. One awk function reads simctl's pretty-printed `-j` output (one key per line) into flat records. The fixtures in `tests/fixtures/disk/` are real-shaped with placeholder values, so CI runs the real parser. If the format changes, rows go missing; nothing is wrongly deleted, because `--clean` acts only on ids its own scan found, and runtimes turn `keep` when the device count in the raw output and the parsed records differ.

## Guards

**Build output**, all required, re-checked at `--clean`:
1. `git check-ignore` says the folder is ignored. Paths go to git as `./<folder>`, so a name like `:x` is never read as pathspec magic.
2. `git ls-files` finds no tracked file in it.
3. No `.git` in it at any depth, and none between it and the repo (a nested repo or worktree is never build output).
4. Nothing in it modified in the last 60 min, and the repo's index untouched for 60 min.
5. The current directory is not inside that repo.

**Removal.** Every plain removal goes through one function. It refuses when `HOME` is empty or resolves to `/`, the path is relative, a symlink or ends in `/`, its name is `.` or `..`, or its canonical parent plus name is not strictly under the canonical `HOME`. No other root is allowed, so a projects folder outside `HOME` lists build output but can't clean it.

## `--clean`

- Re-scans only the categories the ids name.
- Validates first: an unknown or `keep` id refuses the whole call, deletes nothing and exits 1.
- Order: `worktrees`, build output, caches, `sim:*`, `sim-unavailable`, `runtime:*`, `avd:*`, `devicesupport:*`.
- A `runtime:` image is kept ("used by N simulator(s)") while a simulator not deleted in this call uses its runtime, unless another image of the same runtime is not selected.
- Each item prints `removed <id>  <size>`, or `failed <id>: <first line of the tool's error>` (`kept` / `skipped` for the runtime and Gradle cases). A failure never stops the others and never triggers a fallback: no `rm` after a tool fails, no `sudo`, no `chmod`.
- `worktrees` fails when any worktree removal failed.
- Ends with `free before <size>, after <size>, freed <size>` from `df -k "$HOME"`; exits 1 when any item failed.
