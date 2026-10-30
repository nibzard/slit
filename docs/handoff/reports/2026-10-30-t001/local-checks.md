# Local preparation evidence

Date: 2026-10-30. Operator: coding agent. Run: T001-local-01.
Round 1, WP-00 local preparation (T001).
Source base: `10dcec51c20b44f38d7317e817b2f84f09e952cf` plus the T001 preparation changes.
Host: Linux 6.8.0-147-generic, x86_64. Python: 3.12.3.

## Check results

| Command or inspection | Result |
| --- | --- |
| `make check` | PASS: portable files, Python and shell syntax, privacy plist, JSON, links, and acceptance ID coverage |
| `make test-core` | NOT RUN: Swift is absent; make exits 2 after command error 127 |
| `make bootstrap` | NOT RUN: doctor rejects Linux; make exits 2 |
| `make build` | NOT RUN: doctor rejects Linux; make exits 2 |
| `make test-ios` | NOT RUN: doctor rejects Linux; make exits 2 |
| `make verify` | Portable checks pass; stops at missing Swift with exit 2 |
| `make -n verify` | Confirms ordered check, test-core, build, and test-ios commands |
| Source inventory | Eight core tests and two app UI tests remain unchanged |
| Setup and continuous integration | Both use `make verify`; the app scheme includes SlitUITests and links SlitCore |
| Generated output | Existing build, project, plist, cache, and archive ignores retained; coverage profile ignores added |
| Working files | Command-run snapshots confirm no tracked or unignored file changes from verification |

The scripts check the native toolchain during bootstrap, including builds and app tests.
No Swift, Xcode, XcodeGen, or simulator version can be recorded on this host.
No remote continuous integration run was requested or executed.
Static checks do not establish a native build baseline.

## Acceptance records

- [Capability](capability-report.md): NOT RUN; no device values inferred.
- [Performance](performance-report.md): NOT RUN; fixed limits retained and device gates pending.
- [Acceptance](acceptance-report.md): M01–M24 are NOT RUN; all remain required.

Keep the full evidence requirements in specification 0002, sections 10 and 11.
Development fault injection does not replace physical camera evidence.
Keep user photographs outside the repository.

## Existing work and resume conditions

| Task | Owner | Required outcome and resume condition |
| --- | --- | --- |
| T002 | Operator | Provide worker access to a Mac with permission to configure native tools |
| T003 | Agent | After T002, run setup, core tests, simulator build and app tests; launch the shell and record exact versions |
| T004 | Operator | Provide the primary iPhone 16 Plus and authorized signing inputs before device execution |
| T006 | Agent | After T003, T004, and T005, measure physical capability and freeze capture settings |
| T017 | Agent | After T006 and T016, measure the integrated baseline and freeze numerical release gates |
| T018 | Agent | After T017, complete physical M01–M24 and all frozen gates |

T001 completes local preparation only. WP-00 still needs the native baseline in T003.
Missing platform access does not block source preparation in this task.
Round 2 stays deferred until Round 1 passes and the post-field decision approves monochrome.
No publication or distribution is authorized by this record.
