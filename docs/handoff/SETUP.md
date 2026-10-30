# macOS setup

## Requirements

Use macOS with Xcode 16 or newer and an installed iOS simulator runtime.
Use the Swift 6 compiler in that Xcode installation. The project uses Swift 5 language mode with complete concurrency checking.
This is a compatibility starting point, not a claim that the project was compiled with every newer Xcode version.
XcodeGen 2.46.0 is the minimum generator version. `.xcodegen-version` records that minimum.
Record the exact installed versions in the [capability report](templates/capability-report.md).

## First build

1. Select the full Xcode installation with `sudo xcode-select -s /Applications/Xcode.app/Contents/Developer` if needed.
2. Open Xcode, complete its first-launch setup, and install an iOS simulator runtime.
3. Install XcodeGen with `brew install xcodegen` if it is absent.
4. Run `make bootstrap` from the project root.
5. Run `make check` and `make test-core`.
6. Run `make build` and `make test-ios`.
7. Open `Slit.xcodeproj`, select Slit, and run the development shell.

The scripts select an installed iPhone simulator. They prefer iPhone 16 Plus when available.
Override selection with an installed simulator identifier:

```sh
xcrun simctl list devices available
SLIT_SIMULATOR_ID=YOUR_SIMULATOR_UUID make test-ios
```

The core package's tests run separately from the app scheme with `make test-core`.
The Slit scheme contains the app's UI tests. Both commands are required in continuous integration.

## Device signing

Copy `Config/Local.xcconfig.example` to `Config/Local.xcconfig`.
Set `SLIT_BUNDLE_ID` to a unique identifier and `SLIT_TEAM_ID` to your Apple team identifier.
The local file is ignored by version control and excluded from the handoff archive.

```sh
cp Config/Local.xcconfig.example Config/Local.xcconfig
```

Edit the copied file, connect the phone, enable Developer Mode as required by the phone, and select it in Xcode.
Use automatic signing through the team's normal account setup.
Do not send certificates, provisioning profiles, private keys, or account credentials with this handoff.
The simulator scripts intentionally disable signing. Run device builds from Xcode with the local signing override.

## Generated files

XcodeGen creates `Slit.xcodeproj` and `App/Info.plist` from `project.yml`.
Both are ignored generated outputs. Re-run `make bootstrap` after changing the project specification.
Edit permission strings, targets, scheme definitions, and supported orientations in `project.yml`.

## Common setup failures

| Symptom | Action |
| --- | --- |
| `xcodebuild` cannot find Xcode | Select the full Xcode installation; Command Line Tools alone are insufficient |
| No simulator is installed | Install an iOS runtime in Xcode Settings; then list available devices |
| XcodeGen version is too old | Upgrade it or install the official 2.46.0 release; record the selected version |
| Device signing fails | Check the local identifier, team, device registration, and selected account |
| Camera is unavailable in the shell | Expected: implement WP-01 and WP-02; the scaffold does not open a camera |
| Tests are missing from the app scheme | Core tests are a separate Swift package; run `make test-core` |

## Sources

Checked October 30, 2026:
[XcodeGen project format](https://github.com/yonaskolb/XcodeGen/blob/2.46.0/Docs/ProjectSpec.md),
[XcodeGen release](https://github.com/yonaskolb/XcodeGen/releases/tag/2.46.0), and
[Apple UserDefaults privacy reason](https://developer.apple.com/documentation/bundleresources/app-privacy-configuration/nsprivacyaccessedapitypes/nsprivacyaccessedapitype).
The privacy manifest describes current shell usage. Reassess it when storage and timing APIs are implemented.
