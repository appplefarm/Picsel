import CoreLocation
import NMapsMap
import SwiftUI

/// 네이버 지도는 카메라만 담당합니다.
/// 반경 원과 현재 위치 표시는 SwiftUI 오버레이이므로 줌과 관계없이 고정됩니다.
struct NaverMapView: View {
    let coordinate: CLLocationCoordinate2D
    let radiusMeters: Double
    var isValidOrigin: Bool = true

    var body: some View {
        ZStack {
            NaverMapRepresentable(
                coordinate: coordinate,
                radiusMeters: radiusMeters,
                circleDiameterPoints: HomeMapStyle.radiusCircleDiameter,
                isValidOrigin: isValidOrigin
            )

            if isValidOrigin {
                FixedRadiusOverlay()
            }
        }
    }
}

private struct NaverMapRepresentable: UIViewRepresentable {
    let coordinate: CLLocationCoordinate2D
    let radiusMeters: CLLocationDistance
    let circleDiameterPoints: CGFloat
    let isValidOrigin: Bool

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeUIView(context: Context) -> LayoutAwareMapView {
        let naverMapView = LayoutAwareMapView(frame: .zero)
        naverMapView.showLocationButton = false
        naverMapView.showZoomControls = false
        naverMapView.showCompass = false
        naverMapView.showScaleBar = false
        naverMapView.showIndoorLevelPicker = false

        let mapView = naverMapView.mapView
        mapView.customStyleId = HomeMapStyle.customStyleID
        mapView.isScrollGestureEnabled = false
        mapView.isZoomGestureEnabled = false
        mapView.isRotateGestureEnabled = false
        mapView.isTiltGestureEnabled = false
        mapView.isStopGestureEnabled = false

        naverMapView.onLayout = { [weak coordinator = context.coordinator] mapView in
            coordinator?.applyLatestCamera(to: mapView)
        }
        context.coordinator.update(self, mapView: mapView)

        return naverMapView
    }

    func updateUIView(_ naverMapView: LayoutAwareMapView, context: Context) {
        context.coordinator.update(self, mapView: naverMapView.mapView)
    }

    static func dismantleUIView(_ naverMapView: LayoutAwareMapView, coordinator: Coordinator) {
        naverMapView.onLayout = nil
        naverMapView.mapView.cancelTransitions()
    }

    private func applyCamera(to mapView: NMFMapView, animated: Bool) {
        let update: NMFCameraUpdate

        if isValidOrigin {
            let center = NMGLatLng(
                lat: coordinate.latitude,
                lng: coordinate.longitude
            )
            let safeRadius = max(radiusMeters, HomeMapStyle.minimumCameraRadiusMeters)
            let bounds = NMGLatLngBounds(
                southWest: center.offset(-safeRadius, withEastMeter: -safeRadius),
                northEast: center.offset(safeRadius, withEastMeter: safeRadius)
            )

            update = NMFCameraUpdate(
                fit: bounds,
                paddingInsets: cameraPaddingInsets(for: mapView.bounds.size)
            )
        } else {
            let points = KoreaExtremePoint.allCases.map {
                NMGLatLng(lat: $0.coordinate.latitude, lng: $0.coordinate.longitude)
            }
            let bounds = NMGLatLngBounds(latLngs: points)
            update = NMFCameraUpdate(
                fit: bounds,
                paddingInsets: HomeMapStyle.fallbackPaddingInsets
            )
        }

        if animated {
            update.animation = .easeOut
        }
        mapView.moveCamera(update)
    }

    /// 선택 반경이 화면 중앙의 270pt 원 안에 들어오도록 지도 SDK의 fit-bounds 여백을 계산합니다.
    private func cameraPaddingInsets(for mapSize: CGSize) -> UIEdgeInsets {
        let horizontal = max((mapSize.width - circleDiameterPoints) / 2, 0)
        let vertical = max((mapSize.height - circleDiameterPoints) / 2, 0)
        return UIEdgeInsets(top: vertical, left: horizontal, bottom: vertical, right: horizontal)
    }

    final class Coordinator {
        private var latest: NaverMapRepresentable?
        private var applied: NaverMapRepresentable?
        private var appliedSize: CGSize?

        func update(_ configuration: NaverMapRepresentable, mapView: NMFMapView) {
            latest = configuration
            applyLatestCamera(to: mapView)
        }

        func applyLatestCamera(to mapView: NMFMapView) {
            let size = mapView.bounds.size
            // 위치가 먼저 도착해도 버리지 않고, 실제 지도 레이아웃 이후 최신 값으로 적용합니다.
            guard let latest, mapView.window != nil, size.width > 0, size.height > 0 else { return }
            let sizeChanged = appliedSize != size
            let radiusChanged = applied?.radiusMeters != latest.radiusMeters
                || applied?.circleDiameterPoints != latest.circleDiameterPoints
            let coordinateChanged = applied?.coordinate.latitude != latest.coordinate.latitude
                || applied?.coordinate.longitude != latest.coordinate.longitude
            let originChanged = applied?.isValidOrigin != latest.isValidOrigin
            guard sizeChanged || radiusChanged || coordinateChanged || originChanged else { return }

            // 첫 배치·크기 변경·Slider는 즉시 맞추고, 이후 위치 변경만 애니메이션합니다.
            latest.applyCamera(
                to: mapView,
                animated: applied != nil && !sizeChanged && !radiusChanged
            )
            applied = latest
            appliedSize = size
        }
    }

    final class LayoutAwareMapView: NMFNaverMapView {
        var onLayout: ((NMFMapView) -> Void)?

        override func layoutSubviews() {
            super.layoutSubviews()
            onLayout?(mapView)
        }

        override func didMoveToWindow() {
            super.didMoveToWindow()
            onLayout?(mapView)
        }
    }
}

private struct FixedRadiusOverlay: View {
    var body: some View {
        ZStack {
            Circle()
                .fill(PicselColor.radiusGreen.opacity(0.09))
                .overlay {
                    Circle().stroke(PicselColor.radiusBorder, lineWidth: 1.5)
                }
                .frame(
                    width: HomeMapStyle.radiusCircleDiameter,
                    height: HomeMapStyle.radiusCircleDiameter
                )

            Circle()
                .fill(.white)
                .overlay {
                    Circle().stroke(PicselColor.radiusGreen, lineWidth: 1)
                }
                .frame(width: 21, height: 21)

            Circle()
                .fill(PicselColor.radiusGreen)
                .frame(width: 13, height: 13)
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

private enum HomeMapStyle {
    static let radiusCircleDiameter: CGFloat = 270
    static let minimumCameraRadiusMeters: CLLocationDistance = 1_000
    static let fallbackPaddingInsets = UIEdgeInsets(top: 24, left: 24, bottom: 24, right: 24)

    /// NMapsMap 3.24.0은 Style Editor의 배포 버전을 customStyleId로 불러옵니다.
    /// 현재 배포 버전은 20260917002003이며, SDK에는 버전을 별도로 전달하는 API가 없습니다.
    static let customStyleID = "65f87fe6-6f0b-4fa1-a26a-c3f9a4ced440"
}
