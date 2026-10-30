---
name: plan
description: Write a plan for a feature or change that is too big for one quick edit, split it into phases and get it approved before building. Use when someone says "let's plan this", "I want to build a feature", "write this up before we start", "this will take several steps", or when a brainstorm ends with settled decisions and several steps to do.
---

# Plan

Create a written plan, review it with a fresh agent, show it as a visual and get it approved. The plan is the source for `go`.

How you talk to the user (this is the only mode):
- Say what you are about to do before you do it.
- One round at a time; group related questions. Ask about outcomes only: who uses it, what they see, what they do next, what "done" looks like. Never a tech question.
- Tech choices come from `docs/stack.md` (the stack profile). Decide them yourself and explain one in a plain sentence when it matters ("Your data stays on the phone first, so it works without internet"). A fork that can't be translated into an outcome is decided from the profile and recorded as the agent's decision; if it touches a contract `risk` area it is shown to the user with a visual and that one sentence.
- Every decision gets a visual. Plain words in what the user reads: no file paths, no plan tables. The plan file itself stays technical.

## The contract

Read the project's Factory contract: the `## Factory` section of `AGENTS.md` in the repo root. Spec: `.solidvibes/factory-contract.md`. Read from `AGENTS.md` only. Missing → say so in plain words and offer the `interview` skill before planning. A missing field gets the same treatment, for that field only; a field set to `none` is answered, not missing.

## Who runs which phase

Planning runs off the main thread, so the conversation stays short:
- **Planner** — one sub-agent runs Phases 1–4 and the rule gaps of Phase 5. Pass it the request, the `brainstorm` scope card if there is one, and the user's answers so far. Sub-agents never ask: a decision Phase 2 must put to the user comes back as an open question; ask it here and continue the planner with the answer (or start a fresh one with the plan path and the answer).
- **Reviewer** — Phase 5's fresh sub-agent, started from the main thread. Its findings go to the planner to fix.
- **Main thread** — the questions, Phase 6 and the hand-off. It never writes the plan itself.

Without sub-agents (see `.solidvibes/agents.md`), run every phase in this thread.

## Phase 1 — Gather context (silently)

- Read the contract.
- Load the contract's `rules` that match the work. `AGENTS.md` covers crosscutting invariants.
- Read related plans where the contract's `plans` says they live (default `docs/plans/`), and the relevant behavior docs from `docs` (`docs/how-it-works/`, `docs/intent.md`, `docs/stack.md`). They are the source of truth for how the system works today.
- When the work touches what people see or read, load the `accessibility` and `writing` skills; when it touches sign-in, payments, personal data or secrets, the `security-basics` skill, whose Step 1 goes in `## Constraints`. Name them in `## Constraints` so the coder loads them too.
- If `brainstorm` ran, its accepted scope card is the input: don't reopen its settled decisions.
- If a parked idea in `docs/ideas/` matches the work, promote it: move it into the plans folder with today's date in front (`git mv docs/ideas/<slug>.md docs/plans/<YYYY-MM-DD>-<slug>.md`), set its `status: idea` to `status: draft`, and write the plan into that file.

## Phase 2 — Surface decisions

Decide the approach before writing. The usual axes:
- Data: where does it live and who owns it?
- Contracts: what do other systems or clients depend on, and does this change it?
- Failure: what happens offline, on error, or half-way through?
- Scope: what is explicitly out of scope?
- Risk: does it touch a contract `risk` area?
- Success: how will we know this is done correctly?

For each, state your answer from project conventions, `docs/decisions/` and the stack profile. Ask the user only about a decision that is hard to undo and genuinely ambiguous, in outcome words. Don't ask questions the project already answers.

Either way, capture the final set of decisions in the plan's `## Decisions` section so the user can review them briefly.

## Phase 3 — Size check

Each plan must fit one coder sub-agent in roughly 300–350k tokens of implementation and produce a diff one reviewer can hold, usually one area (one skill, one `layers` chain). Rough guide: more than about 40 files, more than about 7 steps, or more than two areas means split. Attention degrades on bigger diffs: a 112-file phase once hid 8 blockers that one reviewer would have missed.

Also split when the work is long-running (multi-day, separate PRs) or phases would ship independently.

If splitting: one file per phase (`<slug>-phase-1.md`, …), inner `layers` first (data and contracts), UI last. The split is part of what the user approves in Phase 6. One file with phase sections is also fine (the context stays together), but each phase must pass the size check on its own, and it is executed phase by phase, never as one run (`go` may hand several small phases to one coder while they fit its budget).

## Phase 4 — Write the plan

Write it where the contract's `plans` says (default `docs/plans/YYYY-MM-DD-<slug>.md`, today's date), with YAML frontmatter carrying `status:`, one of `idea`, `draft`, `not-started`, `implemented`, `deferred`. A new plan is `draft`. Use `idea` only for a file still sitting in `docs/ideas/`; moving it into the plans directory promotes it to `draft`.

```
---
status: draft
---

# [Feature Name]
**Date**: YYYY-MM-DD
**Status**: Draft
**Touches**: the behavior docs and rule files whose intent this change lives in, so the decision stays findable from them later (omit if none).

## TL;DR
10–15 bullets a human can skim in 30 seconds: one bullet per file changed or major step, plus key decisions and tradeoffs in one line each. If a bullet needs more than ~12 words, it belongs in the detailed sections below.

## Context
What problem are we solving and why now.

## Constraints
The contract `rules` files that apply, listed by **file path**, so fresh sub-agents (which don't autoload them) get them. Plus any always-on invariants from `AGENTS.md` that are load-bearing for this change, and any `risk` area touched. Plus the pack names from `docs/stack.md` `## Packs` that cover the touched files (for example "Packs: flutter, supabase"), so every sub-agent loads them.

## Approach
The chosen path. Why alternatives were ruled out.

## Files
Every file to create or modify, with full path and a one-line description.

## Steps
Ordered implementation checklist. Each step should be completable independently.

## Decisions
Questions asked → answers given in this session. This is the permanent record. Tag each **mine** (the user's) or **agent's**.

## Verification
What "done" looks like, as checks the `verify` skill can run: the contract's `checks`, the flow to drive per its `run`, a staging check. When the contract's `harness` is not `none`, write each check in harness levels (1 static and unit, 2 wider suite, 3 run the real thing on a target, 4 staging; the `verify` skill defines them). Mark checks only the user can do.

## Rule gaps
Patterns that came up which aren't captured in any `rules` file or in `AGENTS.md` yet.
```

Behavior docs: when the plan adds or changes behavior, add or update the matching `docs/how-it-works/<surface>.md` with status `Planned` (the `go` skill moves it to `Built` in the same change that lands the code).

## Phase 5 — Review (always)

Spawn **one fresh** sub-agent (it never saw you write the plan; strongest model where the agent supports pinning) to review the plan with the `review` skill's table-only mode, against the applicable `rules`, `AGENTS.md` and the code, for latent bugs, wrong reasoning, missed conventions and over-engineering. Pass it the plan paths and the rule file paths, not your conclusions. It returns findings only; the planner fixes the plan for every finding it agrees with, without asking. Never review your own plan in your own context.

Then resolve `## Rule gaps` on the right side of the contract's `docs` line: a **behavior fact, limit or intent** → the behavior docs; a **code rule or gotcha** that fits an existing rule file → update it in place, concisely; a crosscutting invariant → `AGENTS.md`. Only stop to ask when a gap warrants a brand-new rule file or a core change.

Carve-out: a plan is written before implementation, so only apply gaps that are already true. A gap describing the end-state the plan will create stays in `## Rule gaps`; the implementing run applies it when the code lands.

## Phase 6 — Visual summary and approval (always)

This is the human gate. The user won't read the whole plan, and won't read a wall of text either: the page tells them where to look. Show a visual generated from the plan (how: see Visuals), never edited by hand, regenerated whenever the plan changes. Synthesize; don't transcribe.

**Top: 3 to 5 boxes, the only part the user must read.** Each box: a short title and two or three plain sentences. Pick the few things that matter: the outcome, what will change for them, anything that needs their call. Mark the box that needs their attention so it stands out from the ones that are just information.
- **Visuals carry the page.** Mockups are where feedback comes from, so draw generously: every screen the plan changes, every state it has (locked vs unlocked, empty vs full), and where it appears (each platform, entry point). Never one mixed frame; a mockup that mixes states misleads. An architecture diagram only when data or contracts move. When `docs/design/screens.md` has `## How it all works`, put that system picture on the page and draw the mockups in the look from `docs/design/`.
- **Assumptions.** Where the user gave no direction and you chose, say so in a box: "I assumed X because Y." Those are what they check.

**Below: reference they may skip.** Compact lists, no prose:
1. **Decisions** — numbered; mine vs agent's; flag the agent's that are hard to undo.
2. **Risks** — numbered; how it would show. Name every contract `risk` area touched.
3. **Verification** — how we'll know it works; mark the checks only the user can do.

No file or step lists. Ask the user to look at the boxes, and at the numbered items only if they want to. They answer per item ("ok", "3: use the other one", "risk 2 accepted") or comment on the visual; the planner updates the plan, you regenerate the page, and ask again until they accept.

Once accepted, set `**Status**: Approved` and don't ask anything more. Write the next step into `.solidvibes/handover.md`: `- go <plan path>` as the first line under `## Next` (create the file with `# Handover` and `## Next` when missing; keep everything else, and leave `## Snapshot` as it is). Then hand off to `go`, always naming the plan path (a bare "go" can pick the wrong plan or none). `go` builds in sub-agents, so a clean context is needed only when this conversation is already long: under about 250k tokens, say "Building it now: `go <plan path>`" and run `go` with that path here; above it, end with exactly one line, the real path filled in: "Type /clear, then paste: `go <plan path>`".

For a focused bug fix or small addition that doesn't need a lasting record, use `brief` instead. For work you aren't ready to commit to, write one paragraph to `docs/ideas/<slug>.md` instead, with no plan.

## Visuals

"Show a visual" means: as `.solidvibes/agents.md` says for the agent in use. If that file is missing, write a local HTML file and tell the user where it is.
