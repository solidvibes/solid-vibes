# The seam: skills and the harness

**Status:** Built on the skill side (`verify`, `plan`, `go`, `brief` read it; `solidvibes doctor` checks it). The harness itself is Planned (the Flutter and Supabase extension, sv-pro).

> Skills never ask whether a harness is installed. They read the Factory contract, and the contract says.

## The picture

```
 sv skills ──read──▶ Factory contract ──names──▶ harness ──drives──▶ devices · browser · macOS · database tests
 (verify, plan,       (AGENTS.md:                (sv-harness)                         │
  brief, go)           checks, run, harness)            ◀──── report.json ────────────┘
       │
       └─ no harness? → contract checks/run → none? → steps for you, by hand
```

## How a skill decides

1. **Declared, never sniffed.** The contract's `harness` field names the command and what it covers, e.g. `` `sv-harness` · levels: unit, db, story · targets: ios, web ``, or `none`. `stack` names `docs/stack.md` and the profile it came from.
2. **Per level.** When `harness` is not `none` and its command exists, the skill runs `<cmd> status --json`, which lists each level and target as available or not. Available levels go through the harness; the rest use the contract's `checks` and `run`. A level with neither becomes exact steps for the owner, listed as follow-ups.
3. **No plugin checks.** The contract is the only switch, so the same skills work in any agent and in CI.

`solidvibes doctor` reports which case a project is in: `harness: none`, the command not installed (`solidvibes install` links it), or `status --json` answering.

## The harness interface

Stable and versioned:

| Part | Shape |
|---|---|
| Commands | `version`, `status [--json]`, `up`, `down`, `reset --yes`, `devices [--erase\|--shutdown]`, `guard`, `unit`, `db [--local\|--linked]`, `story <name> --target <t>`, `screenshots`, `all` |
| Exit codes | 0 pass, 1 fail, 2 refused by the guard, 3 not available here (no simulator, no Docker, no credentials). `verify` reads 3 as an owner follow-up, never a pass |
| Evidence | `.harness/out/<run-id>/report.json`: a list of `{level, check, result, evidence}`; evidence is a screenshot path, a test count or one output line, never a secret |
| Guard | Runs first: refuses CI, production hosts, non-loopback stacks, migration drift and a wrong linked project, before any device or database level |

## Levels and the verify ladder

| `verify` level | Through the harness | Without it |
|---|---|---|
| 1. Static and unit | `unit` | `checks.fast`, `checks.full` |
| 2. Wider suite | `story`, `db` | the tests `run` names |
| 3. Run the real thing | `story` on a target, with a screenshot | launch per `run` |
| 4. Staging | only when `run` names it and credentials exist | same |
