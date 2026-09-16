#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/../.."
test_dir=$(mktemp -d /tmp/picsel-panorama-tests.XXXXXX)
xcrun swiftc -swift-version 5 -default-isolation MainActor -parse-as-library \
  -target "$(uname -m)-apple-macos15.0" \
  Picsel/Sources/Features/History/Views/Components/TripHistoryCard.swift \
  Picsel/Sources/Features/TripCompletion/Views/Components/VisitedPlaceCardView.swift \
  Tools/PanoramaLayout/validate_panorama_layout.swift \
  -o "$test_dir/validate"
"$test_dir/validate"
