#!/bin/bash
# Reset ALL learned keyboard state before any checker- or extension-dependent
# benchmark: the system's dynamic lexicon (UITextChecker rankings adapt to
# typed text) AND the extension's own UserDefaults (outcome-log trains
# PersonalRanking -- five smoke-test ?->. cycles permanently flipped question
# predictions to '.', observed 2026-07-29). Run solo, never alongside another
# xcodebuild session on the same simulator.
#
# Usage: eval/v4/reset-keyboard-state.sh <simulator-udid>
set -euo pipefail

UDID="${1:?usage: reset-keyboard-state.sh <simulator-udid>}"
DATA="$HOME/Library/Developer/CoreSimulator/Devices/$UDID/data"

xcrun simctl shutdown "$UDID" 2>/dev/null || true
rm -rf "$DATA/Library/Keyboard"/*
find "$DATA/Containers" -path "*Preferences/com.jtsilverman.smartspace*" -name "*.plist" -delete
xcrun simctl boot "$UDID"
echo "keyboard model + extension state reset for $UDID"
