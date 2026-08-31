import CoreLocation
import Observation

@Observable
final class HomeViewModel {
    var userName = "동선"

    /// 위치 권한이 없거나 시뮬레이터 위치가 없을 때 사용할 안전한 초기값입니다.
    private(set) var fallbackCoordinate = CLLocationCoordinate2D(
        latitude: 36.0190,
        longitude: 129.3435
    )

    let radiusRange: ClosedRange<Double> = 0...150
    let radiusGuideValues: [Double] = [0, 40, 80, 120, 150]
    var currentRadiusKm = 80.0

    var currentRadiusMeters: Double { currentRadiusKm * 1_000 }
}
