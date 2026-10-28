# Solid Vibes

Solid Vibes is a free plugin for Claude Code that makes the AI build the way a careful team would. It is for anyone who builds with AI, whether you have never written code or do it every day.

It also works in Codex and other AI coding agents. Website: [solidvibes.stojanovventures.com](https://solidvibes.stojanovventures.com).

## The method

1. **Make your intentions clear.** What you're building, for whom, and what it must never do. Everything else follows from it.
2. **A picture says 1,000 words.** Say what you want next. Judge the result from screens and diagrams, not code or walls of text.
3. **Let AI check its work.** Simulators, test data and checks, so every piece is verified without you.
4. **Keep everything up to date.** Every decision is checked against your intention and the ones before. Old gives way to new.

## What you do

You talk in plain words. There are no commands to learn.

You come in at three points:

- **Describe** what you want and who it is for.
- **Steer** from pictures: screens, diagrams and side-by-side choices.
- **Check** the result before anything goes live.

The AI does the rest: it asks about the problem first, writes a plan you can read, has a fresh AI review the work, and proves the result runs. Nothing is merged, deployed or published without your go.

## Set it up

You need a computer and Claude Code. Install Claude Code from [code.claude.com](https://code.claude.com/docs/en/overview) and sign in. Type each step below into Claude Code's chat box. If a step feels unfamiliar, tell the AI "do this for me".

1. **Add Solid Vibes.** Type these two lines, one at a time:

   ```
   /plugin marketplace add solidvibes/solid-vibes
   /plugin install sv@solid-vibes
   ```

   When it asks where to install, pick "Install for you", so it is there in every project.

2. **Turn on updates.** Type `/plugin`, open the **Marketplaces** tab, pick `solid-vibes` and choose **Enable auto-update**. New versions then arrive on their own.

3. **Start.** Open an empty folder in Claude Code and say what you want, for example:

   > I'm a dentist and want my patients to book online.

   The AI starts with a conversation about the problem. Then it sets the project up and tells you what it does, including saving your work with git.

Using Codex or another agent? See [Other agents](#other-agents) below.

## What's inside

Twelve skills. Each is a short instruction file the AI follows. You start five by name; the AI picks the other seven from what you say.

| Skill | Started by | What it does |
|---|---|---|
| interview | you | A conversation about the problem, then sets the project up. |
| hello | you, at the start of a session | Picks up where you stopped and says what's next. |
| bye | you, at the end of a session | Writes down where things stand and what was learned. |
| release | you | Merges, deploys and publishes, one step at a time, each on your go. |
| update | you, now and then | Brings tools and packages to their latest and proves the app still works. |
| design | the AI, on a new app | The look: three directions to pick from, then colours, screens and one picture of how it works. |
| brainstorm | the AI | Explores an unclear idea and the choices that are hard to undo. |
| brief | the AI | One small, clear change, from idea to checked result. |
| plan | the AI | A written plan in phases you approve. |
| go | the AI | Builds an approved plan and stops at checked pull requests. |
| review | the AI | A fresh AI reads the change, or the whole project through one lens: security, docs, speed or architecture. |
| verify | the AI | Proves the change does what was asked, cheapest check first. |

Your project keeps its memory in `docs/`: why it exists, how it works and what was decided, each decision with its date and reason. The AI reads it first and keeps it true.

## Pro

Solid Vibes Pro adds ready-made rules for building Flutter apps with Supabase. It is a separate, paid plugin. Everything in this repo works without it.

## Contact

[hello@stojanovventures.com](mailto:hello@stojanovventures.com)

---

## For developers

### Other agents

Claude Code finds the `solidvibes` command by itself. For Codex and other agents, ask your AI: "put the `solidvibes` command on my PATH, then run `solidvibes install`". By hand, that is one line in your shell profile, with `<folder>` where you keep Solid Vibes:

```
export PATH="$PATH:<folder>/bin"
```

Then run `solidvibes install`. It links every skill into `~/.agents/skills/`, replaces only its own links and deletes nothing. Run it again after every update, so new skills get linked; it also names links to skills that no longer exist, for you to remove.

### How a project is set up

Setup writes an `AGENTS.md` into your project. It tells the AI how to handle every request: understand it, size it, pick the skill, say what happens next and wait for your go.

One section of it, the Factory contract, says how the project is built and checked: its test commands, how to run it, and where a human must look (`risk`). The skills read it and never guess your stack. `solidvibes doctor` checks it.

Opinions about tools live in one stack profile, copied into the project as `docs/stack.md`. A `blank` profile ships here; the AI fills in the choices with you. The format: [docs/how-it-works/profile-format.md](docs/how-it-works/profile-format.md).

### The `solidvibes` command

- `solidvibes init [--profile <dir>] [--agents claude,codex,generic] <dir>` sets a project up, or brings it up to date. Never deletes.
- `solidvibes doctor [dir]` checks a project's setup and changes nothing.
- `solidvibes lint <dir>` checks skills and plugin files.
- `solidvibes worktrees [--clean] [path]` lists working copies and removes the finished ones.
- `solidvibes run <plan|"task"> [--agent claude|codex|"<cmd>"] [--dry-run]` hands work to an agent in its own sandboxed copy. [How it works](docs/how-it-works/headless-run.md).
- `solidvibes stop <slug>` stops a run.
- `solidvibes install [nono]` links the skills for Codex and other agents, or the sandbox profile. Deletes nothing.
- `solidvibes hello [--full] [--checked] [dir]` prints a project's status at the start of a session: handover, setup, CI, docs.
- `solidvibes update [dir]` prints where a repo stands for the `update` skill. [How it works](docs/how-it-works/update.md).
- `solidvibes handover --snapshot [dir]` saves the git snapshot into `.solidvibes/handover.md`. The Claude Code hook runs it before compaction.
- `solidvibes statusline --check|--install` reports or installs a status bar for Claude Code. Never replaces yours. [How it works](docs/how-it-works/status-bar.md).

More: [docs/how-it-works/](docs/how-it-works/) and [docs/decisions/](docs/decisions/).

### Security

Found a problem? Please report it privately, not in a public issue. See [SECURITY.md](SECURITY.md).

### License

MIT, by Stojanov Ventures. See [LICENSE](LICENSE).
