---
name: cleanup
description: Free up disk space on this computer: list what takes space with its size, why it is safe to delete and what it costs, then delete only what the owner picks. Use when someone says "cleanup", "clean up disk", "free up space", "my disk is full", "out of space", "the Mac is full", "delete old simulators" or "what is taking space". Not for tidying code.
---

# Cleanup

Frees space on this computer. It lists what takes space, says what each item costs, and deletes only what the owner picks. The `solidvibes disk` command finds the items and does every delete, with its own checks. This skill explains and asks. Works from any folder; no Factory contract needed.

How you talk to the user:
- Plain words, outcomes only. Say what you are about to do before you do it.
- Short. One line per item.
- How this agent asks and shows pages: `.solidvibes/agents.md`.

The `solidvibes` command: in Claude Code the plugin puts it on the path; elsewhere it is `bin/solidvibes` in the Solid Vibes folder, two levels above this file's folder.

## Never

- Never delete any other way: never type `rm`, never run the native tools (`simctl`, `dart pub cache clean`, `avdmanager`, `brew`) yourself, never `sudo`, never `chmod`.
- Never delete an id the owner did not pick. `all` is defined in step 3; nothing else counts as a yes.
- Never guess an unclear answer. Ask again.
- Never offer a different way when the command refuses or fails. Report it and say where to fix it by hand.
- Never ask the owner to loosen `rm` permissions.

## 1. Look

Say "I'll look at what takes space first. Nothing is deleted yet."

Find the projects folder: `$SOLIDVIBES_PROJECTS_DIR`; else the folder that holds the current repo, when it holds other git repos; else ask in plain words where they keep their projects, and say that project build folders and finished working copies are skipped without it.

Run `solidvibes disk --tsv --projects <dir>` (no `--projects` when skipped). Read the rows: `id`, `item`, `kb`, `class`, `note`. `-` is an empty note. Lines starting with `#` are the CLI's own: `# free` is the free space, `# note` is something to tell the owner in plain words.

## 2. Show the list

Number the `safe` and `your-call` rows, except `sim:` and `runtime:` rows (step 3 groups them), biggest first, one line each: name, size, why it is safe, what it costs. Use the table below for the words; use the row's `kb` for the size, in GB or MB. `your-call` rows say so and say what is lost.

| id | Say |
|---|---|
| `worktrees` | Finished side copies of your projects. The work in them is already saved elsewhere; nothing is lost. |
| `build:<repo>` | Build folders in `<repo>`. The tools make them again; the next build is slower. |
| `deriveddata` | Xcode's build leftovers. Xcode makes them again; the next build is slower. |
| `gradle` | Android build downloads. They download again on the next Android build. |
| `pub` | Flutter's package downloads. They download again on the next build. Tools you installed with `dart pub global activate` need installing again. (Your call.) |
| `npm` | npm's download cache. It fills again as you install packages. |
| `cocoapods` | CocoaPods' download cache. It downloads again on the next iOS build. |
| `swiftpm` | Swift package downloads. They download again on the next build. |
| `homebrew` | Old downloads and old versions of tools installed with Homebrew. Current versions stay. |
| `sim-unavailable` | Simulators Xcode can no longer start. Nothing uses them. |
| `avd:<name>` | The Android emulator `<name>`, with its apps and data. Making it again is by hand. (Your call.) |
| `devicesupport:<build>` | Xcode's files for phones on iOS `<version>` (the version in the item, not the id). Xcode copies them again when such a phone connects; that takes a while. (Your call.) |

Rows with class `keep` are not numbered. Put them in a short "Left alone" list with the reason: `archives` ("needed to read crash reports of apps you shipped"), `ollama` ("downloaded AI models"), the newest DeviceSupport, a running simulator or emulator, a runtime Xcode won't let go. The note says why. One more line: "Docker isn't checked; look at `docker system df` or Docker Desktop yourself."

End the list with the free space from `# free` ("<size> free on this computer") and say what `all` and the numbers would free.

## 3. Simulators

Do not number each simulator. Group them into two numbered lines:

- **Old simulators (N)**: every `sim:` row with class `your-call`, except the ones to keep. Say the size of the group and that apps and data inside them are lost.
- **Runtimes no one needs (N)**: every `runtime:` row with class `your-call` that no simulator uses, or whose users are all in the group. The note says `used by N simulator(s)`; a `sim:` row uses the runtime named after the comma in its item (`<name>, iOS-18-0` uses `iOS-18-0 runtime`). It is a big download to get back. A runtime a kept simulator uses stays out; say so.

Keep the newest iPhone and the newest iPad. The note of a `sim:` row says `<type>, newest runtime for type` when its runtime is the newest that supports that device. Pick the newest model among those rows, one for iPhone and one for iPad. Never assume the newest runtime has every device. Name the two in the line: "Keeping the <name> and the <name>." No such iPhone or iPad: say none of that kind is kept.

The owner can add more: "keep the <name> too" moves that simulator out of the group. Redo the line and the sizes. Nothing to group (no `sim:` rows): leave the group out.

## 4. Ask

Ask once: `all`, `none`, or the numbers ("1, 3, 5"). Say what each means:
- `all`: every `safe` line plus the simulator group as proposed (the old simulators and the runtimes no one needs).
- Other `your-call` lines (`pub`, `avd`, `devicesupport`) go only when named by number.
- `none`: stop here, nothing is deleted.

Anything else ("all but 3", a number that isn't on the list): ask again. Offer once to show the list as a page (the `visual` skill); the chat list is the default.

## 5. Delete

Say the full list of what will go and its size. Then map the numbers to ids and run once:

`solidvibes disk --clean <id>… --projects <dir>`

Leave out `--projects` when step 1 did. A group expands to every `sim:` or `runtime:` id in it. Claude Code may ask the owner to approve this one command; that is the only question. The command re-checks everything and refuses what changed since the list.

Blocked by the sandbox: say so, ask the owner to allow that one command, or to run it in their own Terminal. Nothing else.

## 6. Report

Read the output. One short message:
- freed, and free before and after (the last line of the command);
- one line per failure, with where to fix it by hand. A simulator that won't delete: Xcode, Window, Devices and Simulators, select it and delete there. Gradle running: close Android Studio and try again. A runtime kept because a simulator still uses it: say which, and offer to run cleanup again with that simulator in the group;
- a refusal (it names the id and why): nothing was deleted; say what changed and offer a fresh list.

Deleted runtimes can take a few minutes to show as free space. Say so when any went.
