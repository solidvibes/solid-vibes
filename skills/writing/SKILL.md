---
name: writing
description: Write the words people read, and the docs, so they are clear, kind and true: the app's voice, plain words, buttons, errors and confirmations, onboarding, store and website text, READMEs. Use when someone says "write the text", "what should the button say", "fix the wording", "this error message is confusing", "write the App Store description", "write the landing page copy", "make it sound less like AI", "write the README", or when a change adds or changes words people read.
---

# Writing

The words people read: in the app, on the website, in the store, in emails and in the docs. On any platform and any stack. Good words are short, plain and true, and sound like one person.

Used by `brand` (the voice in a line), by `brief`, `plan` and `go` whenever a change adds or changes words people read.

How you talk to the user:
- Show words in place: on the screen, the button, the page, never as a list of strings (see Visuals).
- A choice of wording comes as two or three versions side by side, the recommended one first.
- Use their words for their things. If they call it a "visit", the app says "visit", not "appointment".

## The voice

One line in `docs/design/brand.md` (or `docs/intent.md` when there is no brand yet): how the product talks, in three words and one example ("Calm, warm, direct: 'Saved. You can change it any time.'"). Every new word follows it. No voice yet → propose one from the intent and its values.

## The basics

1. **Plain words.** Everyday words a 12-year-old knows. One idea per sentence. Short sentences. No jargon, no internal names ("sync failed: 409" → "Couldn't save. Check your connection and try again").
2. **True claims only.** Never invent social proof: no ratings, reviews, testimonials, user counts or "trusted by" that are not real and current. No "secure", "private" or "encrypted" without the exact limit that makes it true. No promises the product doesn't keep.
3. **Say what happens.** Buttons say the action with a verb and the thing ("Save entry", "Delete photo"), never "OK", "Submit" or "Yes". Links say where they go.
4. **Errors help.** What happened, in their words, and what to do next. Never blame ("You entered an invalid…"). Never only a code. Keep what they typed.
5. **Confirmations match the risk.** Something that can't be undone asks once, names the thing and the consequence ("Delete 'Grandma's recipes'? This removes 12 recipes for good"), and the button repeats the action. Everything else just happens, with an undo where it can.
6. **Empty and first-time screens** say what goes here and the one next step.
7. **No AI tics.** No "seamless", "effortless", "elevate", "unlock", "dive in", "leverage", "robust", "in today's world"; no "not just X, but Y"; no stacked adjectives, no em-dash chains, no exclamation marks to sound friendly, no emoji unless the voice has them.
8. **Consistent.** One word per thing everywhere: the app, the website, the store and the docs. Same capitals style everywhere (sentence case unless the voice says otherwise). Dates, times, numbers and money in the reader's own format.

## Docs

Docs a builder reads (README, `docs/`) follow the same basics: lead with what it is and what to do, one fact in one place, true today. Behavior goes in `docs/how-it-works/`, decisions in `docs/decisions/`, per `docs/CONVENTIONS.md`.

## While building

- New or changed words: check them against the voice and all eight basics before the commit.
- Words that make a claim about safety, privacy, money or results: check the claim against the code or the facts; when it can't be checked, cut it.
- Translations: write the source words first, plain and short, so they translate.

With Pro: the `ui` pack adds rules for dates, numbers and money on screen, permission asks, onboarding, and no pressure patterns.

## Visuals

"Show a visual" means: as `.solidvibes/agents.md` says for the agent in use. If that file is missing, write a local HTML file and tell the user where it is. Words are shown in place: the screen or page with the new words, next to the old ones when they changed.
