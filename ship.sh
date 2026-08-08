#!/bin/bash
# Ship Baby Beat to TestFlight.
#
# Archives, signs, and uploads to App Store Connect; the "Baby Beat Team"
# internal group has automatic distribution, so the build lands on
# everyone's TestFlight with no further steps.
#
# Signing note: this must run on a Mac whose Xcode is signed into the
# team account holder's Apple ID (Individual memberships keep signing
# owner-only). Build numbers bump automatically on upload.
set -euo pipefail
cd "$(dirname "$0")"

command -v xcodegen >/dev/null || { echo "xcodegen missing: brew install xcodegen"; exit 1; }
xcodegen generate

WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' EXIT

echo "── archiving…"
xcodebuild -project BabyBeat.xcodeproj -scheme BabyBeat \
  -destination 'generic/platform=iOS' \
  archive -archivePath "$WORK/BabyBeat.xcarchive" \
  -allowProvisioningUpdates -quiet

/usr/libexec/PlistBuddy -c 'Add :method string app-store-connect' \
  -c 'Add :destination string upload' \
  -c 'Add :teamID string TU3QY46Z5S' \
  -c 'Add :uploadSymbols bool true' \
  -c 'Add :manageAppVersionAndBuildNumber bool true' \
  "$WORK/ExportOptions.plist" >/dev/null

echo "── uploading to App Store Connect…"
xcodebuild -exportArchive -archivePath "$WORK/BabyBeat.xcarchive" \
  -exportOptionsPlist "$WORK/ExportOptions.plist" \
  -exportPath "$WORK/export" -allowProvisioningUpdates

echo "✓ shipped — TestFlight will notify the Baby Beat Team group after processing (~10 min)."
