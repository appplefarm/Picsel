#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/../.."
test_dir=$(mktemp -d /tmp/picsel-network-tests.XXXXXX)
xcrun swiftc -swift-version 5 -default-isolation MainActor \
  -target "$(uname -m)-apple-macos15.0" -parse-as-library \
  -module-cache-path /tmp/picsel-network-module-cache \
  Picsel/Sources/App/Support/NetworkRecovery.swift \
  Picsel/Sources/App/Support/TripImageStore.swift \
  Picsel/Sources/Models/StaticModels.swift \
  Picsel/Sources/Models/DatabaseModels.swift \
  Picsel/Sources/Features/Planning/API/TourAPIManager.swift \
  Picsel/Sources/Features/Planning/API/TourResponse.swift \
  Picsel/Sources/Features/Planning/TransitSwipeViewModel.swift \
  Picsel/Sources/Features/RouteConfirmation/Services/RouteDirections.swift \
  Picsel/Sources/Features/RouteConfirmation/Support/Trip+RouteOrder.swift \
  Picsel/Sources/Features/RouteConfirmation/ViewModels/RouteConfirmationViewModel.swift \
  Picsel/Sources/Features/PhotoExplore/Models/PhotoDestination.swift \
  Picsel/Sources/Features/PhotoExplore/Models/DestinationDetailInfo.swift \
  Picsel/Sources/Features/PhotoExplore/ViewModels/DestinationDetailViewModel.swift \
  Picsel/Sources/Features/PhotoExplore/Services/RemotePhotoImageLoader.swift \
  Tools/NetworkRecovery/validate_network_recovery.swift \
  -o "$test_dir/validate"
"$test_dir/validate"
