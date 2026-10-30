#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
./scripts/bootstrap.sh
# Use an installed simulator UUID, not an assumed device name or runtime version.
if [[ -z "${SLIT_SIMULATOR_ID:-}" ]]; then
  SLIT_SIMULATOR_ID="$(xcrun simctl list devices available --json | python3 -c '
import json, sys
items = [d for group in json.load(sys.stdin)["devices"].values() for d in group if d.get("isAvailable") and "iPhone" in d["name"]]
items.sort(key=lambda d: ("iPhone 16 Plus" not in d["name"], d["name"], d["udid"]))
if not items: sys.exit("No iPhone simulator is installed. Install an iOS runtime in Xcode Settings.")
print(items[0]["udid"])
')"
fi
mkdir -p build/test-results
result_path="build/test-results/ui-$(date +%Y%m%d-%H%M%S)-$$.xcresult"
xcodebuild -project Slit.xcodeproj -scheme Slit -configuration Debug \
  -destination "platform=iOS Simulator,id=$SLIT_SIMULATOR_ID" \
  -derivedDataPath build/DerivedData -resultBundlePath "$result_path" \
  CODE_SIGNING_ALLOWED=NO test
