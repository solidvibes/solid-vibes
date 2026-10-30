---
name: security-basics
description: Build it so the people using it are safe, on any stack: what could go wrong for whom, where secrets live, what personal data leaves the device, sign-in and payments done the safe way. Use when someone says "keep my users' data safe", "where do I put the API key", "add sign-in", "add login", "take payments", "add a subscription", "store their emails", "send this to a server", "is this safe to build", or when a change touches sign-in, payments, personal data, secrets or what leaves the device. To check a finished project ("is it secure?"), `review` runs its security lens.
---

# Security

The basics of building something safe, on any stack. This skill is for **while you build**: the questions to answer and the rules to follow before and during a change. Checking afterwards is the `review` skill's security lens, which starts from the basics below and goes deeper; the basics are written here once.

Used by `plan`, `brief` and `go` whenever a change touches sign-in, payments, personal data, secrets or what leaves the device.

How you talk to the user:
- Talk about people, not attacks: "If someone got this list, they would have every customer's phone number."
- Decide the safe way yourself from `docs/stack.md`; explain it in one plain sentence when it changes what they see ("You'll sign in with a code sent by email, so there's no password to steal").
- A change that touches a contract `risk` area is shown to them first, with a visual and that one sentence.

## Step 1 — Who could be hurt, and how

Before the change, write three to five lines in the plan's `## Constraints` or the brief's **Risk**: what this stores or sends, who it belongs to, and what would happen to them if it leaked, was changed by someone else, or was lost. Use the people from `docs/intent.md` and its never list. Each line gets the basic below that prevents it.

## The basics

1. **Secrets live outside the code.** Keys, tokens and passwords come from the environment or the platform's secret store, never a committed file, never the app or web bundle. A key the app must carry is a public one, limited to what a stranger may do with it. Secret files are listed in `.gitignore` before they exist.
2. **Know what leaves the device.** List every place personal data goes (your server, each outside service, logs, crash reports, analytics) and why. Send the least that does the job. Analytics and tracking only after people say yes, when the intent's values or the law ask for it.
3. **Nothing personal in logs.** No personal data, tokens or message content in logs, error messages or crash reports, in debug builds too. Errors shown to people never include internals.
4. **Sign-in is borrowed, not built.** Use the stack's sign-in provider (email codes, magic links, Apple or Google). Never store passwords yourself. Sessions sit in the platform's secure storage. Signing out ends the session on the server too.
5. **Every request checks who is asking.** The server decides what each person may read and change, on every table and endpoint, the same way. Never trust the app to hide what someone may not see.
6. **Payments go through the provider.** Card details never touch your code: use the provider's hosted checkout or the app store. Access is granted only by the server after the provider confirms payment (a verified webhook or receipt), and removed when it ends.
7. **Check what comes in.** Input from people, links, files and other services is checked where it enters: type, size, allowed values. Queries are parameterised; nothing from outside goes into a shell, a query or HTML unescaped.
8. **People can leave.** Someone can delete their account and data, and the never list in `docs/intent.md` holds for backups and outside services too.

## While building

- Follow every basic the change touches; record any you can't meet, and why, in the plan's `## Decisions` (mine, after showing the owner).
- Name the contract `risk` area the change touches in the brief or plan. It gets a human reviewer before release.
- Never print a secret, even to show where it is; name the file and line only.

With Pro: the `security` pack adds stack rules and checklists (secret scanning, secure storage, consent before analytics, wiping data on sign-out, signing keys, web security headers), and the `supabase` pack checks the database's access rules.

## Visuals

"Show a visual" means: make the page with the `eli-solid` skill and show it as `.solidvibes/agents.md` says for the agent in use. If that file is missing, write a local HTML file and tell the user where it is. Step 1 is drawn as a picture of the real things (phone, server, each outside service) with what personal data travels along each arrow, and the basic that protects it.
