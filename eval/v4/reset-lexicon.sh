#!/bin/bash
# Reset the simulator's learned keyboard model before any checker-dependent
# benchmark (typos, protection, completions, scenarios). UITextChecker
# rankings adapt to typed text, so benchmark runs are order-dependent
# without this (observed 2026-07-28: typo miscorrections 4 -> 18 after an
# XCUITest typing session). Run solo -- never alongside another xcodebuild
# session on the same simulator.
#
# Usage: eval/v4/reset-lexicon.sh <simulator-udid>
set -euo pipefail

UDID="${1:?usage: reset-lexicon.sh <simulator-udid>}"
KEYBOARD_DIR="$HOME/Library/Developer/CoreSimulator/Devices/$UDID/data/Library/Keyboard"

xcrun simctl shutdown "$UDID" 2>/dev/null || true
rm -rf "$KEYBOARD_DIR"/*
xcrun simctl boot "$UDID"
echo "keyboard model reset for $UDID"
