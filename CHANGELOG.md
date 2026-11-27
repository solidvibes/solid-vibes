# Changelog

Written from the reader's perspective: what the thing does now, not what was refactored.
One plain sentence per entry.

## Unreleased

- The handover's git snapshot holds only the branch, up to 15 changed files and the last 5 commits, so each session starts smaller.
- Finished work is kept in `docs/log/`, one file per month, committed with each piece of work so every device sees it.
- The handover keeps its five newest Done lines, so each session starts smaller; older ones move to one file per month in `.solidvibes/done/`.
- `hello` and `bye` keep Open and Next to what is in progress, and the session start warns when the handover is too big or its Done trim is off.
- The plugin has an icon, and its README says what runs on your computer and that nothing is sent off it.
- The Progress pane opens on one card that says whether it needs you and where that plan is, lists other plans one line each, and opens a plan's stages when you press it.
- In a Solid Vibes project, a Progress pane beside the chat shows where the work stands, whether it needs you, how many steps are left before it does, and what was saved to the project.
- Agents check what a sub-agent reports before quoting it, leave other worktrees alone, read a write back before retrying it, and read CI the right way: mergeable first, rerun only failed jobs, quote the proof.
- Skills now ask before turning a correction into a rule, keep things lean and simple (essential complexity in one place, parts reused by the third time), check work where the owner will look, and say what an approval covers.
- When a project lists the sv-pro `linear` pack, hello shows its open Linear issues, bye updates the ones the session touched, a plan can link to a Linear project, and release closes what shipped.
- Installing sv-pro fetches it over HTTPS, so it works without an SSH key set up for GitHub.
- Answers to the owner are short and built for deciding: what needs their call and what happens next, in tables and lists, with explanations on request.
- Every change, even a one-line fix, keeps the docs true in the same change.
- The AI never amends a pushed commit or skips a commit hook.
- Saying "cleanup" or "my disk is full" lists what takes space on your computer with its size and what it costs, and deletes only what you pick.
- The page skill is now called `visual` (`/sv:visual`); with Codex, run `solidvibes install` again and remove the old link it names.
- A new `eli-solid` skill makes every page Solid Vibes shows the same way, picture first with real names and open questions flagged, in the app's own colours and fonts.
- Five new craft skills (brand, design system, accessibility, security, writing) teach the basics of each on any stack, and a new app's look now includes a logo, an app icon and a brand board.
- An approved plan starts building right away while the conversation is short; otherwise it names the exact `go` command to paste after /clear.
- Saying go in a fresh session finds the approved plan, even one kept in a private folder git ignores.
- Every pull request runs the tests on GitHub before it can be merged.
- Saying "I want to build …" starts a conversation about the problem, who it is for and what it must never do, then sets the project up so every later request goes to the right step.
- Twelve skills take work from a vague idea to a reviewed, checked pull request: you call interview, hello, bye, release and update by name, and the routing picks brainstorm, brief, plan, design, go, review and verify from what you say.
- A new app gets its look before it is built: three directions to choose from, then the design system, the screens and one picture of how it all works.
- `hello` starts a session where the last one stopped and says what's next; `bye` writes down where things stand and what was learned.
- `update` brings a whole project to the latest of everything now and then, asks only about the upgrades that need your call, and ends in a pull request.
- `review` can look at the whole project through one lens: security, docs, speed or architecture.
- Decisions come as plain choices with a picture, and pages lead with a picture and explain every term.
- The `solidvibes` command sets a project up, checks its setup, cleans up finished worktrees, blocks commits that carry secrets or personal paths, and hands a plan to Claude, Codex or another agent in a sandboxed copy that can't change your GitHub or git settings.
- Stack know-how comes from the sv-pro plugin, turned on per project.
- `go` builds a multi-phase plan much faster: one AI codes as many phases as fit, then one review and one full test run cover them all.
- In Claude Code, setup offers a status bar with the folder, branch, model, how full the AI's memory is, cost and time.
- The README now says plainly what Solid Vibes is, the four steps of the method, what you do and how to set it up.
