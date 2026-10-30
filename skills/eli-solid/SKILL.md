---
name: eli-solid
description: Make a page that explains or decides something: big pictures, few words, in the app's own look. Use when a skill says "show a visual", or someone asks for a page or a picture, like "explain this as a page", "draw how it works", "show the options side by side", "make a decision page", "mock up this screen", "summarise the plan as a page". A plain "how does X work?" gets an answer in words, not a page.
---

# Eli Solid

Makes the pages Solid Vibes shows: one method for every explanation, decision, plan summary and mockup, in the app's own look.

Used by every skill's Visuals step. A plain "how does X work?" is answered in words, not with a page.

How you talk to the user:
- Plain words. Every term gets one line saying what it is.
- Reply with the link or path and one line. Nothing else.

## The contract

Read `## Factory` in `AGENTS.md` for where plans and docs live.

## Read first

Start from the thread, the plan, the pull request or the code. Then read `docs/intent.md`, `docs/how-it-works/`, `docs/decisions/`, the plans folder and `docs/design/`. Use the project's own words. When sources disagree, show the disagreement; don't pick.

## The basics

1. **Big pictures, few words.** Each section is one SVG or one table, plus at most two short sentences. A point that needs a paragraph needs a picture.
2. **Real names in mono.** Label boxes and arrows with the real services, files, fields and statuses, each with one plain caption line on what it is. An analogy can be a heading hook, never a replacement for the name.
3. **One idea per section.** Sections stack, each about one screen tall.
4. **Show mechanisms and choices.** Draw the data path or the state change, or the options side by side with labelled arrows. The rejected option is greyed.
5. **Flag gaps.** Say what the sources leave open and where to raise it. Never invent an answer.
6. **Plain register.** Short words, active voice. No em dashes, no bullet walls.
7. **Go deeper.** End with a footer linking every source used.

## Section order

Skip what does not apply.

- **Explain:** what it is, why, how it works, where things live, who does what, where it can go wrong, what is still open.
- **Decide:** the ask and the recommendation in the hero. Then the options side by side: the recommended one in `--hot`, the others plain until decided. Then what each costs later, how it works, and what is open.

Hero: eyebrow (project and date), a short h1, a one-sentence goal, status chips and a jump nav. Open questions go in `.cards`, each with a "Raise in …" line naming where.

## The look

Paste `templates/style.html` at the top of the page, then set its tokens and fonts from the project as `references/look.md` says. Build from its classes; don't restyle them. These pages may load fonts from Google Fonts. Name the look's source in the layout comment.

## Updating a page

Republish to the same URL, or overwrite the same file, and make the change visible:

1. Give every section a stable `id`.
2. Put a "What changed since vN" box under the header: one line per added or changed section, each linking to it, and one muted line on what stayed the same. Replace the previous box.
3. Badge each added or changed section ("New in vN", "Updated in vN") with a highlighted border. Drop older badges.
4. Put new sections where they belong in the story, not at the bottom.

With Pro: the `ui` pack adds a design craft review of what the page draws.

## Visuals

Show it as `.solidvibes/agents.md` says for the agent in use. If that file is missing, write a local HTML file and say where it is. Where the agent shows no HTML, keep the method: the picture first, as Mermaid or a table. Load the host's page-design or diagramming skills first, if it has them. Reply with the link or path and one line.
