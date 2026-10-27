# Stack profiles

**Status:** Built. (The `scaffold/` and `security/` parts are Planned.)

> A stack profile holds every tech opinion in one swappable folder, so the skills never name a stack.

## Intent

New builders should never be asked a tech question. The profile answers them: which tools, how to check and run the project, which areas are risky, the code rules for each part. Swapping a choice is editing one profile; a new stack is a new profile. The generic skills read only the project's contract and `docs/stack.md`.

## Layout

```
stack-<name>/
├── SKILL.md            # frontmatter: name, description, version; optional requires
├── stack.md            # the choices table, packs and overrides → the project's docs/stack.md
├── contract.md         # the Factory defaults → the project's AGENTS.md ## Factory
├── security/<topic>.md # checklists the review security lens works through (Planned)
├── scaffold/           # templates and commands for an empty repo (Planned)
└── release.md          # deploy and store steps the release skill follows (optional)
```

A profile is a skill named `stack-<name>`, so an agent finds it the way it finds any skill. The `blank` profile is the exception: it ships at `setup/profiles/blank/`, and is named `blank`.

## SKILL.md frontmatter

| Key | Required | What it does |
|---|---|---|
| `name` | yes | The profile's name, equal to its folder |
| `description` | yes | When to offer it, as a "Use when" trigger |
| `version` | yes | Semver. Written into every header and into `.solidvibes/manifest.json` |
| `requires` | no | `sv-pro`: setup enables the sv-pro plugin in the project's `.claude/settings.json` and sets the contract's `harness` to `sv-harness`. No entry, no Pro |

## What `solidvibes init --profile <dir>` does with each file

| File | Becomes | Kind |
|---|---|---|
| `stack.md` | the body of `docs/stack.md` (wrapped by the template): the choices table and `## Checks at hello` | seeded: written once, then the project's |
| `contract.md` | the bullets under `## Factory` in `AGENTS.md` | seeded, and only when `AGENTS.md` has no `## Factory` and `CLAUDE.md` holds none either |

`contract.md` holds only the field bullets, in the `- **field** — value` shape the spec in `setup/templates/factory-contract.md` defines. `{{profile}}` in `contract.md` and `stack.md` becomes `<name> <version>`; `{{project}}` becomes the project folder's name.

## Packs and overrides

A profile copies no code rules and no harness into the project. Stack know-how lives once, in the sv-pro plugin, as one skill per area (a pack). The profile's `stack.md` names the packs the project uses and starts its overrides:

```
## Packs
- flutter
- supabase (hosted)

## Overrides
- off: state-bloc:* — we use Riverpod; follow the repo's providers.
- replace: supabase:anon-no-grants — anon reads public_profiles; it is public by design.
- add: Every new table gets a row in docs/how-it-works/data.md.
```

- `off:` takes a rule ID (`<pack>:<slug>`) or `<pack>:*`; `replace:` swaps one rule; `add:` is a project-only rule. Each has a reason after `—`.
- Local always wins. When the AI applies an override, it says so in one line.
- A listed pack with no skill means "follow the pattern this repo already uses".

## Interview decisions

A profile's `stack.md` may hold `## Interview decisions`: the stack choices big enough to ask the user, in the order to ask them. The `interview` skill asks them in its last round, on how it gets built. Each entry:

```
### Data

**Question:** Must the app work without internet, e.g. on a plane or in a basement, and keep everything you did?

- **No (default) → `<pack>`.** What the user notices (works offline? two devices change the same thing? sign-in to see data? effort and running cost). When to pick it.
- **Yes → `<pack>`.** The same, for this option.

**Sets row:** Data.

**Show:** the options side by side, one column each, the default marked.
```

- `### <short name>`, then the outcome question in plain words.
- Two or three options. Each says what the user notices, when to pick it, and what it sets: `## Packs` entries, with a mode suffix such as `(self-hosted)` where it applies. One is marked `(default)`.
- **Sets row** names the row of the choices table (by its first cell) that the answer rewrites. Optional.
- **Show** describes the visual the interview shows before the user answers.

Each answer becomes a decision in `docs/decisions/`, what it sets replaces the default's entries in the project's `## Packs`, and the row **Sets row** names is rewritten to match.

## Rules for init

- `init` never writes through a link: a path whose folder is a link (or a file) is skipped, so nothing lands outside the project.
- Project-specific rules are the project's own skills in `.agents/skills/`; `init` never touches them, and links them for Claude Code.

## Agent profiles

How an agent shows visuals, asks a choice, runs sub-agents and worktrees, and finds skills lives in `setup/agents/<agent>.md` (`claude`, `codex`, `generic`). `init --agents <list>` copies the table row and the section of each agent in use into the project's `.solidvibes/agents.md`. They live in `setup/`, not in a top-level `agents/` folder, because Claude Code loads a plugin's top-level `agents/` as sub-agents.
