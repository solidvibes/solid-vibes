# Solid Vibes

The plugin `sv` and the `solidvibes` CLI. Skills, templates and scripts here change how every project that installs them behaves, so a bad line here is followed everywhere. The rules below exist for that reason.

Knowledge lives in `docs/`: decisions in `docs/decisions/`, behavior in `docs/how-it-works/`.

## Invariants

- **No owner data, ever.** No personal names, emails, owner paths (`/Users/<name>`, a home projects folder), project refs, bundle ids, team ids, device ids, Slack channels or people, analytics ids, secrets or signing material. Examples use `example.com`, `com.example` and placeholders. `scripts/strip-check.sh` runs before every commit; never skip it.
- **Behavior here, data in the project.** Skills, formats and scripts live here and are the same everywhere. What varies per project lives in that project (`AGENTS.md`, `docs/`, `.solidvibes/`).
- **Generated vs seeded.** Every file `init` writes is one or the other. Generated files are owned here, carry a header naming the refresh, and are overwritten on every run; never edit them in a project. Seeded files are created only if missing and never touched again. If you cannot say which a new file is, it is seeded.
- **Init creates; it never fixes.** It does not reorganize, migrate or correct an existing structure, and it never deletes. The one exception is moving a `## Factory` from `CLAUDE.md` into `AGENTS.md`, and only after the user says yes.
- **Anything that deletes is a risk area.** `worktrees --clean` removes only what is provably finished, without `--force`, and never deletes branches. When in doubt, it stays.
- **Plugin hooks act only in projects with `.solidvibes/manifest.json`.** Anywhere else they exit 0 and write nothing. They never block.
- **Bash for the CLI.** No runtime to install; works on a fresh macOS or Linux machine, including the bash 3.2 macOS ships.

## Secrets

- Nothing here needs a credential, and the design goal is that it never does.
- If something ever does: it comes from the environment or a file outside every repo, never a committed file.
- Never echo a secret into a log line, an error, a commit or a report. A script that prints its environment on failure is the bug.
- Pre-flight for a credential's presence and fail with the variable's name, never its value.
- The strip check and the linter name file, line and category, never the matched value.

## Audience

Solid Vibes is a setup for builders. Anyone can be a builder. Skills are written so a teacher or a dentist with an idea can follow them; a developer uses them as they are. One product, no beginner and expert tracks.

- Plain language, outcomes only. Ask who uses it, what they see, what they do next, what "done" looks like. Never ask a tech question.
- Tech choices come from the stack profile. Explain one in a plain sentence when it matters.
- Every decision gets a visual.
- Assume no knowledge of git, a terminal or any framework. Spell out each step, or do it after saying what you will do.
- One round at a time; group related questions.
- A choice comes as options, each saying what it means and what it costs later, recommended first.
- Never estimate how long the AI takes; ask when they want it.
- Approved means go: don't ask before the obvious next step.
- Reports say what changed and how it was checked. Technical detail goes in the PR body.
- Skills keep their technical internals; only what the user reads and answers is plain.

## Working style

- Simplest approach that works. No speculative abstractions, feature flags or compat shims.
- No comments unless the logic isn't self-evident.
- Skill descriptions are trigger conditions ("Use when …") in the user's own phrases.
- Only `interview`, `release`, `hello`, `bye`, `update` are called by name; the rest are routed.
- Deterministic work in the CLI, judgment in the skill.
- No `~/.claude` paths in skills; they cite `.solidvibes/factory-contract.md` in the project.

## Factory

- **layers** — skill (`skills/*/SKILL.md`) → reads the project contract (`.solidvibes/factory-contract.md` spec) → calls `bin/solidvibes` (`lib/cli-*.sh`) → writes the project (`init` templates) · plugin: `.claude-plugin/marketplace.json` → `plugin.json` → `skills/`, `bin/`, `hooks/hooks.json`
- **checks** — fast: `bash -n bin/solidvibes lib/*.sh scripts/*.sh && bin/solidvibes lint . && scripts/strip-check.sh` · full: `bash -n bin/solidvibes lib/*.sh scripts/*.sh && bin/solidvibes lint . && scripts/strip-check.sh --history && tests/run.sh && (if command -v claude >/dev/null; then claude plugin validate .; else echo "claude CLI absent: plugin validate skipped"; fi)`
- **codegen** — none
- **run** — `bin/solidvibes init --profile setup/profiles/blank tests/.tmp/demo` then run the demo's contract `checks`; in Claude: `/plugin marketplace add ./` and `/plugin install sv@solid-vibes` in a scratch folder under the scratchpad
- **plans** — `docs/plans/YYYY-MM-DD-<slug>.md`
- **docs** — behavior: `docs/how-it-works/`, `README.md` · decisions: `docs/decisions/` · changelog: `CHANGELOG.md` under `## Unreleased`, one plain sentence
- **rules** — always-on: `AGENTS.md`
- **risk** — `lib/cli-run.sh` sandbox grants, `profiles/solidvibes.json`, anything that deletes (`worktrees --clean`, `init` refresh), `scripts/strip-check.sh`, `.gitleaks.toml` allowlist
- **ships** — Claude Code plugin, bash CLI (macOS, Linux)
- **sandbox** — none
- **stack** — none
- **harness** — none
