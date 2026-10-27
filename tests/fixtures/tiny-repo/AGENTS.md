# Tiny repo

A fixture for `tests/init_blank.sh`: a project that already has instructions and a contract.

## Factory

- **layers** — `greet.sh` prints a greeting
- **checks** — fast: `sh -n greet.sh && sh greet.sh >/dev/null` · full: `sh -n greet.sh && sh greet.sh >/dev/null`
- **codegen** — none
- **run** — `sh greet.sh`
- **plans** — `docs/plans/YYYY-MM-DD-<slug>.md`
- **docs** — behavior: `README.md` · changelog: none
- **rules** — always-on: `AGENTS.md`
- **risk** — none
- **ships** — a shell script
- **sandbox** — none
- **stack** — none
- **harness** — none
