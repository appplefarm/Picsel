#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/../.."
test_dir=$(mktemp -d /tmp/picsel-snap-tests.XXXXXX)
xcrun swiftc -swift-version 5 -default-isolation MainActor \
  -target "$(uname -m)-apple-macos15.0" -parse-as-library \
  -module-cache-path /tmp/picsel-snap-module-cache \
  Picsel/Sources/Models/StaticModels.swift \
  Picsel/Sources/Features/PhotoExplore/Models/PhotoDestination.swift \
  Picsel/Sources/Features/PhotoExplore/Models/SpatialPlaceItem.swift \
  Picsel/Sources/Features/PhotoExplore/Scene/PhotoSpace.swift \
  Picsel/Sources/Features/PhotoExplore/Interaction/PhotoCamera.swift \
  Picsel/Sources/Features/PhotoExplore/Interaction/PhotoInteractionSettings.swift \
  Picsel/Sources/Features/PhotoExplore/Interaction/PhotoSelectionPolicy.swift \
  Picsel/Sources/Features/PhotoExplore/Interaction/PhotoSnapNavigation.swift \
  Picsel/Sources/Features/PhotoExplore/ViewModels/SpatialPhotoCanvasViewModel.swift \
  Tools/PhotoSnapNavigation/validate_snap_navigation.swift \
  -o "$test_dir/validate"
"$test_dir/validate"
