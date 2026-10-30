---
name: brainstorm
description: Scope a piece of work, find the decisions that are hard to undo and explore the options before any plan or code. Use when someone says "I'm not sure how to approach this", "let's think about", "what are my options", "help me figure out", "I want to add something but I don't know what", or hands over a new idea, a new screen or a feel change on an existing app, a website section or user-facing wording (those count as unclear by default). The look of a whole new app goes to the `design` skill.
---

# Brainstorm

Understand the problem, find the decisions that are hard to undo, explore the options and land on a recommendation. No plan and no code yet.

How you talk to the user (this is the only mode):
- Say what you are about to do before you do it.
- Scope out loud. One round at a time; group related questions. Ask about outcomes: who uses it, what they see, what they do next, what "done" looks like. Never ask a tech question.
- A technical fork is translated into what it changes for them ("Should this work for everyone who signs in, or only for you?"), never asked as a tech choice. A fork that cannot be translated is decided from `docs/stack.md` (the stack profile) and recorded as the agent's decision, with one plain sentence on why. If it touches a contract `risk` area, show it with a visual and that one sentence.
- Every decision gets a visual (see Visuals).
- Plain words, no file paths, no jargon in what the user reads. Internals below stay technical.

## The contract

Read the project's Factory contract: the `## Factory` section of `AGENTS.md` in the repo root. The spec is `.solidvibes/factory-contract.md`. It is read from `AGENTS.md` only. If `AGENTS.md` or its `## Factory` is missing, say so in plain words ("this project has no setup file yet, so I don't know how it is built or checked") and offer to run the `interview` skill (it reads the repo first and asks only what the code does not answer). Never guess a stack. A missing field gets the same treatment, for that field only; a field set to `none` is answered, not missing.

## Phase 1 — Scope (silently)

- Read the input: an issue, a plan, or a one-line ask.
- Read the contract, then what already decides things: `AGENTS.md`, `docs/intent.md`, `docs/stack.md`, `docs/decisions/`, the `docs/how-it-works/` docs, the contract's `rules` that match, related plans (contract `plans`) and the code the work touches.

## Phase 2 — Clarify the problem

Ask until you understand, a few related questions per round, waiting for each round's answers:
- What outcome is the user actually after?
- What limits apply (time, money, devices, who else is involved)?
- What have they already tried or considered?

Don't assume scope. Ask. When the user jumps to a solution, ask what problem it solves.

## Phase 3 — Find the hard-to-undo decisions

List the decisions this work forces, and keep only the hard-to-undo ones:
- Who owns the data and where it is stored.
- Contracts other systems or clients depend on.
- What later work this makes easier or harder.
- Anything in a contract `risk` area.

Mark each one **settled** (a decision file, a convention, the stack profile; cite it) or **open**. Code inside one service, tests and small UI details are not on this list; the agent decides those.

## Phase 4 — Explore the space

Explore only the open hard-to-undo decisions. Present two or three meaningfully different approaches, only when they genuinely exist. If one is clearly right, say so and why instead of inventing alternatives. For each, in outcome words:
- How it fits the project's constraints (the invariants in `AGENTS.md`, the contract's `layers` and `risk`).
- The tradeoffs.
- What breaks at the edges or under growth.
- How hard it is to reverse if it turns out wrong.

Then land on something: a recommendation per open decision, with clear reasoning. Be direct.

When the goal itself is fuzzy, align on it with a visual first: a few boxes on top, mockups of every screen and state, assumptions called out (the shape of the `plan` skill's final phase).

## Phase 5 — Scope card

Show the card and nothing else:
- **Goal** — one line.
- **Out of scope** — one line.
- **Decisions** — numbered; each tagged settled (with its source) or open, and **mine** (the user's) or **agent's**. Where the user gave no direction and you chose, say "assumed X because Y"; those are what they check.
- **Route** — the next step and why, in one line.

| Situation | Next step |
| --- | --- |
| The goal itself is fuzzy | Align on the goal with a visual first |
| Open hard-to-undo decisions | Decide them here, then record each one as a decision file in `docs/decisions/` (or in the plan's `## Decisions`) |
| Decisions settled, several steps | `plan`: one plan, or several when it exceeds one plan's size budget or phases ship apart |
| One small unit, nothing open | `brief` |

If anything is open or the goal is fuzzy, stop and wait. The user answers per item ("ok", "2: use the first option", "drop 4"), not yes or no; update the card and ask again until it is accepted, then continue into the route. If nothing is open, continue straight into the route without waiting.

## Visuals

"Show a visual" means: make the page with the `eli-solid` skill and show it as `.solidvibes/agents.md` says for the agent in use. If that file is missing, write a local HTML file and tell the user where it is. Decision visuals compare the options side by side; flow and screen visuals draw each state separately.

## At the end

Note any correction or new constraint the user gave that the docs don't reflect yet. Ask if it should be added, on the right side of the line the contract's `docs` field draws: a behavior fact or intent → the behavior docs (`docs/how-it-works/`, `docs/intent.md`); a code rule → a `rules` file (existing or new); a crosscutting invariant → `AGENTS.md`.
