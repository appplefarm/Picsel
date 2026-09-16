//
//  RouteMapView.swift
//  Picsel
//
//  Created by kosoobin on 9/6/26.
//

import CoreLocation
import Foundation
import NMapsMap
import SwiftUI

/// 지도에 세울 장소 표시입니다.
struct RouteMapMarker: Equatable {

    /// 경로에서 이 장소가 맡은 역할입니다. 마커 모양과 이름 표시 여부를 정합니다.
    enum Kind: Hashable {
        case origin
        case waypoint
        case destination
    }

    let coordinate: CLLocationCoordinate2D
    let title: String
    let kind: Kind

    static func == (lhs: RouteMapMarker, rhs: RouteMapMarker) -> Bool {
        lhs.title == rhs.title
            && lhs.kind == rhs.kind
            && lhs.coordinate.latitude == rhs.coordinate.latitude
            && lhs.coordinate.longitude == rhs.coordinate.longitude
    }
}

/// 경로 화면의 지도입니다.
///
/// 홈 화면은 Google 지도를 쓰지만, Google은 국내에서 자동차 길찾기를 제공하지 않아
/// 경로 화면만 네이버 지도로 그립니다. 경로 데이터와 지도를 같은 업체로 맞추면
/// 좌표가 어긋나지 않고 약관 문제도 없습니다.
struct RouteMapView: UIViewRepresentable {

    /// 경로 선입니다. 계산 전이면 비어 있습니다.
    let path: [CLLocationCoordinate2D]
    /// 출발지 · 경유지 · 목적지 표시입니다.
    let markers: [RouteMapMarker]

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeUIView(context: Context) -> NMFNaverMapView {
        let mapView = NMFNaverMapView(frame: .zero)

        // 경로를 한눈에 보는 화면이라 조작 UI는 최소로 둡니다.
        mapView.showLocationButton = false
        mapView.showZoomControls = false
        mapView.showCompass = false
        mapView.showScaleBar = false
        mapView.showIndoorLevelPicker = false

        return mapView
    }

    func updateUIView(_ mapView: NMFNaverMapView, context: Context) {
        let signature = makeSignature()

        // 같은 내용으로 반복 호출될 때 오버레이를 다시 그리지 않도록 막습니다.
        guard context.coordinator.lastSignature != signature else { return }
        context.coordinator.lastSignature = signature

        context.coordinator.clearOverlays()
        drawPath(on: mapView.mapView, coordinator: context.coordinator)
        drawMarkers(on: mapView.mapView, coordinator: context.coordinator)
        moveCamera(of: mapView.mapView)
    }

    /// SwiftUI가 뷰를 걷어낼 때 오버레이도 함께 정리합니다.
    static func dismantleUIView(_ mapView: NMFNaverMapView, coordinator: Coordinator) {
        coordinator.clearOverlays()
    }

    // MARK: - 그리기

    private func drawPath(on mapView: NMFMapView, coordinator: Coordinator) {
        // NMFPath는 점이 2개 이상이어야 합니다.
        guard path.count >= 2 else { return }

        let overlay = NMFPath()
        overlay.path = NMGLineString(points: path.map(Self.latLng(from:)))
        overlay.width = MapStyle.pathWidth
        overlay.outlineWidth = MapStyle.pathOutlineWidth
        overlay.color = MapStyle.pathColor
        overlay.outlineColor = MapStyle.pathOutlineColor
        overlay.mapView = mapView

        coordinator.pathOverlay = overlay
    }

    private func drawMarkers(on mapView: NMFMapView, coordinator: Coordinator) {
        coordinator.markerOverlays = markers.map { item in
            let marker = NMFMarker()
            marker.position = Self.latLng(from: snapped(item.coordinate))
            marker.iconImage = RouteMapMarkerIcon.image(for: item.kind)

            // 기본 마커는 핀이라 아래 끝이 기준점입니다.
            // 원은 가운데가 실제 좌표에 놓여야 합니다.
            marker.anchor = MapStyle.circleAnchor

            marker.captionText = item.title
            marker.captionTextSize = MapStyle.captionTextSize(for: item.kind)
            marker.captionColor = MapStyle.captionColor
            marker.captionHaloColor = MapStyle.captionHaloColor
            // 글자가 겹치면 덜 중요한 쪽부터 숨습니다. 순서는 zIndex를 따릅니다.
            marker.isHideCollidedCaptions = true

            marker.zIndex = MapStyle.zIndex(for: item.kind)
            marker.mapView = mapView
            return marker
        }
    }

    private func moveCamera(of mapView: NMFMapView) {
        // 경로가 있으면 경로 전체를, 없으면 지점들만 담습니다.
        let targets = path.isEmpty ? markers.map(\.coordinate) : path
        let points = targets.map(Self.latLng(from:))

        guard let first = points.first else { return }

        guard points.count > 1 else {
            mapView.moveCamera(NMFCameraUpdate(scrollTo: first, zoomTo: MapStyle.singlePointZoom))
            return
        }

        let latitudes = points.map(\.lat)
        let longitudes = points.map(\.lng)

        let bounds = NMGLatLngBounds(
            southWest: NMGLatLng(lat: latitudes.min()!, lng: longitudes.min()!),
            northEast: NMGLatLng(lat: latitudes.max()!, lng: longitudes.max()!)
        )

        mapView.moveCamera(NMFCameraUpdate(fit: bounds, padding: MapStyle.fitPadding))
    }

    // MARK: - 마커 위치 보정

    /// 마커를 경로선 위에서 가장 가까운 점으로 옮깁니다.
    ///
    /// 장소 좌표는 관광 API가 준 건물 위치이고 경로선은 길찾기 업체가 도로에 맞춰 준 좌표라,
    /// 그대로 두면 지도를 확대했을 때 마커가 경로선 옆에 따로 떠 있습니다.
    /// 이 화면은 장소를 찾는 지도가 아니라 경로를 미리 보는 지도라 붙여 놓는 편이 읽기 좋습니다.
    private func snapped(_ coordinate: CLLocationCoordinate2D) -> CLLocationCoordinate2D {
        guard !path.isEmpty else { return coordinate }

        var nearest = coordinate
        var nearestDistance = Double.greatestFiniteMagnitude

        // 위도 1도의 길이는 어디서나 비슷하지만 경도는 위도에 따라 줄어듭니다.
        // 한 마커를 보는 동안에는 위도가 거의 같으므로 보정값을 한 번만 구해 씁니다.
        let longitudeScale = cos(coordinate.latitude * .pi / 180)

        for point in path {
            let latitudeMeters = (point.latitude - coordinate.latitude) * Self.metersPerDegree
            let longitudeMeters =
                (point.longitude - coordinate.longitude) * Self.metersPerDegree * longitudeScale
            let distance = latitudeMeters * latitudeMeters + longitudeMeters * longitudeMeters

            if distance < nearestDistance {
                nearestDistance = distance
                nearest = point
            }
        }

        // 경로에서 한참 떨어진 장소까지 끌어다 붙이면 위치를 속이는 셈입니다.
        // 그런 장소는 원래 자리에 그대로 둡니다.
        let limit = Self.maximumSnapDistanceMeters
        guard nearestDistance <= limit * limit else { return coordinate }

        return nearest
    }

    /// 마커를 경로선으로 당겨 붙일 수 있는 최대 거리(m)입니다.
    private static let maximumSnapDistanceMeters: Double = 500
    /// 위도 1도의 대략적인 길이(m)입니다.
    private static let metersPerDegree: Double = 111_320

    // MARK: - 보조

    private static func latLng(from coordinate: CLLocationCoordinate2D) -> NMGLatLng {
        NMGLatLng(lat: coordinate.latitude, lng: coordinate.longitude)
    }

    /// CLLocationCoordinate2D는 Equatable이 아니라 비교용 문자열을 만들어 씁니다.
    private func makeSignature() -> String {
        let markerPart = markers
            .map { "\($0.title)@\($0.coordinate.latitude),\($0.coordinate.longitude)#\($0.kind)" }
            .joined(separator: "|")
        // 경로는 좌표가 수천 개라 전부 비교하지 않고 개수와 양 끝만 봅니다.
        let pathPart = "\(path.count)-\(path.first?.latitude ?? 0)-\(path.last?.latitude ?? 0)"
        return markerPart + "#" + pathPart
    }

    final class Coordinator {
        var lastSignature: String?
        var pathOverlay: NMFPath?
        var markerOverlays: [NMFMarker] = []

        func clearOverlays() {
            pathOverlay?.mapView = nil
            pathOverlay = nil
            markerOverlays.forEach { $0.mapView = nil }
            markerOverlays = []
        }
    }
}

private enum MapStyle {
    static let singlePointZoom: Double = 13
    static let fitPadding: CGFloat = 40

    // 경로 선
    static let pathWidth: CGFloat = 5
    static let pathOutlineWidth: CGFloat = 1.5
    static let pathColor = UIColor(PicselColor.actionGreen)
    /// 지도의 도로·건물 위에서 선이 묻히지 않도록 흰 테두리를 둡니다.
    static let pathOutlineColor = UIColor.white
    static let captionColor = UIColor(PicselColor.placeName)

    // 마커
    /// 원형 아이콘은 가운데가 기준점입니다.
    static let circleAnchor = CGPoint(x: 0.5, y: 0.5)
    static let captionHaloColor = UIColor.white

    /// 경유지 이름은 한 단계 작게 두어 출발지·목적지가 먼저 읽히게 합니다.
    static func captionTextSize(for kind: RouteMapMarker.Kind) -> CGFloat {
        kind == .waypoint ? 11 : 12
    }

//    static func captionColor(for kind: RouteMapMarker.Kind) -> UIColor {
//        kind == .waypoint
//            ? UIColor(PicselColor.travelMinutes)
//            : UIColor(PicselColor.placeName)
//    }

    /// 목적지가 경유지에 가려지지 않도록 순서를 정합니다.
    static func zIndex(for kind: RouteMapMarker.Kind) -> Int {
        switch kind {
        case .waypoint: 0
        case .origin: 1
        case .destination: 2
        }
    }
}

#if DEBUG
#Preview("경로 지도") {
    let stops: [(String, Double, Double, RouteMapMarker.Kind)] = [
        ("호미곶 해맞이광장", 36.076_2, 129.567_3, .origin),
        ("구룡포 일본인가옥거리", 35.989_6, 129.554_9, .waypoint),
        ("월포해수욕장", 36.157_8, 129.396_1, .waypoint),
        ("이가리 닻 전망대", 36.187_992, 129.379_005, .destination)
    ]

    return RouteMapView(
        // 실제 경로 대신 지점을 직선으로 이은 선입니다.
        path: stops.map { CLLocationCoordinate2D(latitude: $0.1, longitude: $0.2) },
        markers: stops.map {
            RouteMapMarker(
                coordinate: CLLocationCoordinate2D(latitude: $0.1, longitude: $0.2),
                title: $0.0,
                kind: $0.3
            )
        }
    )
    .aspectRatio(342 / 286, contentMode: .fit)
    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    .padding()
}
#endif
