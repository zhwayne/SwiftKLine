#!/bin/bash
#
# test-ios.sh
# SwiftKLine
#
# Created by zhwayne on 2026/10/21.
#

set -euo pipefail
cd "$(dirname "$0")/.."
if [[ -n "${SWIFTKLINE_DESTINATION:-}" ]]; then
    destination="$SWIFTKLINE_DESTINATION"
else
    simulator_id=$(xcrun simctl list devices available -j | python3 -c '
import json, sys
runtimes = json.load(sys.stdin)["devices"]
for runtime in sorted(runtimes, reverse=True):
    if "iOS" not in runtime: continue
    devices = [d for d in runtimes[runtime] if d.get("isAvailable") and "iPhone" in d["name"]]
    if devices:
        print(next((d for d in devices if d["state"] == "Booted"), devices[0])["udid"])
        break
')
    if [[ -z "$simulator_id" ]]; then
        echo "No iOS Simulator is installed. Add a runtime in Xcode or set SWIFTKLINE_DESTINATION." >&2
        exit 1
    fi
    destination="platform=iOS Simulator,id=$simulator_id"
fi
exec xcodebuild test -workspace .swiftpm/xcode/package.xcworkspace -scheme SwiftKLine-Package \
    -destination "$destination" -derivedDataPath "${SWIFTKLINE_DERIVED_DATA:-.build/xcode-tests}"
