# Security

## Reporting a problem

Please don't open a public issue. Report it privately on GitHub instead: the repo's **Security** tab, then **Report a vulnerability**.

Say what you found, how to reproduce it and what it lets someone do. You'll get an answer within a week.

## What counts

- The `solidvibes` command: anything that deletes, the `run` sandbox and its grants, the commit check (`strip-check`).
- The Claude Code hooks: they must never block or write outside `.solidvibes/`.
- A skill that leads the AI to leak secrets, skip a check it promises, or act outside the project.

## Supported versions

Only the latest version on `main`.
