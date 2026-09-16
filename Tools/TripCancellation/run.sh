#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/../.."
test_dir=$(mktemp -d /tmp/picsel-cancellation-tests.XXXXXX)
xcrun swiftc -swift-version 5 -default-isolation MainActor \
  -target "$(uname -m)-apple-macos15.0" -parse-as-library \
  -module-cache-path /tmp/picsel-cancellation-module-cache \
  Picsel/Sources/Models/DatabaseModels.swift \
  Picsel/Sources/App/AppRouter.swift \
  Tools/TripCancellation/validate_trip_cancellation.swift \
  -o "$test_dir/validate"
"$test_dir/validate"
