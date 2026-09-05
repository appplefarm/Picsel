//
//  RouteMapView.swift
//  Picsel
//
//  Created by kosoobin on 9/6/26.
//

import CoreLocation
import NMapsMap
import SwiftUI

/// 지도에 세울 장소 표시입니다.
struct RouteMapMarker: Equatable {
    let coordinate: CLLocationCoordinate2D
    let title: String
    let isDestination: Bool

    static func == (lhs: RouteMapMarker, rhs: RouteMapMarker) -> Bool {
        lhs.title == rhs.title
            && lhs.isDestination == rhs.isDestination
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
            marker.position = Self.latLng(from: item.coordinate)
            marker.captionText = item.title
            marker.captionTextSize = MapStyle.captionTextSize
            marker.iconTintColor = item.isDestination
                ? MapStyle.destinationTint
                : MapStyle.waypointTint
            // 목적지가 다른 마커에 가려지지 않도록 위로 올립니다.
            marker.zIndex = item.isDestination ? 1 : 0
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

    // MARK: - 보조

    private static func latLng(from coordinate: CLLocationCoordinate2D) -> NMGLatLng {
        NMGLatLng(lat: coordinate.latitude, lng: coordinate.longitude)
    }

    /// CLLocationCoordinate2D는 Equatable이 아니라 비교용 문자열을 만들어 씁니다.
    private func makeSignature() -> String {
        let markerPart = markers
            .map { "\($0.title)@\($0.coordinate.latitude),\($0.coordinate.longitude)" }
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
    static let pathWidth: CGFloat = 6
    static let pathOutlineWidth: CGFloat = 1
    static let pathColor = UIColor.label
    static let pathOutlineColor = UIColor.systemBackground
    static let captionTextSize: CGFloat = 11
    static let destinationTint = UIColor.label
    static let waypointTint = UIColor.systemGray2
}
