#!/bin/bash
#
# build-example.sh
# SwiftKLine
#
# Created by zhwayne on 2026/10/21.
#

set -euo pipefail
cd "$(dirname "$0")/.."
exec xcodebuild build -project SwiftKLineExample.xcodeproj -scheme SwiftKLineExample \
    -destination 'generic/platform=iOS Simulator' CODE_SIGNING_ALLOWED=NO \
    -derivedDataPath "${SWIFTKLINE_DERIVED_DATA:-.build/xcode-example}"
