# Speed lens

A lens of the `review` skill: what makes this slow for the people using it, or will once there is real data. Read-only. Findings go in the review table; each says what the person would notice ("the list takes seconds to open with a year of orders").

Look where the user waits: opening a screen, a search, a save, a sync, the first launch.

- **Repeated work.** A query or a network call inside a loop; the same data loaded twice for one screen; work redone on every redraw.
- **Unbounded data.** A list, a query or a file read with no limit or paging; everything loaded to show the first twenty.
- **Missing indexes.** A filter or sort on a column with no index, in a table that grows.
- **The main thread.** Parsing, image work, encryption or file reads on the thread that draws the screen.
- **The network.** Calls in sequence that could run together; no caching of what rarely changes; large payloads where a few fields would do; no timeout.
- **Startup.** Work done at launch that could wait until it is needed.
- **Size.** Large images or assets shipped as they are; dependencies pulled in for one function.
- **Leaks.** Listeners, timers or streams that are never closed.

Severity: BLOCKER when a person would feel it today with normal data; SUGGEST when it bites only as data grows. Never guess at a number: say what to measure, and how, when it matters.
