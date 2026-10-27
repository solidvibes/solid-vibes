---
name: release
description: Get finished work out to the world. Use when someone says "release it", "ship it", "publish it", "merge it", "deploy it", "put it live", "send it to the app store", "cut a release", or "the pull requests are green, take them live".
---

# Release

The last step, and the only one that reaches outside the project: merge green pull requests, deploy, release to the stores, tag. It is small and separate from `go` on purpose. `go` runs without stopping and ends at green pull requests; this skill never runs on its own.

## The rule

**Before every outward step, say in plain words what it does and what it cannot undo, then wait for the user's explicit go.** One go covers one step. A go for the merge is not a go for the deploy. Never run this skill headless, never from a plan, never because a plan says so.

An outward step is anything that others can see or use: merging into the main branch, pushing, deploying, uploading to a store, publishing a release, tagging. Anything pointed at production needs a go in this session, every time, even if an earlier one was given.

What the user reads is plain: "This puts version 1.4.0 on the App Store for review. You can't take it back, but you can release a newer one." Commands stay out of the way.

## The contract

Read the project's Factory contract: the `## Factory` section of `AGENTS.md` in the repo root (spec: `.solidvibes/factory-contract.md`). `risk` says where a release needs the most care; `stack` names the profile; `docs` names the changelog. Missing → say so in plain words and offer the `interview` skill.

## 1. Find out what is ready

- Open pull requests and their checks (`gh pr list`, `gh pr checks`). Ready means: checks green, not a draft, nothing in its body under `## Stopped at` or `## Unresolved findings` left open.
- The changelog's `## Unreleased` lines: what people will notice in this release. Empty → there is nothing to release; say so and stop.
- Existing tags and releases, to avoid reusing a version.
- The profile's `release.md`: from the contract's `stack` field take the profile name (`stack-<name>`), find that profile's folder (the installed skill of that name) and read `release.md` in it if there is one. It holds the deploy and store steps for this stack. No profile or no `release.md` → there are no stack steps: work out from the repo how it goes live (hosting or store config, deploy scripts), say it back in plain words as an outcome ("this puts the website live at example.com"), and ask only where people should get it. Write the steps down in `docs/how-it-works/` once the user agrees, and follow them.
- **No remote or no `gh`**: there is nothing to merge or publish online. Say so plainly, list the steps the user would do by hand, and stop at what can run locally.

Show the plan as a visual per `.solidvibes/agents.md`, else a local HTML file: pull requests to merge, in order, the version and tag, each outward step with a one-line effect, and anything that is not ready and why. Ask the user to confirm the plan. The version number is the one thing that is hard to undo cheaply, so confirm it by itself.

## 2. Merge

For each green, ready pull request, in dependency order, ask for the go and merge it (`gh pr merge`, the method the project already uses). Pending checks are not green: wait for them. After each merge, check the main branch's checks. A red main stops the release: say so, and hand back to `go` or `brief` to fix it.

Never merge a red or draft pull request, never force anything through, never bypass protections. A pull request touching a contract `risk` area that nobody but the agent has reviewed: say that plainly and ask whether the user has looked at it.

After the merges, sweep finished worktrees with `solidvibes worktrees --clean`, after saying so.

## 3. Reconcile the docs

Before the changelog is cleared for the next cycle, run the `review` skill with the docs lens so `docs/how-it-works/` matches what ships. Its scope is what shipped this cycle: the `## Unreleased` lines and the plans added or changed since the last tag (`git log <last tag>..HEAD --name-only` on the contract's `plans`). Before the first release (no tag yet), run it on the whole project, together with the security lens. Show the findings in plain words. Fix the docs drift through `brief` and commit that on its own; ask whether security findings get fixed before the release goes on.

## 4. Prove it before anything is uploaded

Run the contract's `checks.full`; when `harness` is not `none`, also `<harness command> all`, else the project's integration or end-to-end suite if it has one. Any failing suite stops the release: fix it through `brief` or `go`, or ship only with the user's explicit go, naming the failing suite in the report.

## 5. Deploy and store release

Follow the profile's `release.md`, one step at a time, each with its own go. For each: say what it does, run it, read the output and report in one line. An upload counts only when the tool's own confirmation says it landed; never assume it from a zero exit. A step that fails stops the release: report the tail of the output and what was and was not done. Nothing is retried blindly, and nothing is skipped.

Staging comes before production, when the project has both. Credentials come from the environment or the tools' own login, never from a file in the repo; if one is missing, name the variable and stop.

## 6. Tag and publish

With a go: tag the released commit (`v<version>`) and push the tag. With a second go: publish a release page from the `## Unreleased` lines (`gh release create`). Then reset for the next cycle as the project does it: move the changelog lines under the released version, start a new `## Unreleased`, bump the version if the project keeps one in a file. One commit, with a go before it is pushed.

## 7. Report

Plain words: what is live, where, which version, the link to the release, what was skipped and why, and what the user still has to do themselves (a store review, a manual check). Keep it under ten lines.
