# Street camera developer handoff

Date: October 30, 2026.
Status: Native project scaffold and developer handoff prepared; native compilation and device validation are pending.

## Scope

The user requested project bootstrapping and a complete handoff for a development team.
The first native specification remains authoritative. Grip and the optional grid are selected.
The handoff does not implement the complete camera or distribute a signed application.

## Prepared artifacts

- XcodeGen project specification, local signing override, and iOS 18 SwiftUI shell.
- A local SlitCore Swift package with capture admission and focus-operation tokens.
- Eight core tests and two shell UI tests.
- macOS build/test scripts and a continuous integration workflow.
- Team backlog, dependency order, architecture contracts, and four evidence templates.
- Portable research snapshots, an offline prototype, and a source archive with a SHA-256 manifest.

## Verified findings

The preparation host is Linux and has no Swift, Xcode, or XcodeGen executable.
Native compilation, project generation, and camera tests cannot be run on this host.
The disabled shutter and explicit placeholder prevent the shell from presenting a fake successful capture.
Portable checks cover source structure, file links, configuration parsing, script syntax, and acceptance coverage.
See the handoff validation report for actual executed checks.

XcodeGen 2.46.0 documents local Swift packages and generated app/test targets.
Apple's CA92.1 UserDefaults reason covers preferences accessible only to the application itself.
The manifest declares this existing use only; storage and timing implementation require a later API inventory.

Sources checked October 30, 2026:
[XcodeGen project specification](https://github.com/yonaskolb/XcodeGen/blob/2.46.0/Docs/ProjectSpec.md),
[XcodeGen release](https://github.com/yonaskolb/XcodeGen/releases/tag/2.46.0),
and [Apple required-reason APIs](https://developer.apple.com/documentation/bundleresources/app-privacy-configuration/nsprivacyaccessedapitypes/nsprivacyaccessedapitype).

## Open questions

The team must supply signing identity, assign owners, select a repository remote, and validate the native toolchain.
The physical phone must establish raw dimensions, focus behavior, review decoding, performance gates, and storage reserve.
No distribution license is selected. No code from researched camera repositories was copied.

Start with [the project README](../../README.md),
[handoff status](../handoff/STATUS.md),
and [the backlog](../handoff/BACKLOG.md).
