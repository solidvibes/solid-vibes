# Set it up

How a project gets set up for Solid Vibes, or brought up to date. Not a skill of its own: the `interview` skill follows it at its end, and a refresh follows it whenever the project's setup is older than the installed Solid Vibes. Safe at any point. It never deletes anything and never changes what the user wrote, with one exception (step 3) that needs their yes.

The `solidvibes init` command does the writing; these steps decide what to pass it, explain the result, and draft the Factory contract and the project's first rules.

How you talk to the user:
- Say what you are about to do before you do it. Plain words, no file paths unless they ask.
- Ask only what setup can't decide itself, one round at a time; group related questions. Never a tech question: tech choices come from the stack profile.
- Standard behaviour (the checks, tests on fakes, flavors, which areas get a closer review) is never put to the user: write it in and say so in one line.
- The only questions left: the profile, when the interview did not choose one (Step 1); a `skipped` file, a broken-marker fix and the sv-pro settings (Step 2); the CLAUDE.md move (Step 3); and a change to a value someone already wrote (Step 4).
- Every decision gets a visual (see Visuals).

## Step 1 — Choose the profile and the agents

**Refresh** (`.solidvibes/manifest.json` exists): take both from the manifest, never the blank defaults. `profile.name` names the profile: `blank` is the blank profile below; any other name is the `stack-*` skill of that name, found as on a first setup. `agents` is the list to pass. If the named profile cannot be found, say so and stop; never refresh with a different one.

**First setup:**
- **Profile.** If the contract's `stack` names a profile, use that one. Else, if a `stack-*` skill is available (in the skill list, `.agents/skills/` or `~/.agents/skills/`) and fits what `docs/intent.md` and the code say, offer it in outcome words, using the devices from the interview ("It's one app for phones and computers, and keeps working without internet. OK?") and use its folder on a yes. If its `stack.md` has `## Interview decisions`, settle them as round 5 of `SKILL.md` in this folder says. Else the blank profile: `setup/profiles/blank/` in the Solid Vibes folder, two levels above this file's folder. The format is in `docs/how-it-works/profile-format.md` of the Solid Vibes repo.
- **Agents.** The agent you are (`claude` for Claude Code, `codex` for Codex, `generic` for anything else), plus any other AI tool the user says they use. Unsure: all three (the default).

**The command.** `solidvibes`. In Claude Code the plugin puts it on the path. Elsewhere it is `bin/solidvibes` in the Solid Vibes folder, two levels above this file's folder.

## Step 2 — Run it

If the folder has no version history yet (no `.git`), say so in one line ("I'll turn on version history, so every change is saved and can be undone") and run `git init`.

Say: "I'll set up the project's files now. Nothing you have written gets deleted or rewritten; I only add what is missing." Then run, from the project root:

```
solidvibes init --profile <profile folder> --agents <list> .
```

Its output has one line per file: `created` (new, now the project's own), `wrote` and `updated` (Solid Vibes' own files, refreshed), `unchanged`, `kept` (already there, left alone), `linked`, `skipped` (something of the user's sits where Solid Vibes wanted to write; left alone). Tell the user in one or two sentences what was set up and what was left alone. For each `skipped` line, say what it means and ask what they want; never move their file without a yes.

If it stops with an error about broken markers in `AGENTS.md`, show the user the broken spot and fix only those marker lines after their yes, then run it again.

**Pro stack.** When the profile's `SKILL.md` frontmatter has `requires: sv-pro`, merge into the project's `.claude/settings.json` (create it if missing; keep every other key), showing the diff first and writing it on their yes. Say why in one line: "This turns on the stack know-how for this project only, and keeps it up to date."

```json
{
  "enabledPlugins": { "sv-pro@solid-vibes": true },
  "extraKnownMarketplaces": {
    "solid-vibes": { "source": { "source": "github", "repo": "solidvibes/solid-vibes" }, "autoUpdate": true }
  }
}
```

## Step 3 — A contract in CLAUDE.md (only when the command says so)

When the output says `CLAUDE.md holds a ## Factory`, the skills cannot see the contract: they read it from `AGENTS.md` only. Show the move as a visual (both files, before and after) and ask in plain words: "Your project's setup notes sit in a file only Claude reads. Can I move them to AGENTS.md, so every AI tool reads them? The notes stay word for word."

On a yes, and only then:
1. Cut the `## Factory` section from `CLAUDE.md`, from its heading to the next `## ` heading, word for word.
2. Put it at the end of `AGENTS.md`.
3. Make sure `CLAUDE.md` has the line `@AGENTS.md` (the command already added it).
4. Run `solidvibes init` again; it must report nothing new to write for the contract.

Without a yes, leave both files as they are and say once that the other skills will report the contract as missing until it moves. This is the only place setup changes existing content.

## Step 4 — Draft the contract

The spec is `.solidvibes/factory-contract.md`. Go through each field of `## Factory` in `AGENTS.md`:
- A field still at the blank profile's value or the chosen profile's default, or `none` where the project now has something: draft it from the repo (package files, scripts, test commands, CI files, the README's run steps) and the chosen profile's `contract.md`. If a `stack-*` profile was chosen after a blank start, its `contract.md` values replace the blank ones, and `stack` names it.
- On a first setup, write those drafted fields straight in; don't ask.
- A value the user or an earlier session wrote is theirs: propose a change, never overwrite it silently.
- Never invent a command for something that does not exist. `none` is an honest answer.
- Commands run as written from the repo root. Run `checks.fast` to prove it before you write it in.
- `risk` comes from the code and `docs/intent.md`: sign-in, payments, people's data, database changes, anything the intent's "Never" section names.
- `sandbox` paths start with `~` or a variable, never a fixed home folder.
- `ships` and the harness `targets`: from the devices decision of the interview (round 3), keeping only the profile's entries for those devices.
- `harness`: when the profile requires `sv-pro`, `` `sv-harness` · levels … · targets … `` with the levels from its `contract.md` and the targets above; else `none`.

Explain the draft in plain words, one line per field that matters to the user ("Before every save, I run the checks: …", "Changes to sign-in or payments always get a human review"), and show it as a visual: one page on how the project is built, checked and run, with the risk areas marked. Only a change to a value someone already wrote waits for their ok.

On a refresh where every field already holds a value, there is nothing to draft: skip this step.

## Step 5 — The project's own rules (first setup only)

When the profile's `SKILL.md` frontmatter has `requires: sv-pro`, skip every topic a pack listed in `docs/stack.md` `## Packs` covers (testing, data, layers usually are); write only facts that belong to this project, in the form below, and nothing when there are none. Without sv-pro, draft a few short, generic rules for this project from the interview, `docs/stack.md` and the code, each as a seeded skill in `.agents/skills/<topic>/SKILL.md`. Three or four at most, for example:
- **testing** — how a change gets tested here and which command runs the tests.
- **data** — where the data lives, and what must never leave it.
- **layers** — the parts of the code and which part may call which, matching the contract's `layers`.

Each file opens with frontmatter: `name` equal to its folder, and a `description` that says when it applies, in the words of the change ("Use when a change adds or changes a test", "Use when a change reads or stores data"). The body is a handful of lines: how to do it, what never to do. Generic, no invented detail; leave out a topic the project has nothing to say about yet. Never touch a topic folder that already exists.

Don't ask about them; say what you wrote in one line per rule. When you wrote any, run `solidvibes init` again with the same profile and agents: when `claude` is among the agents, it links each `.agents/skills/<topic>` folder to `.claude/skills/<topic>` (one `linked` line per rule), which is how Claude Code finds them; Codex and other agents read `.agents/skills/` directly. These rules grow later, from corrections and decisions.

## Step 6 — Wrap up

One line per thing done, and one for what was left alone.

In a folder whose version history you just turned on, save a first version (a commit) with everything setup wrote, without asking. In an existing project, don't commit: show what changed and let the user look.

**Status bar** (agent `claude` only; before what happens next, so a new project gets it too): run `solidvibes statusline --check`. On `statusLine: none`, offer it in one sentence ("Want a bar at the bottom that shows the folder, how full my memory is, and when to start fresh?") and show, as a diff, the `entry` line added as a top-level key of the `settings` file it names (a missing file becomes `{ <entry> }`). On a yes: run `solidvibes statusline --install`, then write that change with your edit tool, keeping the file valid JSON. On a no: run `solidvibes statusline --decline`, so it isn't offered again. Any other `statusLine` line: say nothing about it. Never replace a status line.

Then what happens next:
- **First setup of a new project** (no app code and no `docs/design/` yet): one line ("Next we pick the look") and continue into the `design` skill without asking.
- **First setup of an existing project:** ask what they want it to do next; the routing in `AGENTS.md` takes it from there.
- **A refresh:** stop after the report.

## Visuals

"Show a visual" means: make the page with the `eli-solid` skill and show it as `.solidvibes/agents.md` says for the agent in use. If that file is missing, write a local HTML file and tell the user where it is.
