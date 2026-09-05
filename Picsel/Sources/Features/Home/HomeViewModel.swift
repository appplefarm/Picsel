import CoreLocation
import Observation

@Observable
final class HomeViewModel {
    /// 값이 클수록 가까운 거리 구간이 Slider에서 더 넓은 영역을 차지합니다.
    private let radiusSliderCurve = 3.0

    /// 위치 권한이 없거나 시뮬레이터 위치가 없을 때 사용할 안전한 초기값입니다.
    private(set) var fallbackCoordinate = CLLocationCoordinate2D(
        latitude: 36.0190,
        longitude: 129.3435
    )

    /// 현재 위치에서 대한민국 4극점 중 가장 먼 곳까지의 직선거리입니다.
    /// 실제 극점이 범위 안에 포함되도록 km 단위로 올림합니다.
    private(set) var maximumRadiusKm = 710.0
    private(set) var farthestExtremePoint: KoreaExtremePoint?
    var currentRadiusKm = 80.0

    var radiusRange: ClosedRange<Double> { 0...maximumRadiusKm }

    /// Slider의 동일한 위치 간격에 해당하는 로그 스케일 거리 눈금입니다.
    var radiusGuideValues: [Double] {
        [0.0, 0.25, 0.5, 0.75, 1.0].map(radiusKm(forSliderPosition:))
    }

    var currentRadiusMeters: Double { currentRadiusKm * 1_000 }

    /// SwiftUI Slider가 사용하는 0...1 위치와 실제 km를 비선형으로 변환합니다.
    /// 0km를 지원하기 위해 위치→거리는 지수 함수, 거리→위치는 그 역함수를 사용합니다.
    var radiusSliderPosition: Double {
        get {
            guard maximumRadiusKm > 0 else { return 0 }
            let normalizedRadius = currentRadiusKm / maximumRadiusKm
            let curveRange = exp(radiusSliderCurve) - 1
            return log(1 + normalizedRadius * curveRange) / radiusSliderCurve
        }
        set {
            currentRadiusKm = radiusKm(forSliderPosition: newValue)
        }
    }

    init() {
        updateMaximumRadius(from: fallbackCoordinate)
    }

    func updateMaximumRadius(from coordinate: CLLocationCoordinate2D) {
        let currentLocation = CLLocation(
            latitude: coordinate.latitude,
            longitude: coordinate.longitude
        )

        guard let farthest = KoreaExtremePoint.allCases.max(by: {
            distance(from: currentLocation, to: $0)
                < distance(from: currentLocation, to: $1)
        }) else { return }

        let farthestDistanceKm = distance(from: currentLocation, to: farthest) / 1_000
        maximumRadiusKm = max(1, ceil(farthestDistanceKm))
        farthestExtremePoint = farthest

        // 위치 갱신으로 최댓값이 작아져도 Slider 값이 범위를 벗어나지 않게 합니다.
        currentRadiusKm = min(max(currentRadiusKm, radiusRange.lowerBound), radiusRange.upperBound)
    }

    private func distance(
        from location: CLLocation,
        to extremePoint: KoreaExtremePoint
    ) -> CLLocationDistance {
        location.distance(from: extremePoint.location)
    }

    private func radiusKm(forSliderPosition position: Double) -> Double {
        let clampedPosition = min(max(position, 0), 1)
        let curveRange = exp(radiusSliderCurve) - 1
        let normalizedRadius = (exp(radiusSliderCurve * clampedPosition) - 1) / curveRange
        return (maximumRadiusKm * normalizedRadius).rounded()
    }
}

/// 대한민국에서 현재 실효적으로 접근 가능한 4대 극지의 대표 좌표입니다.
/// CLLocation의 WGS84 좌표계에서 두 지점 사이의 측지 직선거리를 계산합니다.
enum KoreaExtremePoint: String, CaseIterable {
    case north = "극북 · 강원 고성군"
    case south = "극남 · 마라도"
    case east = "극동 · 독도"
    case west = "극서 · 백령도"

    var coordinate: CLLocationCoordinate2D {
        switch self {
        case .north:
            CLLocationCoordinate2D(latitude: 38.6167, longitude: 128.3700)
        case .south:
            CLLocationCoordinate2D(latitude: 33.1119, longitude: 126.2667)
        case .east:
            CLLocationCoordinate2D(latitude: 37.2408, longitude: 131.8728)
        case .west:
            CLLocationCoordinate2D(latitude: 37.9500, longitude: 124.6100)
        }
    }

    var location: CLLocation {
        CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
    }
}
