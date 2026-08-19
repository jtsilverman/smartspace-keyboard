#!/bin/bash
# Stock-parity sweep: capture the stock keyboard and SmartSpace on every
# iPhone 16 and 17 simulator, then report the cap deltas in points.
#
# Usage:
#   PARITY_OUT=<dir> eval/parity/run-all.sh
# Build first, into the same output dir:
#   xcodebuild build-for-testing -scheme SmartSpace -project app/SmartSpace.xcodeproj \
#     -destination 'platform=iOS Simulator,name=iPhone 17' -derivedDataPath $PARITY_OUT/DD
set -uo pipefail
REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
S="${PARITY_OUT:-$HOME/.smartspace-parity}"
mkdir -p "$S"

# Device types, newest runtime available. Missing simulators are created.
DEVICES=(
"iPhone 16|iPhone-16"
"iPhone 16 Plus|iPhone-16-Plus"
"iPhone 16 Pro|iPhone-16-Pro"
"iPhone 16 Pro Max|iPhone-16-Pro-Max"
"iPhone 16e|iPhone-16e"
"iPhone 17|iPhone-17"
"iPhone 17 Pro|iPhone-17-Pro"
"iPhone 17 Pro Max|iPhone-17-Pro-Max"
"iPhone Air|iPhone-Air"
)
RUNTIME=$(xcrun simctl list runtimes 2>/dev/null | grep -o 'com.apple.CoreSimulator.SimRuntime.iOS-[0-9-]*' | tail -1)

ok=0; failed=0
for row in "${DEVICES[@]}"; do
  IFS='|' read -r label type <<< "$row"
  slug=$(echo "$label" | tr 'A-Z ' 'a-z-')
  udid=$(xcrun simctl list devices available 2>/dev/null \
         | grep -F "$label (" | head -1 | sed -E 's/.*\(([0-9A-F-]{36})\).*/\1/')
  if [ -z "$udid" ]; then
    udid=$(xcrun simctl create "$label" "com.apple.CoreSimulator.SimDeviceType.$type" "$RUNTIME" 2>/dev/null)
  fi
  if [ -z "$udid" ]; then
    echo "{\"device\": \"$label\", \"error\": \"no simulator and none could be created\"}"
    failed=$((failed+1)); continue
  fi
  if ! bash "$REPO/eval/parity/run-parity.sh" "$udid" "$slug" "$label" > /dev/null 2>&1; then
    echo "{\"device\": \"$label\", \"error\": \"capture failed, see $S/parity-$slug.log\"}"
    failed=$((failed+1)); continue
  fi
  W=$(grep -o 'PARITY screen=([^)]*)' "$S/parity-$slug.log" | head -1 | tr -d '()' \
      | sed 's/PARITY screen=//' | cut -d, -f3 | tr -d ' ')
  SCALE=$(python3 -c "from PIL import Image; print(Image.open('$S/px-$slug-stock.png').width / $W)")
  python3 "$REPO/eval/parity/analyze.py" "$S/px-$slug-stock.png" "$S/px-$slug-smart.png" "$SCALE" "$label"
  ok=$((ok+1))
done
echo "MEASURED $ok devices, FAILED $failed"
[ "$failed" -eq 0 ]
