#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
./scripts/doctor.sh
xcodegen generate --spec project.yml
printf '%s\n' 'Generated Slit.xcodeproj. Open it in Xcode; select the Slit scheme.'
