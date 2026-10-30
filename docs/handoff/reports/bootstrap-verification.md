# Bootstrap verification

Date: October 30, 2026.
Host: Linux. Native Apple tools are unavailable.

## Executed checks

| Check | Result |
| --- | --- |
| `make check` | Passed: required files, local links, shell syntax, privacy plist, JSON, and acceptance coverage |
| Parse `project.yml` | Passed with PyYAML; app/test sources and local package paths exist |
| Parse continuous integration workflow | Passed with PyYAML; macOS job and command definitions present |
| Parse Python sources | Passed with Python abstract syntax parsing |
| Parse privacy manifest | Passed with Python plist parser; tracking is false and UserDefaults reason is declared |
| Resolve Markdown file links across docs and experiments | Passed; no unresolved local targets |
| Unit test inventory | Eight core tests written; execution pending |
| UI test inventory | Two shell tests written; execution pending |

## Not run

Swift compilation, core test execution, XcodeGen generation, simulator build, UI tests, and physical-phone tests were not run.
This host has no Swift, Xcode, or XcodeGen executable.
No continuous integration run or signing result is claimed.

## Repository state

A local Git repository is initialized on `main`.
No commit, remote, push, team message, or public release was created.
Generated outputs, signing configuration, caches, and handoff archives are ignored.

## Archive verification

The handoff archive is produced by `make handoff` and includes a SHA-256 manifest of source files.
Its preparation check extracts the archive, checks all hashes, excludes signing/generated outputs, and runs `make check` from the extracted root.
The preparation result is reported with the final handoff. Re-run packaging after any source change.
