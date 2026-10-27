# Ecosystems

Commands, quirks and fallback checks per ecosystem, for steps 3, 5, 6 and 7 of the `update` skill. A listed pack's `references/updating.md` wins over this file for its part.

Run every command in the folder the `solidvibes update` line names. A fallback check runs only for a folder the contract's `checks` don't reach (they don't run in it or name it).

## Flutter and Dart

The `flutter:` line says `flutter` (depends on the Flutter SDK) or `dart` (plain Dart), and `workspace root` / `workspace member` for a pub workspace.

| What | Command |
|---|---|
| Tool | `flutter upgrade`, on the channel it is on; then `flutter pub get` in each folder |
| Tool settings | `flutter config --list`: `enable-swift-package-manager` off → `flutter config --enable-swift-package-manager` (machine-wide), then rebuild |
| Pinned (`pinned <ver>`) | prefix every command with `fvm`: `fvm flutter …`, `fvm dart …`; `flutter upgrade` leaves the pin alone |
| Within ranges | `flutter pub upgrade`; plain Dart: `dart pub upgrade` |
| After a revert | `flutter pub get` (`dart pub get`), then codegen when used |
| Codegen | the contract's `codegen`; else, when `build_runner` is a dev dependency, `dart run build_runner build --delete-conflicting-outputs` |
| Mechanical fixes | `dart fix --apply`, then the checks again |
| Big upgrades, find | `flutter pub outdated` (`dart pub outdated`); `--json` to read it |
| Big upgrades, apply | `flutter pub upgrade --major-versions <pkg> <pkg>`; it rewrites the ranges in `pubspec.yaml` |
| Held back, find | the resolver's error, or `flutter pub deps`; then `held-back.md` |
| New pin | `fvm use <version> --force` (it skips fvm's project checks, which can prompt) in the folder that holds `.fvmrc` (or `.fvm/fvm_config.json`) |
| Fallback check | `flutter analyze` and `flutter test` (`dart analyze`, `dart test`); skip the tests when there is no `test/` folder |

Quirks:
- **`pub outdated` columns.** Current is installed; Upgradable is what `pub upgrade` reaches within the ranges; Resolvable is the newest that fits with every other package; Latest is the newest published. A big upgrade is one where Latest is past Upgradable. Resolvable below Latest means another package holds it back: clear it as `held-back.md` says.
- **Pub workspaces.** Members share one `pubspec.lock` at the root. Run `pub upgrade` and `pub outdated` once, from the `workspace root` folder, and commit the whole workspace together. Never from a member.
- **Newest pin.** The latest stable Flutter is what `flutter upgrade` just installed globally (`flutter --version`), or `fvm releases`. A pin move is a big upgrade: it changes Dart too and can move many packages.
- **Lint packages** (`flutter_lints`, `lints`, `very_good_analysis`). A new version adds rules; the analyzer then fails on code that was fine. `dart fix --apply` clears most of it; what stays is a small adaptation, not a reason to revert.
- **Packages that move together.** A package and its generator or annotations (`freezed` + `freezed_annotation`, `json_serializable` + `json_annotation`, `injectable` + `injectable_generator`, `drift` + `drift_dev`, `retrofit` + `retrofit_generator`) go in one option and one command; then codegen.
- **Platform folders.** An upgrade can touch `ios/Podfile.lock` and Android Gradle files; they belong to the folder's commit.

### Native builds and proof

Step 7, for a folder with `ios/`, `macos/` or `android/`. Add `--flavor <dev>` when the app has flavors.

| What | Command |
|---|---|
| Native dependencies | `pod install --repo-update` in `ios/` and `macos/`; a version conflict → `pod update <pod>` for the pod it names |
| iOS | `flutter build ios --no-codesign --debug` |
| Android | `flutter build apk --debug` |
| macOS | `flutter build macos --debug` |
| Web | `flutter build web` |
| Stale modules | an error about a missing or stale module, or a module built by another compiler → delete `build/<platform>` (`build/ios`, `build/macos`), build again, then diagnose |
| End to end | the contract's integration suite (`run`), or the `harness`, on a booted simulator; never a physical device |

Build only what the contract's `ships` names. A build failure is a new failure: the ladder in the skill.

## Node: npm, pnpm, Yarn 1

The `node:` line names the lock beside the `package.json`: `npm` (`package-lock.json`), `pnpm` (`pnpm-lock.yaml`), `yarn` (`yarn.lock`) or `none`. Use that manager only; never switch managers or add a second lock.

| What | npm | pnpm | Yarn 1 |
|---|---|---|---|
| Within ranges | `npm update` | `pnpm update` | `yarn upgrade` |
| Big upgrades, find | `npm outdated --json` | `pnpm outdated --format json` | `yarn outdated` |
| Big upgrades, apply | `npm install <pkg>@latest`; `-D` for a dev dependency | `pnpm add <pkg>@latest`; `-D` | `yarn add <pkg>@latest`; `--dev` |
| Run a script | `npm run <name>` | `pnpm run <name>` | `yarn <name>` |
| Run a package's binary | `npx <bin>` | `pnpm exec <bin>` | `yarn <bin>` |
| After a revert | `npm ci` | `pnpm install --frozen-lockfile` | `yarn install --frozen-lockfile` |

Quirks:
- **`outdated` exits 1** when something is outdated (npm, pnpm and Yarn 1). That is the answer, not a failure; read the output.
- **`none`.** Look for a lock in a folder above: a workspace. Upgrade once there, from the folder with the lock. No lock anywhere: list the folder, change nothing.
- **Yarn 2 or later** (Berry): `.yarnrc.yml` beside it, or `packageManager` naming `yarn@2` or later. List what is outdated; never upgrade it here.
- **Node itself** is never upgraded. Report `node --version` against `.nvmrc`, `.node-version` or `engines.node` in `package.json`.
- **Fallback check.** The scripts the `package.json` has, in this order: `lint`, `typecheck` or `check`, `test` (not npm's placeholder `echo "Error: no test specified"`), `build`. A folder with none of them: install only, and say it was not checked.

## Astro

A `node:` line marked `astro`. Everything in Node applies.

- Within ranges, the manager's update covers Astro and its integrations.
- **Never `npx @astrojs/upgrade`**: it asks questions in the terminal. Upgrade in one command instead: `npm install astro@latest @astrojs/<x>@latest …` (or the pnpm and Yarn 1 forms) with every `@astrojs/*` package in `package.json`. One option, one commit.
- Before offering an Astro major, read its upgrade guide (`docs.astro.build/en/guides/upgrade-to/v<N>/`) and say what it breaks in plain words.
- Fallback check: `astro check` in the manager's form (`npx astro check`, `pnpm exec astro check`, `yarn astro check`) when `@astrojs/check` is installed, then the `build` script.

## Supabase

A `supabase:` line, `(imports <path>)` when edge functions have an import map.

**The CLI.** Find how it was installed:
- `brew list supabase` succeeds: `brew upgrade supabase`.
- `supabase` is a dependency in a `package.json`: install the latest there with that folder's manager (`npm install -D supabase@latest`) as part of step 5, in that folder's commit.
- Anything else: report `supabase --version` and leave it.

**The local stack.** Its images follow the CLI version and are pulled the next time it starts. To prove the migrations and database tests still pass, ask first, at the baseline: `supabase db reset` wipes local data. On a yes: `supabase db reset`, then `supabase test db` when `supabase/tests/` exists, at the baseline and again after the upgrade. On a no: say the database was not checked locally.

**Never remote.** No `supabase link`, `db push`, `functions deploy`, `--linked` or `--db-url`. Update never reaches a hosted project.

**Edge function imports.** Read the import map (`deno.json` `imports`) and inline `npm:` and `jsr:` specifiers in `functions/**/*.ts`. Find newer versions with `npm view <pkg> version`, and for `jsr:` the package's page on jsr.io. List them only: they change with a deploy, which update never does. Leave `deno.json` and `deno.lock` as they are.

**Fallback check.** None without the yes above.
