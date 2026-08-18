# Stock-parity harness

Measures how far the SmartSpace keyboard sits from the stock iOS keyboard, in
points, from screenshots. Screenshots are the oracle: the accessibility tree
reports touch cells for stock and visible caps for SmartSpace, so the two are
not comparable (`~/Documents/brain/wiki/patterns/ios-xcode-swift.md`).

## Run

```
export PARITY_OUT=/tmp/parity
xcodebuild build-for-testing -scheme SmartSpace -project app/SmartSpace.xcodeproj \
  -destination 'platform=iOS Simulator,name=iPhone 17' -derivedDataPath $PARITY_OUT/DD
eval/parity/run-all.sh
```

Each device prints one JSON line: cap deltas in points, the space-bar delta,
and the function-key fills for both keyboards. The run exits non-zero if any
device fails to capture, and deletes its own crops first, so a failed capture
can never report the previous run's numbers.

## Parts

| File | Job |
|---|---|
| `run-all.sh` | Sweeps every iPhone 16/17 simulator, creating any that are missing |
| `run-parity.sh` | One device: install, enable the keyboard, capture both keyboards |
| `analyze.py` | Cap positions and sizes, and the function-key fills |
| `pixdiff.py` | Whole-key-area difference and a red overlay image |
| `assembly.py` | Top of the keyboard assembly, which gives the band above the keys |

`ParityShotTests` in `app/SmartSpaceUITests` drives the simulator and attaches
the two screenshots; `run-parity.sh` exports them from the result bundle.
