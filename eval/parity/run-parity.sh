#!/bin/bash
# Capture stock + SmartSpace on one simulator, then pixel-diff the key area.
# Usage: run-parity.sh <udid> <slug> "<label>"
set -uo pipefail
REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
S="${PARITY_OUT:-$HOME/.smartspace-parity}"
mkdir -p "$S"
APP=$S/DD/Build/Products/Debug-iphonesimulator/SmartSpace.app
UDID=$1; SLUG=$2; LABEL=$3

xcrun simctl boot "$UDID" >/dev/null 2>&1
xcrun simctl bootstatus "$UDID" >/dev/null 2>&1
xcrun simctl install "$UDID" "$APP" >/dev/null 2>&1
# Stale crops once reported a fixed colour as still broken after the fix
# landed, so every run starts by deleting its own outputs (2026-08-18).
rm -rf "$S/rb-$SLUG.xcresult" "$S/att-$SLUG" "$S/px-$SLUG-stock.png" \
       "$S/px-$SLUG-smart.png" "$S/px-$SLUG-diff.png"

# The project path is pinned: the run inherited the caller's directory and
# every device failed with "does not contain an Xcode project" (2026-08-18).
xcodebuild test-without-building -scheme SmartSpace \
  -project "$REPO/app/SmartSpace.xcodeproj" \
  -only-testing:SmartSpaceUITests/EnableKeyboardTests \
  -only-testing:SmartSpaceUITests/ParityShotTests \
  -destination "platform=iOS Simulator,id=$UDID" \
  -derivedDataPath "$S/DD" -resultBundlePath "$S/rb-$SLUG.xcresult" \
  > "$S/parity-$SLUG.log" 2>&1

SCREEN=$(grep -o 'PARITY screen=([^)]*)' "$S/parity-$SLUG.log" | head -1 | tr -d '()' | sed 's/PARITY screen=//')
QTOP=$(grep -o 'PARITY stock q=([^)]*)' "$S/parity-$SLUG.log" | head -1 | tr -d '()' | sed 's/PARITY stock q=//' | cut -d, -f2 | tr -d ' ')
W=$(echo "$SCREEN" | cut -d, -f3 | tr -d ' ')
H=$(echo "$SCREEN" | cut -d, -f4 | tr -d ' ')
if [ -z "$QTOP" ] || [ -z "$W" ]; then
  echo "{\"device\": \"$LABEL\", \"error\": \"no PARITY frames captured, see $S/parity-$SLUG.log\"}"
  exit 1
fi

xcrun xcresulttool export attachments --path "$S/rb-$SLUG.xcresult" --output-path "$S/att-$SLUG" > "$S/att-$SLUG.txt" 2>&1
STOCK=$(python3 -c "
import json,sys
m=json.load(open('$S/att-$SLUG/manifest.json'))
for t in m:
    for a in t.get('attachments',[]):
        if a.get('suggestedHumanReadableName','').startswith('stock'): print(a['exportedFileName'])
" | head -1)
SMART=$(python3 -c "
import json,sys
m=json.load(open('$S/att-$SLUG/manifest.json'))
for t in m:
    for a in t.get('attachments',[]):
        if a.get('suggestedHumanReadableName','').startswith('smartspace'): print(a['exportedFileName'])
" | head -1)
python3 "$S/pixdiff.py" "$S/att-$SLUG/$STOCK" "$S/att-$SLUG/$SMART" "$QTOP" "$W" "$H" "$S/px-$SLUG" "$LABEL"
xcrun simctl shutdown "$UDID" >/dev/null 2>&1
