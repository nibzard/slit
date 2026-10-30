# Slit project instructions

Read [README.md](README.md), [handoff status](docs/handoff/STATUS.md), and the
[first native specification](docs/specs/0002-first-native-mvp.md) before implementation.
The first native specification governs this build. Historical research is supporting evidence, not additional scope.

## Product constraints

- Keep stills, one physical rear main camera, and 1× framing.
- Use Grip and its optional grid. Do not add modes, looks, or a distance scale.
- Preserve original bytes. Never claim Saved before the original bundle commits.
- Keep capture slots occupied through saving or retained save failures.
- Return from review without triggering capture.
- Do not copy the browser's simulated delays or in-memory captures into the native implementation.

## Working rules

- Use the generated Xcode project. Change `project.yml`, not the generated project file.
- Keep platform code in `App/Sources`; keep platform-independent state rules in `Packages/SlitCore`.
- Follow the ownership and integration rules in [architecture](docs/handoff/ARCHITECTURE.md).
- Run `make check`, `make test-core`, and relevant native checks before claiming a work package complete.
- Record unavailable checks explicitly. Simulator results do not prove raw capture, focus, or timing.
- Keep research notes in Markdown under `/notes/`, with dates, sources, findings, and open questions.
- Update portable research copies through `scripts/sync-research.py` when related notes change.
- Keep signing identifiers in ignored `Config/Local.xcconfig`; do not commit credentials or sample user photographs.
- Use `python3` for Python commands.
- Do not push, publish, message the team, or distribute a signed build without task authorization.

No open-source license has been selected. Do not infer a license from the research examples.
