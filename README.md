# Slit

A native street camera for iPhone 16 Plus. Stills only, one main camera, fixed 1× framing.
The user selected Grip: a dark frame, a large shutter on the lower right, and an optional grid.

**Status: project bootstrap, not a working camera.**
The SwiftUI shell and shared state rules are present. Native capture, storage, review, and device testing remain to implement.
No Swift or Xcode build has run on the Linux preparation host.

## Start here

1. Read the [handoff status](docs/handoff/STATUS.md).
2. Read the [first native MVP specification](docs/specs/0002-first-native-mvp.md).
3. Follow the [macOS setup](docs/handoff/SETUP.md).
4. Take a work package from the [implementation backlog](docs/handoff/BACKLOG.md).
5. Use the [architecture and integration contracts](docs/handoff/ARCHITECTURE.md).
6. Record evidence with the [validation guide](docs/handoff/VALIDATION.md).

## Project map

| Path | Purpose |
| --- | --- |
| `project.yml` | XcodeGen source for app, UI tests, and shared scheme |
| `App/Sources` | Native Grip shell; future camera and library implementation |
| `App/Resources` | Privacy manifest; add native assets here |
| `App/UITests` | Shell checks; extend as native workflows become available |
| `Packages/SlitCore` | Platform-independent state rules and unit tests |
| `Config` | Shared configuration and an ignored local signing override |
| `docs/specs` | Product requirements; 0002 governs the first build |
| `docs/handoff` | Work packages, contracts, setup, and evidence templates |
| `docs/research` | Portable snapshots of selected research from `/notes/` |
| `experiments` | Browser prototype and earlier research experiments |
| `scripts` | Setup, checks, project generation, packaging, and research export |

## Commands

```sh
make check       # Portable checks; works without Xcode
make bootstrap   # macOS: validate tools and generate Slit.xcodeproj
make test-core   # Swift 6 toolchain: test shared state rules
make build       # macOS: unsigned simulator build
make test-ios    # macOS: shell tests on an available iPhone simulator
make handoff     # Create dist/slit-developer-handoff.zip
```

Open `Slit.xcodeproj` after generation. Do not edit the generated project file.
No third-party runtime packages are used. The app links the local SlitCore package.
The continuous integration workflow is supplied but has not run in a remote repository.

## Design reference

Open the [standalone Grip prototype](<experiments/20-29 Camera experience/20 Interface/20.01 Capture interface concepts/prototype.html>).
It works without a server. It simulates camera behavior and must not be used as performance evidence.
The [prototype programme](<experiments/20-29 Camera experience/20 Interface/20.01 Capture interface concepts/programme.md>) explains its limits.

No repository remote, team signing identity, or distribution license has been selected.
This handoff does not publish the project or send it to other people.
