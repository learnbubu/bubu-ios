#!/bin/bash
# Run the native app's unit tests on this Mac's iPhone simulator (free; no cloud minutes).
#   tools/mac-test.sh
# Needs Xcode and XcodeGen (brew install xcodegen).
set -euo pipefail
cd "$(dirname "$0")/.."
git pull --ff-only
command -v xcodegen >/dev/null || brew install xcodegen
(cd native && xcodegen generate)
SIM=$(xcrun simctl list devices available | grep -E "iPhone 1[5-9]( |$| Pro )" | grep -v Max | head -1 | sed -E 's/.*\(([0-9A-F-]{36})\).*/\1/')
echo "Simulator $SIM"
cd native
xcodebuild -project Bubu.xcodeproj -scheme Bubu -destination "id=$SIM" \
  -derivedDataPath ../build CODE_SIGNING_ALLOWED=NO test 2>&1 | tee ../test.log \
  | grep -E "error:|Test Case .*failed|Executed|TEST (SUCCEEDED|FAILED)"
