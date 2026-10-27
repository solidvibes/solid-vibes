---
name: update
description: Bring a whole project to the latest of everything, now and then. Upgrade the tools, their settings and every package, big upgrades included, ask only about the ones that need the owner's call, prove the app still builds and works, and end in a pull request. Use when someone says "update", "update everything", "upgrade everything", "upgrade Flutter", "update the packages", "are we on the latest versions", "bring the repo up to date" or "bring the project up to date". Not for "update the docs": that is a small change.
---

# Update

A heavy run, done now and then. Its goal is the latest of everything: tools, tool settings, every package, big upgrades included. Someone who wanted one small bump would not have started it. It works on a fresh branch, proves the app still builds and works, and ends at a green pull request. `hello` starts a session light and never upgrades or audits; this one does both.

How you talk to the user:
- Plain words, outcomes only. Say what you are about to do before you do it.
- Short. One line per thing found; package names and versions go in the pull request.
- A choice comes as options, each saying what it means and what it costs later, recommended first. How this agent asks: `.solidvibes/agents.md`.

The `solidvibes` command: in Claude Code the plugin puts it on the path; elsewhere it is `bin/solidvibes` in the Solid Vibes folder, two levels above this file's folder.

## The contract

Read the project's Factory contract: the `## Factory` section of `AGENTS.md` in the repo root (spec: `.solidvibes/factory-contract.md`), from `AGENTS.md` only. `checks` says how to prove nothing broke, `codegen` what to regenerate, `ships` what to build, `run` and `harness` how to prove it works, `risk` where to take care.

## Never

- Never touch a remote Supabase: no `db push`, `link`, `functions deploy`, `--linked` or `--db-url`. Edge function imports ship with a deploy, so they are only listed.
- Never wipe local data without a yes: `supabase db reset` runs only after the user agrees.
- Never stash, never force-push, never delete a branch that has commits of its own.
- Never push the default branch without a yes.
- Never open a pull request with a failure that wasn't there before the run.

## 1. State

Say "I'll look at where the project stands first." Then, from the repo root:
- `git fetch` (no remote: skip it);
- `solidvibes update`: the branch and the default branch, ahead and behind; uncommitted files; the changelog's unreleased lines; local branches; then one line per project folder: `flutter: <dir> (…)`, `node: <dir> (…)`, `supabase: <dir> (…)`;
- `solidvibes hello --full`: setup, docs, doctor and the worktrees table.

No contract in `AGENTS.md`, or `setup: none`: say so in plain words, offer the `interview` skill, and stop.

`changes` is not `clean`: say there is unsaved work and offer: save it first on a branch of its own (recommended), save it on the current branch, or stop here. For the second, say which branch that is in plain words; on the default branch, the work lands straight on the main version. Never stash it.

Read the packs listed in `docs/stack.md` `## Packs`. A pack whose skill has `references/updating.md` wins over `references/ecosystems.md` for its part; say in one line when one applies.

## 2. Branch

Say "I'll work on a fresh copy of the latest version, so nothing changes until you approve it." Note the current branch, then `git switch -c update/YYYY-MM-DD <default>` with today's date, `-2`, `-3` when the name is taken. `<default>` is the `default` line's ref as printed (`origin/main`, or `main` with no remote); `default: none found`: from the current branch. Record `git rev-parse HEAD` as `<start>`. Inside a worktree this works the same.

**Stopping early.** Any stop after this step (a red baseline the user wants fixed first, a no): switch back to the branch the user started on. Delete the update branch (`git branch -D`) only when `git rev-list <start>..HEAD` is empty; otherwise keep it and name it.

## 3. Baseline

Run the checks once before anything changes, so only new failures are blamed on the upgrades: the contract's `checks` (full), plus the fallback from the ecosystem reference for each folder those checks don't reach.

Green: say so in one line and go on. Red: say what fails in plain words and ask: fix it first (recommended; the run stops early and the fix goes through `brief`), or go on and judge only new failures. Keep the failing list for the pull request.

## 4. Housekeeping

As in the `hello` skill, cited, not repeated:
- `setup: differs`: its Step 3 setup refresh, in its own commit;
- doctor problems: its Step 3 offer, one plain line each, fixed only on a yes;
- worktrees marked `remove`: its Step 4, saying so first, then `solidvibes worktrees --clean <repo root>`.

## When something fails

Every new failure in steps 5 to 7 goes down this ladder, each rung in a commit of its own, checks after each:
1. **Mechanical**: codegen, `dart fix --apply`, a deprecation whose message names a replacement that returns the same kind of value.
2. **Small adaptation**: read the package's migration guide or changelog and change the code it names.
3. **Revert**, last: only when the fix needs a product or backend decision. Revert newest first (`git revert --no-edit <first>^..HEAD`), re-sync what is installed and rerun codegen (`references/ecosystems.md`, "After a revert"), and note what the fix needs ("the push sender has to change first").

A fix that touches a contract `risk` area gets the `review` skill before the run goes on.

## 5. Tools, settings and small upgrades

Say "I'll upgrade the tools on this computer and the small package updates, and check after each part." Commands, quirks and fallbacks per ecosystem: `references/ecosystems.md`.

Tools, on this computer:
- Flutter, when a `flutter` line names one: `flutter upgrade`. With a pinned version the project keeps its pin and every Flutter command runs as `fvm flutter`; the newest pin is applied in step 6.
- Supabase CLI, when a `supabase` line exists: the way it was installed (Homebrew, or the repo's dev dependency).
- Node: never upgraded. Report the version against `.nvmrc`, `.node-version` or `engines`.

Then the tool settings the reference lists (Flutter: Swift Package Manager). A setting that is off is turned on; say first when it is machine-wide and so affects every project on this computer.

Run the checks again before any package moves, so a failure from the new tools isn't blamed on a package. A tool upgrade is never undone: a new failure it causes goes down the ladder without its last rung, or is noted as needing the user.

Then per project folder, in the order the update lines list them:
1. Upgrade within the allowed ranges (`flutter pub upgrade`, `npm update`, …). A pub workspace runs once, from its `workspace root`. Yarn 2 or later: list only.
2. Run the contract's `codegen` when it applies to that folder.
3. Commit that folder alone: `Update <folder> packages within their ranges`.
4. Run the checks: the contract's, plus the folder's fallback when they don't reach it.
5. A new failure: the ladder above.

## 6. Big upgrades

Find every one: `flutter pub outdated` per folder, `npm outdated`/`pnpm outdated`/`yarn outdated` (they exit 1 when something is outdated; that is the answer, not a failure), the fvm pin against the latest stable Flutter, and edge function imports (the `imports` path on the supabase line, and inline `npm:`/`jsr:` specifiers under `functions/`).

Group packages that move together into one: a generator with its annotations, `astro` with its `@astrojs/*` integrations, packages that share a held-back dependency (`references/held-back.md`).

**Held back is not done.** A package whose Resolvable stops below Latest has a blocker. Find it and clear it as `references/held-back.md` says: an upstream fix through a marked override, the owner's own package updated and tagged, or a group that moves together. Only what is truly blocked stays, with its reason.

**Apply all of them by default.** Ask only about the ones that need the owner's call:
- raising a platform minimum that drops users (macOS 10.15 → 12, an older Android);
- one that needs a backend or server change, or a deploy;
- one in a `risk` area that needs a hand test (sign-in, payments, push).

Say it in one message: "Applying all of these; these N need your call." Each call in plain words, with what it gets and what it costs, recommended answer first. No calls: say what is being applied and go.

Apply them one at a time: the command from the reference (`flutter pub upgrade --major-versions <pkgs>`, `npm install <pkg>@latest …`; never the interactive `npx @astrojs/upgrade`), codegen, its own commit, the checks, the ladder on a failure.

Edge function imports are only listed, for a deploy the user does separately.

## 7. Proof

`flutter analyze` and the tests don't see native builds. For an app, after the upgrades (commands: `references/ecosystems.md`, "Native builds and proof"):
1. Refresh native dependencies (CocoaPods for iOS and macOS).
2. Build every target the contract's `ships` names, debug, with the dev flavor when the app has flavors.
3. The final gate: the contract's integration or end-to-end suite on a simulator, or the `harness` when it is not `none`. Never a physical device. A suite that needs the owner's secrets: name it in the report as theirs to run.

A failure goes down the ladder. A build that fails on stale modules: clear that platform's build folder and build again before diagnosing.

## 8. Audit

Look for what went stale (`references/audit.md`): project skills, `docs/stack.md` packs, overrides and hello checks, the automatic checks on GitHub, local branches whose work is already in, and the docs. One plain line each. Fix only on a yes, each fix its own commit. Branches are listed, never deleted.

## 9. Pull request

No net change (`git diff --quiet <start> HEAD`): no pull request; switch back to the branch the user was on. No commits at all (`git rev-list <start>..HEAD` is empty): delete the branch (`git branch -D`, safe only because it holds nothing) and say nothing needed upgrading. Only upgrades and their reverts: keep the branch and say so in the report.

Not green at the end (a check green at the baseline now fails, say from a tool upgrade): no pull request. Switch back, keep the branch, and say why in the report.

Otherwise, when every check that was green at the baseline is green: push the branch (`git push -u origin <branch>`) and open the pull request (`gh pr create --title "Update dependencies YYYY-MM-DD" --body-file <temp file>`). The body, technical:
- tools and settings: Flutter, Supabase CLI, before → after; settings turned on; Node against the project's pin;
- per folder: packages before → after;
- big upgrades applied, and the calls the owner made;
- held back, with the blocker; overrides added, with when to remove them;
- adapted, with the migration guide; reverted, with what the fix needs;
- the builds and the end-to-end suite, with their results;
- edge function imports waiting for a deploy;
- baseline failures, if the user chose to go on;
- audit fixes, and the branches listed.

No remote or no `gh`: skip the push and the pull request, say so, and name the branch.

**Merge locally instead.** When the user asks to merge into the default branch instead of opening a pull request: same green rule, then `git switch <default>` and `git merge --no-ff <branch>`. Ask before pushing the default branch.

## 10. Report

Run `solidvibes update` again. Then one short message, plain:
- where the repo stands: branch, ahead and behind, unsaved work, unreleased changes;
- what was upgraded, in a line or two, and that the builds and end-to-end run passed;
- what is still held back, each with its reason in plain words;
- what was undone and what its fix needs;
- what needs the user (a deploy for edge functions, a hand test, a local reset they declined, stale branches);
- the pull request link, the merge, or the branch kept and why.
