---
name: bye
description: End a working session. Write down where things stand so the next session picks up cleanly, and keep what was learned. Use when someone says "bye", "good night", "done for today", "that's it for today", "wrap up", "let's stop here", or "see you tomorrow".
---

# Bye

The end of a session. Two things: a handover the next session reads first, and the lessons of this session written where they will be found again.

How you talk to the user: plain words, short. Say what you saved, one line each. Ask only when a lesson's wording or place is genuinely unclear.

## 1. Write the handover

Write `.solidvibes/handover.md`, about 15 lines:

```
# Handover

## Done
- What was finished this session, one line each, with the PR or plan when there is one.

## Open
- What is started but not finished, and where it stands. Questions waiting for an answer.

## Next
- The next steps, in order. The first one is what the next session starts with.
```

Replace the old Done, Open and Next. Keep the `## Snapshot` section exactly as it is: a hook writes it before the conversation is compacted. The file is local to this machine and never committed (`.solidvibes/.gitignore` lists it).

## 2. Keep what was learned

Look back over the session for corrections the user made ("no, always …", "don't …") and decisions taken that are not written down yet. For each, write it where the contract's `docs` line says it belongs:
- a decision → a new file in the decisions folder, with its date and why;
- a rule for one part of the code → that topic's rule in `.agents/skills/<topic>/SKILL.md` (the contract's `rules`); a new topic gets a new folder with a "Use when" description;
- a rule for everything → `AGENTS.md`, in its own sections.

Never write inside `solidvibes:begin`/`solidvibes:end` blocks or into files marked `solidvibes:generated`: setup replaces them. Skip what is already written, and one-off fixes that teach nothing.

## 3. Say what was saved

One line for the handover ("Saved where we stopped: next is …"), one line per lesson and where it went. Nothing to save: say so. Then a short goodbye.
