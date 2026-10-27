# Update

**Status:** Built. The CLI is tested here; a real run of the skill in a project is owner-checked, not tested here.

> `update` brings a whole project to the latest of everything, now and then, and ends at a green pull request. The CLI does the counting; the skill does the judging. `hello` still never upgrades.

## The CLI

`solidvibes update [dir]` prints one line each, read-only and offline (git with `--no-optional-locks`), for the repo's top folder. Only what `hello --full` doesn't print; the skill fetches first.

| Line | Says |
|---|---|
| `branch` | current branch, `N ahead, M behind <upstream>` or `no upstream`; `detached at <sha>`; `<branch>, no commits` |
| `default` | the ref as git names it: `origin/HEAD`'s target, else `origin/main`, `origin/master`, `main`, `master`; this branch `N ahead, M behind` it; or `none found` |
| `changes` | `clean` or `N uncommitted file(s)` |
| `unreleased` | `N in <path>`: bullets under `## Unreleased` (or `## [Unreleased]`) in the changelog the contract's `docs` names, else `CHANGELOG.md`; or `no changelog` |
| `branches` | `N local` |
| `flutter` | `<dir> (flutter\|dart[, workspace root\|workspace member][, pinned <ver>])` per `pubspec.yaml`; the pin from `.fvmrc` or `.fvm/fvm_config.json`, in that folder or the nearest one above |
| `node` | `<dir> (npm\|pnpm\|yarn\|none[, astro])` per `package.json`, by the lock beside it |
| `supabase` | `<dir>[ (imports <path>)]` per `supabase/config.toml`; `deno.json` beside it or in `functions/` |

Folders are searched to depth 3, skipping `build`, `node_modules` and dot folders; paths are relative to the top folder (`.` for it), sorted. A kind with no folder prints no line.

## The skill

Called by name. Needs a Factory contract in `AGENTS.md`; without one it offers `interview` and stops.

1. **State**: `git fetch`, `solidvibes update`, `solidvibes hello --full`. Unsaved work: commit it first or stop; never stashed.
2. **Branch**: `update/YYYY-MM-DD` from the `default` ref as printed (e.g. `origin/main`), suffixed `-2`, `-3` when taken; its SHA is the start. A stop after this point switches back, deleting the branch only when it has no commits.
3. **Baseline**: the contract's checks plus per-folder fallbacks, so only new failures count against an upgrade. Red: fix first, or go on.
4. **Housekeeping**: `hello`'s setup refresh, doctor fixes and worktree cleanup.
5. **Tools, settings and small upgrades**: Flutter and the Supabase CLI upgraded on the machine; Node only reported. Tool settings turned on (Flutter's Swift Package Manager, machine-wide). Checks again, so tool failures aren't blamed on packages; a tool upgrade is never undone. Per folder: upgrade within ranges, codegen, commit, checks.
6. **Big upgrades**: all applied by default, one at a time, each with its own commit and checks; packages that move together as one. The owner is asked only about a raised platform minimum that drops users, a change that needs a backend change or deploy, and a risk-area change that needs a hand test. Held-back packages get their blocker cleared (an upstream fix through a marked override, the owner's own package updated and tagged, a group moved together); only what is truly blocked is reported.
7. **Proof**: native dependencies refreshed, every target in `ships` built, then the integration suite or `harness` on a simulator as the final gate.
8. **Audit**: project skills, `docs/stack.md` packs and overrides, CI on GitHub, finished local branches (listed, never deleted), the docs (contradictions, duplicates, bloat). Fixes on a yes.
9. **Pull request** when green, with the technical list in its body; or a local merge into the default branch when the user asks, pushed only on a yes. No net change against the start: no pull request; a branch with no commits is deleted, one with only upgrades and reverts is kept. Not green: no pull request, the branch is kept and the report says why.
10. **Report**: `solidvibes update` again and one short plain message.

Every new failure in steps 5 to 7 goes down one ladder: a mechanical fix, then a small adaptation from the package's migration guide, and a revert only when the fix needs a product or backend decision, saying what it needs.

Commands per ecosystem (Flutter and Dart with fvm and pub workspaces, npm, pnpm, Yarn 1, Astro, Supabase), their fallback checks and native builds are in `skills/update/references/ecosystems.md`; clearing a held-back package is in `references/held-back.md`. A pack listed in the project's `docs/stack.md` with a `references/updating.md` wins over it.

## What it never does

- Touch a remote Supabase. Edge function imports ship with a deploy, so they are only listed.
- Run `supabase db reset` without a yes; it wipes local data.
- Upgrade Node or Yarn 2 and later.
- Run the interactive `npx @astrojs/upgrade`.
- Delete a branch with commits of its own, stash, or force-push.
- Open a pull request with a failure the baseline didn't have.
- Push the default branch without a yes.
