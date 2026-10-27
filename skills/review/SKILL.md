---
name: review
description: Review changes as a pull request reviewer would, against the plan, the project's rules, the contract's layers, tests and over-engineering; or look at the whole project through one lens (security, docs, speed, architecture). Use when someone says "review this", "check my changes", "is this ready", "look over what you did", "is it secure", "could someone steal my users' data", "are the docs still true", "is anything out of date", "why is it slow", "is the code in good shape", before a first release or a change to sign-in, payments or personal data, or when a phase or brief needs a quick verdict table from a fresh reviewer.
---

# Review

Review the changes as a PR reviewer would, or look at the project through a lens. Four modes:

| Mode | When | Output |
| --- | --- | --- |
| **Full** (default) | The user asks for a review | Step-by-step review, then the findings table with OK rows |
| **Table-only** | You are a reviewer sub-agent, or the user wants "just the verdict" | The findings table and nothing else, no OK rows |
| **Review-and-fix** | One agent reviews and fixes in the same context (used per phase by `go`, and by `brief`) | Table first, then the fixes |
| **Lens** | One concern, on a diff or on the whole project (see Lenses) | The lens's table, read-only |

What the user reads is plain: a verdict, what was wrong in words, what was fixed. The table keeps its technical detail (file, line, layer); it is for a reviewer and for the PR body.

## The contract

Read the project's Factory contract: the `## Factory` section of `AGENTS.md` in the repo root. Spec: `.solidvibes/factory-contract.md`. Read from `AGENTS.md` only. Missing → say so in plain words and offer the `interview` skill. A missing field gets the same treatment, for that field only; a field set to `none` is answered, not missing.

## Lenses

A lens is one concern looked at closely. Each lives in `lenses/` next to this file; read it and follow it in place of Steps 2–6. A lens is read-only: it reports and changes nothing. It runs on a diff, or on the whole project when the user asks about the project instead of a change.

| Lens | When |
|---|---|
| `lenses/security.md` | "Is it secure?", before the first release, any change to sign-in, payments or stored personal data. Whole project unless a scope is named |
| `lenses/docs.md` | "Are the docs still true?", after `go`'s last phase, before a release |
| `lenses/speed.md` | Something feels slow, or a change touches a list, a query, sync or startup |
| `lenses/architecture.md` | "Is the code in good shape?", a change that adds a part or crosses layers |

Several lenses can run together; as a sub-agent each gets one lens, and the tables are merged.

## Step 1 — Establish scope

- Read the contract.
- List all files modified in this session, or take the diff you were given. A lens on the whole project scopes to the whole project instead: every tracked file.
- If you were given one rule file, you are a **specialist**: check the diff against that file only and skip the rest of the steps.
- Find the plan for this work in the contract's `plans` (default `docs/plans/`; match the feature name or the changed files). Ask only if none matches and the intent is unclear from the diff.

## Step 2 — Plan compliance

If a plan exists, read it. Then check:
- Does the implementation match the approach described in the plan?
- Are all planned files present? Any scope that drifted without being recorded?
- Were the plan's `## Decisions` followed?

## Step 3 — Rules compliance

For each changed file, load the contract's `rules` that apply, and `AGENTS.md`. Then check:
- Layer boundary violations against the contract's `layers` (for example a remote call from UI state, UI logic leaking into a repository).
- Pattern violations the rule or `AGENTS.md` names.
- Anything a rule or `AGENTS.md` explicitly says never to do.
- A rule of a pack listed in `docs/stack.md` `## Packs` broken and not overridden in its `## Overrides`. Name the rule ID.
- Any contract `risk` area touched. Say so: it needs a human reviewer.

## Step 4 — Test coverage

- Does new business logic have tests?
- Are existing tests still valid given the change?
- What is the minimum test that should exist for this?

## Step 5 — Follow-up

- Should any docs be updated (the contract's `docs`, `rules` files, `AGENTS.md`)?
- Behavior changed and no `docs/how-it-works/` doc did → add a finding.
- Did this work surface patterns that are not in any rule or in `AGENTS.md` yet?

## Step 6 — Over-engineering check

Surface anti-patterns that violate "simplest approach that works":
- New abstraction layers without at least two concrete callers.
- Speculative configurability (options or flags for needs that aren't real yet).
- Defensive code for impossible inputs (validation for internal-only callers, null checks on non-nullable values).
- Unused branches, parameters or returned fields.
- Backwards-compat shims, or "removed" comments instead of deletion.
- Speculative interfaces or base classes with one implementation.
- Premature DRY: an abstraction that exists only to deduplicate three or fewer similar lines.

Each is a SUGGEST at minimum, a BLOCKER if egregious or pattern-violating per `AGENTS.md`.

## Specialist review

When the contract's `rules` has topic files, spawn one fresh sub-agent per topic rules file the diff touches, each told to check the diff against that file only, plus one more general reviewer for the plan, the always-on rules, tests and over-engineering. All of them get this skill in table-only mode and the diff. Run them in parallel, merge their tables and drop duplicates. Use the strongest model available for reviewers (in Claude, `opus`). A reviewer never receives earlier findings.

## Output: the findings table

End a full review with a findings table in exactly this format, so it is scannable in a terminal:

```
┌──────────┬────────────────────────────────────────────────────┬──────────────────────────────┐
│ Severity │ Finding                                            │ File                         │
├──────────┼────────────────────────────────────────────────────┼──────────────────────────────┤
│ BLOCKER  │ Watcher ignores depth changes                      │ circle_detail_state:476      │
│ SUGGEST  │ Confirmation page doesn't show depth               │ confirmation_page            │
│ SUGGEST  │ Add round-trip test for depth upsert               │ (new test)                   │
│ OK       │ All imports absolute                               │ —                            │
└──────────┴────────────────────────────────────────────────────┴──────────────────────────────┘
```

- **BLOCKER**: violates a rule, `AGENTS.md`, the plan, or will cause a runtime bug. Must fix before merge.
- **SUGGEST**: an improvement worth considering. Not a merge-blocker.
- **OK**: an explicitly checked rule that passed (include three to five so the user knows what was verified). Full mode only.
- One line per finding; detail goes in the step sections.
- Sort: BLOCKERs first, then SUGGESTs, then OKs.
- If the review is fully clean, a full review still outputs the table with only OK rows.

## Table-only mode

Process silently. Do not output anything from the steps above: no explanations, no per-file walkthrough, no prose. Output only the findings table, nothing before it and nothing after it, with the same columns, no OK rows. If fully clean, output: "No issues found."

If you were spawned as a reviewer sub-agent, stop after the table. Otherwise (the user asked for just the verdict), fix every BLOCKER and every SUGGEST you agree with, without asking, then re-run the contract's `checks.fast`.

## Review-and-fix mode

One agent, one round, no loop. Produce the findings table first, then act on it:
- Fix every BLOCKER.
- Apply each SUGGEST unless it contradicts the plan's `## Decisions`, would break the build, or is wrong (a SUGGEST can be: a "redundant cast" that is load-bearing, for example). Verify before applying; skipping is a legitimate outcome, silently applying a wrong fix is not.
- Findings that only bite a later phase: don't fix them, hand them back for that phase's coder.
- Do not ask "fix all?"; the mandate is to fix.
- Run the contract's `codegen` if matching files changed, then `checks.fast` and the affected tests, then commit once as `fix: review findings (<M>)`. No findings acted on → no commit.
- If a finding is design-level, contradicts the plan, or clearly won't hold in one pass, stop and report instead of fixing blind.

Nothing double-checks this agent, so report plainly: the findings table verbatim, which findings were fixed and which skipped with the reason, and whether any fix forced it outside the plan's `## Approach` or `## Decisions`.

After a full review, end the table by offering to fix and wait for the user's answer.
