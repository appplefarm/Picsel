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

    func makeUIView(context: Context) -> NMFNaverMapView {
        let naverMapView = NMFNaverMapView(frame: .zero)
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

        context.coordinator.previousCoordinate = coordinate
        context.coordinator.previousRadiusMeters = radiusMeters
        context.coordinator.previousIsValidOrigin = isValidOrigin

        // makeUIView 시점에는 뷰 크기가 0일 수 있어 레이아웃 이후 반경을 맞춥니다.
        DispatchQueue.main.async {
            applyCamera(to: mapView, animated: false)
        }

        return naverMapView
    }

    func updateUIView(_ naverMapView: NMFNaverMapView, context: Context) {
        let coordinator = context.coordinator
        let radiusChanged = coordinator.previousRadiusMeters != radiusMeters
        let coordinateChanged = coordinator.previousCoordinate.map {
            $0.latitude != coordinate.latitude || $0.longitude != coordinate.longitude
        } ?? true
        let isValidOriginChanged = coordinator.previousIsValidOrigin != isValidOrigin

        guard radiusChanged || coordinateChanged || isValidOriginChanged else { return }

        // Slider를 움직일 때는 애니메이션을 누적하지 않고 현재 반경과 즉시 동기화합니다.
        applyCamera(
            to: naverMapView.mapView,
            animated: (coordinateChanged || isValidOriginChanged) && !radiusChanged
        )

        coordinator.previousCoordinate = coordinate
        coordinator.previousRadiusMeters = radiusMeters
        coordinator.previousIsValidOrigin = isValidOrigin
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
        var previousCoordinate: CLLocationCoordinate2D?
        var previousRadiusMeters: CLLocationDistance?
        var previousIsValidOrigin: Bool?
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
