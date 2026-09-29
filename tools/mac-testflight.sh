#!/bin/bash
# Build the native app on this Mac and upload it to TestFlight (free; no cloud minutes).
#   BUBU_TEAM=<your 10-character Apple team ID> tools/mac-testflight.sh
# One-off setup on the Mac:
#   - Xcode signed in to the developer account: Xcode → Settings → Accounts
#   - XcodeGen: brew install xcodegen
#   - the team ID is on developer.apple.com → Account → Membership details;
#     put `export BUBU_TEAM=...` in ~/.zshrc so it's always set
# Signing is automatic (Xcode makes or reuses the App Store certificate and profile).
set -euo pipefail
: "${BUBU_TEAM:?Set BUBU_TEAM to your Apple team ID (developer.apple.com → Membership details)}"
cd "$(dirname "$0")/.."
git pull --ff-only
command -v xcodegen >/dev/null || brew install xcodegen
(cd native && xcodegen generate)

# every upload needs a higher build number: the date and time always goes up
BUILD=$(date +%Y%m%d%H%M)
echo "Build number $BUILD"
OUT=build/testflight
rm -rf "$OUT"; mkdir -p "$OUT"

xcodebuild -project native/Bubu.xcodeproj -scheme Bubu -configuration Release \
  -destination "generic/platform=iOS" -archivePath "$OUT/Bubu.xcarchive" \
  -allowProvisioningUpdates DEVELOPMENT_TEAM="$BUBU_TEAM" CODE_SIGN_STYLE=Automatic \
  CURRENT_PROJECT_VERSION="$BUILD" archive | grep -E "error:|ARCHIVE (SUCCEEDED|FAILED)"

cat > "$OUT/ExportOptions.plist" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
  <key>method</key><string>app-store-connect</string>
  <key>destination</key><string>upload</string>
  <key>signingStyle</key><string>automatic</string>
  <key>teamID</key><string>$BUBU_TEAM</string>
</dict></plist>
EOF

xcodebuild -exportArchive -archivePath "$OUT/Bubu.xcarchive" -exportPath "$OUT" \
  -exportOptionsPlist "$OUT/ExportOptions.plist" -allowProvisioningUpdates \
  | grep -E "error:|EXPORT (SUCCEEDED|FAILED)|Upload"
echo "Uploaded build $BUILD. Apple takes 5-15 minutes to process it, then it appears in TestFlight."
