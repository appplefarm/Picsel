import CoreLocation
import GoogleMaps
import SwiftUI

/// Google 지도 자체는 카메라만 담당합니다.
/// 반경 원과 현재 위치 표시는 SwiftUI 오버레이이므로 줌과 관계없이 고정됩니다.
struct GoogleMapView: View {
    let coordinate: CLLocationCoordinate2D
    let radiusMeters: Double

    var body: some View {
        ZStack {
            GoogleMapRepresentable(
                coordinate: coordinate,
                radiusMeters: radiusMeters,
                circleDiameterPoints: HomeMapStyle.radiusCircleDiameter
            )

            FixedRadiusOverlay()
        }
    }
}

private struct GoogleMapRepresentable: UIViewRepresentable {
    let coordinate: CLLocationCoordinate2D
    let radiusMeters: Double
    let circleDiameterPoints: CGFloat

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeUIView(context: Context) -> GMSMapView {
        let camera = GMSCameraPosition.camera(
            withTarget: coordinate,
            zoom: HomeMapStyle.initialZoom
        )
        let mapView = GMSMapView(frame: .zero, camera: camera)
        // 반경 원의 중심과 실제 현재 위치가 어긋나지 않도록
        // 지도 카메라는 사용자가 직접 이동하지 못하게 고정합니다.
        // 확대/축소는 아래 Slider 값으로만 제어합니다.
        mapView.settings.scrollGestures = false
        mapView.settings.zoomGestures = false
        mapView.settings.rotateGestures = false
        mapView.settings.tiltGestures = false
        // 권한 승인 후 실제 기기 위치는 Google Maps의 파란 점 하나로 표시합니다.
        mapView.isMyLocationEnabled = true
        mapView.settings.myLocationButton = false

        context.coordinator.previousCoordinate = coordinate
        context.coordinator.previousRadiusMeters = radiusMeters

        // makeUIView 시점에는 뷰 크기가 아직 0일 수 있으므로 다음 run loop에서 적용합니다.
        DispatchQueue.main.async {
            applyCamera(to: mapView, animated: false)
        }
        return mapView
    }

    func updateUIView(_ mapView: GMSMapView, context: Context) {
        let coordinator = context.coordinator
        let radiusChanged = coordinator.previousRadiusMeters != radiusMeters
        let coordinateChanged = coordinator.previousCoordinate.map {
            $0.latitude != coordinate.latitude || $0.longitude != coordinate.longitude
        } ?? true

        guard radiusChanged || coordinateChanged else { return }

        // Slider 드래그 중 animate를 반복하면 애니메이션이 누적됩니다.
        // moveCamera를 사용해 현재 값과 지도를 즉시 동기화합니다.
        applyCamera(to: mapView, animated: coordinateChanged && !radiusChanged)
        coordinator.previousCoordinate = coordinate
        coordinator.previousRadiusMeters = radiusMeters
    }

    private func applyCamera(to mapView: GMSMapView, animated: Bool) {
        let zoom = zoomLevel(
            radiusMeters: radiusMeters,
            latitude: coordinate.latitude,
            circleDiameterPoints: circleDiameterPoints
        )
        let camera = GMSCameraPosition(
            target: coordinate,
            zoom: zoom,
            bearing: mapView.camera.bearing,
            viewingAngle: mapView.camera.viewingAngle
        )

        if animated {
            mapView.animate(to: camera)
        } else {
            mapView.moveCamera(GMSCameraUpdate.setCamera(camera))
        }
    }

    /// Google Maps의 줌 0 세계 너비(256pt)와 Web Mercator 배율을 이용합니다.
    /// Google Maps iOS 카메라는 논리 point 기준이므로 UIScreen.scale을 곱하지 않습니다.
    private func zoomLevel(
        radiusMeters: Double,
        latitude: CLLocationDegrees,
        circleDiameterPoints: CGFloat
    ) -> Float {
        let safeRadius = max(radiusMeters, HomeMapStyle.minimumCameraRadiusMeters)
        let diameterMeters = safeRadius * 2
        let latitudeRadians = latitude * .pi / 180
        let visibleWorldMeters = HomeMapStyle.earthCircumferenceMeters * cos(latitudeRadians)
        let zoom = log2(
            visibleWorldMeters * Double(circleDiameterPoints) /
            (HomeMapStyle.googleWorldWidthPoints * diameterMeters)
        )
        return Float(min(max(zoom, HomeMapStyle.minimumZoom), HomeMapStyle.maximumZoom))
    }

    final class Coordinator {
        var previousCoordinate: CLLocationCoordinate2D?
        var previousRadiusMeters: Double?
    }
}

private struct FixedRadiusOverlay: View {
    var body: some View {
        Circle()
            .fill(Color.black.opacity(0.10))
            .overlay {
                Circle().stroke(Color.black.opacity(0.38), lineWidth: 1)
            }
            .frame(
                width: HomeMapStyle.radiusCircleDiameter,
                height: HomeMapStyle.radiusCircleDiameter
            )
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

private enum HomeMapStyle {
    static let radiusCircleDiameter: CGFloat = 251
    static let initialZoom: Float = 8
    static let minimumZoom = 0.0
    static let maximumZoom = 21.0
    static let minimumCameraRadiusMeters = 1_000.0
    static let earthCircumferenceMeters = 40_075_016.686
    static let googleWorldWidthPoints = 256.0
}
