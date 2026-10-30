---
name: interview
description: Start a project with a conversation about the problem, who it is for, why it matters and what it must never do, before anything gets built; then set the project up. Use when someone says "I want to build …", "I have an idea for an app", "new app", "new project", "help me think through an app", "where do I start", "set this project up", "get this repo ready", "the plan has changed", "let's realign", "we're going in a different direction", or when a project has no `docs/intent.md` yet, it is still the unfilled template, or it has no Factory contract.
---

# Interview

The first step of every project: a back-and-forth conversation until you can say the project back in the user's own words and they agree. It records their answers, what each one means for how the thing gets built, and the decisions that follow. Then it sets the project up. Run it again on a described project to realign: what changed, and the decisions that follow.

**Done when** a fresh agent can answer "what are we building, for whom, and what must never happen" from the repo alone.

How you talk to the user (this is the only mode):
- Plain language. Assume no knowledge of git, a terminal or any framework.
- One round at a time; group related questions. Say what you are about to do before you do it.
- Ask about the problem, the purpose and the values. Never about solutions, features or screens, and never a tech question. When the user jumps to a solution ("it should have a calendar"), ask what problem it solves, and write down the problem.
- Help them decide: every question comes with a short recommendation they can take or leave.
- Use their words when you write things down.

## Step 0 — Set up the folder

Silently, after one plain sentence ("I'll set up this folder so we can keep notes as we talk"):
- **An empty folder:** turn on version history (`git init`), then run `solidvibes init --agents <the agent you are> .` with the blank profile. It creates `AGENTS.md` and `docs/` with their empty sections. The stack is chosen at the end; Step 5 brings in its profile then.
- **An existing project:** read the README, the code, `AGENTS.md` or `CLAUDE.md` and `docs/` first. Run `solidvibes init` the same way, unless `.solidvibes/manifest.json` exists: then leave it to Step 5, which refreshes from the manifest. In the conversation, ask only what the repo does not already answer, and say what you found ("The code tells me it runs on phones; is that still the plan?").
- **`docs/intent.md` already filled in:** this is a realign pass. Read `docs/intent.md`, `docs/direction/` and the titles in `docs/decisions/` first. Ask what changed: the problem, who it is for, the values, the direction. Go only through the rounds that moved, in the order of Step 1, skipping the rest. Each change is a decision: write a decision file (a reversal names the decision it replaces) and update `docs/intent.md` and `AGENTS.md` to match. Then say back only what changed (Step 4) and run Step 5 as a refresh.

The `solidvibes` command: in Claude Code the plugin puts it on the path; elsewhere it is `bin/solidvibes` in the Solid Vibes folder, two levels above this file's folder.

## Step 1 — Five rounds, in this order

Open with the map before the first question, one short line each:
1. The problem and who it is for
2. Why it matters
3. The devices, and when you want it
4. How it pays
5. How it gets built
Then we pick the look, then we build.

Each round: two or three related questions at once, follow up until it is clear, a recommendation when they hesitate, then reflect the round's consequences (Step 2), write it down (Step 3), say which round is next. A choice comes as options, each saying what it means and what it costs later, recommended first.

| # | Round | What to find out | A recommendation to offer |
|---|---|---|---|
| 1 | The problem and who it is for | What hurts, for whom, today: a real moment, not a category. Who it is not for | "Start from the one moment it hurts most, for one kind of person. Saying who it's not for makes every later choice easier." |
| 2 | Why, success, values and never | Why this, why now, why you. What success looks like and how they'd notice. What it holds to (no ads, privacy, works offline, kind words). What it must never do | "Something you could see within a month: ten people use it every week." Offer three or four common values to pick from, and "never" examples from them: "Never sell data" |
| 3 | Devices and when they want it | Where people use it, as options: phones / phones and a computer / phones, a computer and the web. When they want a first version, who helps, budget | "Phones first, unless the people you serve sit at a computer." |
| 4 | Business model | Free, paid, subscription, internal, none | "Free or internal is simplest to start. Paying can come later; say if you already know." |
| 5 | How it gets built | The stack in outcome words, and the profile's Interview decisions | See below |

Never estimate how long the AI takes to build it; ask when they want it, and write that down.

**Round 5, the stack.** Look for available `stack-*` profiles (in the skill list, `.agents/skills/`, `~/.agents/skills/`) and read each one's description and `stack.md`. Recommend the one that fits the answers above, and confirm it in one plain line, in outcome words, using the round-3 devices: "It's one app for phones and computers, and keeps working without internet. OK?" Never ask which framework or which devices again. On a yes, rewrite the profile's App row in `docs/stack.md` to the devices from round 3, with one plain sentence of why; setup sets the contract's `ships` and harness `targets` from the same answer. If none fits or none is installed, stay with the blank profile and write each choice into `docs/stack.md` as the answers settle it (devices, where data lives, sign-in, payments), each with one plain sentence of why.

**Interview decisions.** If the chosen profile's `stack.md` has `## Interview decisions`, ask them together in round 5, in order:
- Ask each question in plain words, as options, and show the visual its **Show** line describes (see Visuals).
- Recommend the default in one plain sentence on why, unless earlier answers point elsewhere ("works offline" named as a value → recommend the offline option). A question they can't judge (where to host it) gets the recommendation and why first; they only need to say if they want otherwise.
- Record the answer as a decision (Step 2) with the reason, and write what it sets into `## Packs` of `docs/stack.md`, in place of the default's entries. If the entry has a **Sets row** line, also rewrite that row of the choices table in `docs/stack.md` to match the answer, with one plain sentence of why.

On a realign, revisit one only when the user asks or an answer it depends on changed.

## Step 2 — Reflect the consequences once per round

At the end of each round, show what its answers mean for how the thing is built, as one small table, and ask once if it holds. For example:

| You said | So we build it this way |
|---|---|
| No ads, and privacy matters | No outside trackers, analytics only after people say yes, as little stored about them as we can |
| It has to work offline | The data lives on the phone first and syncs when there's a connection |
| Track everything | A place that collects every event, somewhere to count them, and a clear way to ask permission |

Not every answer has a consequence; don't invent one. They answer per row ("ok", "2: not quite, …"). Write one decision file per accepted row: `docs/decisions/<today>-<slug>.md`, in the shape `docs/decisions/README.md` gives, **Who decided:** mine. The stack choice and the devices get one too. Adjust the rows they correct and show only those again.

## Step 3 — Write it down as you go

Write after each round, so nothing is lost if the conversation stops. Say so once ("I'm writing this down as we go").

| File | What goes in |
|---|---|
| `docs/README.md` | The one line on top: what this is, told to someone who has never heard of it |
| `docs/intent.md` | The problem, who it is for and not for, purpose, values, constraints (devices, when they want it, who helps, budget), business model, never, success, out of scope |
| `docs/direction/vision.md` | Where it could go, in their words: the bigger picture they described, marked as direction, not a commitment |
| `docs/stack.md` | The chosen profile's `stack.md`, or the choices made with the blank profile, each with why |
| `docs/decisions/<date>-<slug>.md` | One per accepted row, one for the devices, one for the stack choice, and one per interview decision |
| `AGENTS.md` `## Project` | One or two lines: what it is, for whom. Replace the placeholder line, keep the rest of the section |
| `AGENTS.md` `## Non-negotiables` | The values and the "never" list, one line each. Replace the placeholder line |

Replace only the placeholders (the lines and table cells in italics, such as "_Not written yet…_" or "_What hurts, for whom, today._"); keep everything else in those files. Never touch the marked blocks in `AGENTS.md` (between `<!-- solidvibes:begin … -->` and `<!-- solidvibes:end … -->`): `solidvibes init` owns them.

## Step 4 — Say it back

When all five rounds are done, say the project back in their words in one short paragraph, and show a visual summary (see Visuals): the problem, who it is and isn't for, the purpose, the values and the never list, what success looks like, the stack in outcome words, and the decisions, numbered, each with its consequence. Ask them to look and correct anything. Update the files and the visual until they approve it.

Then check yourself: reading only `docs/README.md`, `docs/intent.md` and `AGENTS.md`, could a fresh agent answer "what are we building, for whom, and what must never happen"? If not, fix the files.

## Step 5 — Set it up

Say what happens next ("Now I'll write down how the project gets built and checked"), then follow `setup.md` in this skill's folder with the chosen profile. It runs `solidvibes init`, drafts the Factory contract and the project's first rules, and shows them. On a new project it ends by going straight into the `design` skill: the look comes before anything is built.

## Visuals

"Show a visual" means: make the page with the `eli-solid` skill and show it as `.solidvibes/agents.md` says for the agent in use. If that file is missing, write a local HTML file and tell the user where it is.
