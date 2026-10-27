# Architecture lens

A lens of the `review` skill: does the code keep to the shape the project chose? Read-only. Findings go in the review table, with `file:line`.

The shape is the contract's `layers`, `docs/stack.md`, `docs/decisions/` and the `rules` files. Judge against those, not against taste.

- **Layer boundaries.** A call that skips a layer or goes the wrong way (a screen that talks to the network directly, data code that knows about screens).
- **One place for each thing.** The same rule, query or mapping written in two places that can drift apart.
- **Where data lives.** Reads and writes go through the place `docs/stack.md` names; no second source of truth.
- **Dependencies.** A part that imports from everywhere; a cycle between parts; a new package for something the stack already does.
- **Decisions.** Code that goes against a decision in `docs/decisions/`. Name the decision and its date.
- **Stack packs.** Code that breaks a rule of a pack listed in `docs/stack.md` `## Packs` that `## Overrides` does not turn off or replace. Name the rule ID.
- **Size.** A file or a function that does several unrelated jobs and is hard to change safely.
- **Over-engineering.** An abstraction with one user, configuration nobody sets, a layer that only forwards calls.
- **Undocumented shape.** A pattern the code follows everywhere that no rule or doc names; suggest writing it down.

Severity: BLOCKER for a broken boundary or a decision gone against; SUGGEST for the rest. A finding that needs a decision to fix says so: that is a `plan`, not a quick fix.
