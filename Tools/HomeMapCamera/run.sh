#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/../.."
test_dir=$(mktemp -d /tmp/picsel-home-camera.XXXXXX)
# 실제 Coordinator 코드를 추출합니다. SDK 렌더링 대신 카메라 요청 이력을 검증합니다.
awk 'BEGIN { print "import Foundation\nimport CoreGraphics" }
     /^    final class Coordinator \{/ { copying = 1 }
     copying { print }
     copying && /^    }/ { exit }' \
  Picsel/Sources/Features/Home/NaverMapView.swift > "$test_dir/Coordinator.swift"
xcrun swiftc -swift-version 5 -parse-as-library \
  Tools/HomeMapCamera/validate_home_camera.swift "$test_dir/Coordinator.swift" \
  -o "$test_dir/validate"
"$test_dir/validate"
