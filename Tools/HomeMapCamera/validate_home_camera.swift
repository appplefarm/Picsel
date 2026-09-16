import Foundation
import CoreGraphics

// NMapsMap/UIKit만 대체합니다. Coordinator는 run.sh가 프로덕션 파일에서 추출합니다.
struct Coordinate: Equatable {
    var latitude: Double
    var longitude: Double
}
struct NaverMapRepresentable: Equatable {
    var coordinate: Coordinate
    var radiusMeters = 80_000.0
    var circleDiameterPoints = 270.0
    var isValidOrigin: Bool

    func applyCamera(to mapView: NMFMapView, animated: Bool) {
        mapView.requests.append((self, animated))
    }
}
final class NMFMapView {
    var bounds = CGRect.zero
    var window: Bool?
    var requests: [(configuration: NaverMapRepresentable, animated: Bool)] = []
}

@main struct HomeCameraChecks {
    static func main() {
        let coordinator = Coordinator()
        let map = NMFMapView()
        let fallback = NaverMapRepresentable(
            coordinate: Coordinate(latitude: 36.019, longitude: 129.3435), isValidOrigin: false
        )
        var current = NaverMapRepresentable(
            coordinate: Coordinate(latitude: 37.5665, longitude: 126.978), isValidOrigin: true
        )
        coordinator.update(fallback, mapView: map)
        coordinator.update(current, mapView: map)
        precondition(map.requests.isEmpty, "레이아웃 전 요청은 보관만 해야 합니다")
        map.window = true
        coordinator.applyLatestCamera(to: map)
        precondition(map.requests.isEmpty, "0 크기에서는 fit을 요청하면 안 됩니다")
        map.bounds.size = CGSize(width: 402, height: 458)
        coordinator.applyLatestCamera(to: map)
        precondition(map.requests.count == 1 && map.requests.last?.configuration == current,
                     "슬라이더 변경 없이 최신 GPS 위치를 처음 적용해야 합니다")
        precondition(map.requests.last?.animated == false)
        for _ in 0..<100 {
            coordinator.update(current, mapView: map)
            coordinator.applyLatestCamera(to: map)
        }
        precondition(map.requests.count == 1, "반복 레이아웃에서 카메라를 중복 이동하면 안 됩니다")
        current.coordinate = Coordinate(latitude: 35.1796, longitude: 129.0756)
        coordinator.update(current, mapView: map)
        precondition(map.requests.count == 2 && map.requests.last?.animated == true)
        current.radiusMeters = 100_000
        coordinator.update(current, mapView: map)
        precondition(map.requests.count == 3 && map.requests.last?.animated == false)
        map.bounds.size.height = 330
        coordinator.applyLatestCamera(to: map)
        precondition(map.requests.count == 4 && map.requests.last?.animated == false)

        // GPS가 지도보다 늦게 오는 순서, 권한 거절 후 수동 위치 선택도 같은 경로입니다.
        let late = Coordinator()
        let readyMap = NMFMapView()
        readyMap.window = true
        readyMap.bounds.size = CGSize(width: 402, height: 458)
        late.update(fallback, mapView: readyMap)
        late.update(current, mapView: readyMap)
        precondition(readyMap.requests.count == 2 && readyMap.requests.last?.configuration == current)
        current.isValidOrigin = false
        late.update(current, mapView: readyMap)
        precondition(readyMap.requests.last?.configuration.isValidOrigin == false)
        current.isValidOrigin = true
        late.update(current, mapView: readyMap)
        precondition(readyMap.requests.count == 4 && readyMap.requests.last?.configuration.isValidOrigin == true)

        // 화면에 붙기 전 좌표가 갱신되면, 붙은 뒤 최신 값으로 한 번만 적용합니다.
        map.window = nil
        current.coordinate.latitude = 37.5
        coordinator.update(current, mapView: map)
        precondition(map.requests.count == 4)
        map.window = true
        coordinator.applyLatestCamera(to: map)
        precondition(map.requests.count == 5 && map.requests.last?.configuration == current)
        print("PASS: 초기 GPS 순서, 0 크기, 중복 방지, 위치/반경/레이아웃 변경, 권한/수동 위치, 재연결")
    }
}
