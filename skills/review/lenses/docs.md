# Docs lens

A lens of the `review` skill: do the docs still match the code? Read-only. Never edit a doc, a rule or code, and never run `codegen`. Fixing comes after, on the user's word: the docs through `brief`, the code through `brief` or `plan`.

The user reads plain words: what is no longer true, and where. `file:line` evidence stays in the report.

## Scope

The whole of `docs/intent.md`, the behavior docs (`docs/how-it-works/`, or wherever the contract's `docs` field points) and `docs/decisions/`, or only what the user named. When run by `go` after its last phase, only the docs the plans touched plus any doc that names a changed file or behavior.

The boundary, from `docs/CONVENTIONS.md`: docs say what the project does (facts and intent); rules say how to change the code.

## Steps

1. **Extract claims.** Read each doc in scope and list its checkable claims: what a part does, a limit, a default, a schedule, a name, a flow, a "never". Skip opinion and intent that has no observable form. A `Planned` doc claims nothing yet; list it only when the code already does what it plans (then its status is stale). An `Open question` is skipped.
2. **Find the truth in the code.** For each claim, find where the code decides it, walking the contract's `layers`. Read the code; never judge a claim from another doc. Decisions are checked for what they still require: a decision that says "X is stored on the device" is a claim about the code.
3. **Judge.** Each claim is true, no longer true, or unverifiable (say what would settle it). Only the second goes in the drift list. For a claim you cannot find in the code at all, say "no code found" and give where you looked.
4. **List the drift.** One entry per claim that is no longer true, always all three parts:

| Doc line | What it claims | What the code does |
|---|---|---|
| `docs/how-it-works/<part>.md:<line>` | the claim, quoted | what happens instead, with `<file>:<line>` |

   A claim and code that agree are not listed. Group entries by doc. Add two short lists below: **unverifiable claims** and **behavior the code has that no doc mentions** (one line each, with `file:line`).
5. **Say the verdict plainly.** "All N claims checked are still true", or "N claims are no longer true, listed above", then offer `brief` to fix them.

If nothing drifted, say so. A clean check is a valid result.
