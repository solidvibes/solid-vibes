# Security lens

A lens of the `review` skill. A deep look for vulnerabilities, not style. Read-only: report findings, change nothing; fixing comes after, through `brief` or `plan`.

The user reads plain words: what could go wrong for the people using the project, how bad, and what to fix first. File and line references stay as evidence.

## Step 1 — Scope and checklists

- Read the project's Factory contract: the `## Factory` section of `AGENTS.md` in the repo root (spec: `.solidvibes/factory-contract.md`). `ships` decides the platform checks in Step 7; `risk` is where to look hardest. Missing → say so in plain words and offer the `interview` skill.
- The whole project, unless the user named a scope or you were given a diff.
- **Profile checklists.** The contract's `stack` field names the profile (`stack-<name>`). When it is not `none`, find that profile's folder (the installed skill of that name) and read every file in its `security/` folder. Each is a checklist for one topic; work through it in the step it belongs to and add its items to the table. No `stack`, no profile folder or no `security/` folder → run the steps below alone and say that no stack checklists were available.

## Step 2 — Secrets and credentials

Hardcoded secrets, keys, tokens and passwords:
- Environment and config files (`.env` and the platform files in Step 7): are they ignored by git? Are they bundled into the build output (app assets, web bundle, desktop package such as an Electron `asar`, container image)?
- Source: patterns like `apiKey`, `secret`, `password`, `token`, `Bearer`, encoded JWTs.
- History: files that should be ignored but were committed.

Never print a secret you find. Name the file, line and kind only.

## Step 3 — Authentication and authorization

- Server endpoints (API routes, serverless functions): is auth enforced on every one, and the same way?
- Webhook endpoints: is signature verification mandatory or optional?
- Data access: do row-level policies or app-level checks stop one user reaching another's data? On every table?
- Privileged credentials (service keys, admin database users): ever reachable from the client? Only used where necessary, server-side?
- Cross-origin rules: restricted origins or a wildcard?

## Step 4 — Input validation and injection

- SQL injection: raw SQL, string interpolation in queries, unparameterized inputs.
- Command injection: shell calls or process spawning with user input.
- Cross-site scripting: web views, renderers, HTML built from user data.
- Deep links and custom URL schemes: validation of parameters, malformed input.
- Webhook payloads and inter-process messages: validated before use?

## Step 5 — Data exposure

- Logging: personal data, tokens or user content in logs, even in debug builds.
- Error responses: stack traces, database errors or file paths leaking out.
- API responses: more data returned than the client needs.
- Build artifacts: debug symbols, source maps or unobfuscated builds shipping.

## Step 6 — Network and transport

- HTTPS everywhere: any plain HTTP calls, or cleartext traffic allowed?
- Certificate pinning on critical endpoints, where it fits.
- Timeouts on every external call.
- Rate limiting on endpoints that can be abused.

## Step 7 — Platform security (only the targets in `ships`)

- **Android**: `minifyEnabled`, `debuggable`, `allowBackup`, cleartext traffic, exported components, service config files (e.g. `google-services.json`).
- **iOS**: ATS exceptions, keychain use, entitlements, `Info.plist`, service config files (e.g. `GoogleService-Info.plist`).
- **macOS**: entitlements, hardened runtime, keychain use, notarization.
- **Desktop shells (Electron and similar)**: `contextIsolation`, `nodeIntegration`, `sandbox`, the preload or IPC surface, `shell.openExternal` with untrusted URLs, update signature checks.
- **Web**: CSP, cookie flags, secrets in the client bundle.
- **Server and containers**: non-root user, minimal image, secrets from the environment or a secret store, never baked in.
- Permissions requested: each justified? Any over-requested?

## Step 8 — Dependencies

- Known vulnerable or badly outdated packages.
- What third-party SDKs collect and which permissions they take.
- A committed lockfile.

## Output

Findings in the review table, with security severities:

```
┌──────────┬──────────────────────────────────────────────────────┬──────────────────────────────┐
│ Severity │ Finding                                              │ File                         │
├──────────┼──────────────────────────────────────────────────────┼──────────────────────────────┤
│ CRITICAL │ .env bundled into the build; secrets ship to users   │ build config:127             │
│ HIGH     │ Webhook signature verification is optional           │ webhook handler              │
│ MEDIUM   │ Request payload logged in debug builds               │ ai_client:44                 │
│ LOW      │ No timeout on external API calls                     │ http_client:37               │
│ OK       │ Row-level access enforced on all tables              │ —                            │
└──────────┴──────────────────────────────────────────────────────┴──────────────────────────────┘
```

- **CRITICAL** — actively exploitable or leaking secrets now. Fix immediately.
- **HIGH** — significant, exploitable with moderate effort. Fix before the next release.
- **MEDIUM** — a defense-in-depth gap or data exposure risk. Fix soon.
- **LOW** — hardening, best practice. Fix when convenient.
- **OK** — a control that was checked and verified (include 5 to 8).

Sort CRITICAL, HIGH, MEDIUM, LOW, OK. Mark each row that came from a profile checklist with the checklist's name.

After the table, a **Remediation priority** list: the top 5 fixes in order of urgency, one line each, in plain words. Show the table and the priorities as a visual per `.solidvibes/agents.md`, else a local HTML file.
