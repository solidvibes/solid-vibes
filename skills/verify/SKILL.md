---
name: verify
description: Prove a change does what was asked, beyond "it compiles and the review is clean", cheapest check first. Use when someone says "does it actually work", "prove it", "test it", "check that it works", "is it done", or after a review and before a pull request is handed over.
---

# Verify

Prove the change does what the plan says. Runs after review, before the PR is handed over.

What the user reads is plain: what was checked, what passed, what could not be checked here and what they can do to see it themselves. Commands, exit codes and paths stay in the PR body or the evidence column.

## Input

- The project's Factory contract: the `## Factory` section of `AGENTS.md` in the repo root (spec: `.solidvibes/factory-contract.md`): its `checks`, `run`, `harness` and `stack`. Missing → say so in plain words and offer the `interview` skill. A missing field gets the same treatment, for that field only; a field set to `none` is answered, not missing.
- What "done" looks like: the plan's `## Verification`, else the issue's acceptance criteria, else the brief's approach. If none of them says, derive it from the goal and state it in the report.
- The diff since the work started.

## The seam: how each level runs

The contract is the only switch. Never check whether any plugin is installed.

1. **Harness declared.** If `harness` is not `none` and its command exists, run `<harness command> status --json`. It lists each level and target as available or not. Levels it reports available go through the harness; the rest fall back to step 2.
2. **Fallback.** A level the harness doesn't cover (or a project with `harness: none`) uses the contract's `checks` and `run`.
3. **Neither.** A level with no harness and no `checks` or `run` command gets exact steps for the human, written out and listed in the report as an owner follow-up.

A missing capability costs only its own level: no Docker loses the database level, not the devices.

Harness commands: `version`, `status [--json]`, `up`, `down`, `reset --yes`, `devices`, `guard`, `unit`, `db`, `story <name> --target <t>`, `screenshots`, `all`. Exit codes: **0** pass, **1** fail, **2** refused by the guard, **3** not available here (no simulator, no Docker, no credentials). Exit 3 is an owner follow-up, never a pass. Exit 2 is a refusal to respect, never to work around.

Every harness run writes `.harness/out/<run-id>/report.json`, a list of `{level, check, result, evidence}`. Evidence is a screenshot path, a test count or one output line, never a secret. Turn it into the report table; don't re-derive it.

## Levels, cheapest first

Stop at the first level that fails, fix the cause, then re-run from that level.

Slow suites (`checks.full`, simulator, emulator or desktop-app tests) run once per verify; re-run one only to re-check a failure. Turn off slow post-test extras the test tool offers unless a failure needs them (for example `xcodebuild test -collect-test-diagnostics never`).

1. **Static and unit** — the contract's `checks.fast`, then `checks.full` (harness: `unit`).
2. **Wider suite** — the integration or e2e tests the contract's `run` names that cover the touched flow (harness: `story`, `db`).
3. **Run the real thing** — launch the app per the contract's `run` (or a `run` skill if one is installed) and drive the changed flow. Capture a screenshot or the output as evidence (harness: `story` on a target, with a screenshot).
4. **Staging** — only when `run` or the plan names a staging check for this flow, and only when credentials are available in this session.

Never touch production. Anything that cannot run here (no credentials, a sandboxed headless run, a manual GUI step, harness exit 3) is not skipped silently: it goes in the report as an owner follow-up, with the exact command or steps, in plain words for the user.

Headless runs (for example from `solidvibes run`) have no cloud credentials and no GUI: what needs them is an owner follow-up, not a failure. Fix failures you can and commit once as `fix: verification` with the contract's commit discipline (`codegen` if a matching file changed, then `checks.fast`, hooks never skipped).

## Report

One table: check → pass / fail / owner follow-up → evidence (a short output line, a screenshot path, or a test count). Then one line: verified, or what is still unproven.

Write it where the handoff goes: the PR body when there is one, else inline. When a visual helps (a screenshot per changed screen, or the table as a page), show one as `.solidvibes/agents.md` says for the agent in use, else a local HTML file.
