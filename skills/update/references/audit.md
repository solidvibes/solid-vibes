# Audit

What step 8 of the `update` skill looks for. Each finding is one plain line for the user; the file, line and detail go in the pull request. Fix only on a yes, each fix its own commit. `solidvibes doctor` already reports broken skill links and hand-edited generated files; don't repeat them.

## Project skills

The skills in `.agents/skills/` and `.claude/skills/` (a link in `.claude/skills/` to `.agents/skills/` is the same skill; look once).

| Look for | How | The fix to offer |
|---|---|---|
| Too long | `SKILL.md` over 200 lines | move details into `references/` |
| Gone paths | a backticked path or file name that no longer exists in the repo (skip globs and `<placeholders>`) | point it at the new place, or drop the line |
| Restated pack rules | a rule that says what a rule under `## Rules` in a listed pack's `SKILL.md` already says | delete the local copy; if it differs on purpose, make it a line in `## Overrides` instead |

## `docs/stack.md`

- **Packs that don't exist**: a name under `## Packs` with no installed skill of that name.
- **Overrides with no rule**: an ID (`` `<pack>:<slug>` ``) under `## Overrides` that no listed pack's `## Rules` has. Usually the rule was renamed or dropped; ask whether the override still matters.

## Branches

- **Merged**: `git branch --merged <default>` (the `default` line's ref as printed), without the default branch, the current one and the update branch.
- **Pull request done**: with `gh` available, for each other local branch, `gh pr list --head <branch> --state all --json state,number`; `MERGED` or `CLOSED` counts.
- A branch checked out in a worktree is named with its worktree.

List them only: "N old branches whose work is already in, or was dropped". Never delete one, not even on a yes; name them in the pull request so the user can.

## Automatic checks (CI)

From the `ci` line of `solidvibes hello --full`:
- **`ci: none`**: offer to add them. If the stack profile has a `ci/` folder (the profile named in the contract's `stack`, found as in setup), offer its files. Otherwise draft one with the user: checks run on every pull request, from the contract's `checks`.
- **`ci: present`**: read the workflow files under `.github/workflows/`. Check they run on pull requests only (not on every push to every branch) and filter by path, so a docs change doesn't run the app's tests.

## `## Checks at hello`

Missing from `docs/stack.md`, or still the italic placeholder: draft it from the repo (the tools it uses, the contract's `checks`, what goes stale here). Quick checks only; `hello` runs them every session.

## Docs

Skip this on `docs: same`. Otherwise read `AGENTS.md`, `docs/intent.md`, `docs/stack.md`, `docs/decisions/`, `docs/how-it-works/` and the rules in `.agents/skills/`. Look for:
- **contradictions**: two places that say different things; the newer decision usually wins, so ask;
- **duplicates**: the same rule in two places; keep one, point to it from the other;
- **bloat**: text that says nothing a reader needs, or that grew past its job.

Never edit inside `solidvibes:begin`/`solidvibes:end` blocks or files marked `solidvibes:generated`; those are refreshed by setup.

Propose the merges, cuts or rewrites as a diff, a few lines of why each. After the fixes (or none found), run `solidvibes hello --checked`, so the next run skips this until something changes.
