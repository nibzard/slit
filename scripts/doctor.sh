#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
if [[ "$(uname -s)" != Darwin ]]; then
  echo 'Native builds require macOS with Xcode. On this host, run make check.' >&2
  exit 1
fi
for tool in xcodebuild xcrun swift python3 xcodegen; do
  if ! command -v "$tool" >/dev/null 2>&1; then
    echo "Missing $tool. See docs/handoff/SETUP.md." >&2
    exit 1
  fi
done
xcodebuild -version
swift --version
xcodegen --version
python3 - <<'PY'
import re, subprocess
from pathlib import Path
version = subprocess.check_output(['xcodebuild', '-version'], text=True)
assert int(re.search(r'Xcode (\d+)', version)[1]) >= 16, 'Xcode 16 or newer is required'
minimum = tuple(map(int, Path('.xcodegen-version').read_text().strip().split('.')))
actual = subprocess.check_output(['xcodegen', '--version'], text=True)
found = tuple(map(int, re.search(r'(\d+\.\d+\.\d+)', actual)[1].split('.')))
assert found >= minimum, f'XcodeGen {minimum} or newer is required'
PY
xcrun --sdk iphoneos --show-sdk-version
