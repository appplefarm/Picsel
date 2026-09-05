//
//  RouteMapView.swift
//  Picsel
//
//  Created by kosoobin on 9/6/26.
//

import CoreLocation
import NMapsMap
import SwiftUI

/// 경로 화면의 지도입니다.
///
/// 홈 화면은 Google 지도를 쓰지만, Google은 국내에서 자동차 길찾기를 제공하지 않아
/// 경로 화면만 네이버 지도로 그립니다. 경로 데이터와 지도를 같은 업체로 맞추면
/// 좌표가 어긋나지 않고 약관 문제도 없습니다.
struct RouteMapView: UIViewRepresentable {

    /// 지도에 모두 담기도록 맞출 지점들입니다. (출발지 · 경유지 · 목적지)
    let coordinates: [CLLocationCoordinate2D]

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
        let signature = Self.signature(of: coordinates)

        // 같은 좌표로 반복 호출될 때 카메라가 계속 움직이지 않도록 막습니다.
        guard context.coordinator.lastSignature != signature else { return }
        context.coordinator.lastSignature = signature

        moveCamera(of: mapView.mapView)
    }

    private func moveCamera(of mapView: NMFMapView) {
        let points = coordinates.map { NMGLatLng(lat: $0.latitude, lng: $0.longitude) }

        guard let first = points.first else { return }

        guard points.count > 1 else {
            let update = NMFCameraUpdate(scrollTo: first, zoomTo: MapStyle.singlePointZoom)
            mapView.moveCamera(update)
            return
        }

        let latitudes = points.map(\.lat)
        let longitudes = points.map(\.lng)

        let bounds = NMGLatLngBounds(
            southWest: NMGLatLng(lat: latitudes.min()!, lng: longitudes.min()!),
            northEast: NMGLatLng(lat: latitudes.max()!, lng: longitudes.max()!)
        )

        let update = NMFCameraUpdate(fit: bounds, padding: MapStyle.fitPadding)
        mapView.moveCamera(update)
    }

    /// CLLocationCoordinate2D는 Equatable이 아니라 비교용 문자열을 만들어 씁니다.
    private static func signature(of coordinates: [CLLocationCoordinate2D]) -> String {
        coordinates
            .map { "\($0.latitude),\($0.longitude)" }
            .joined(separator: "|")
    }

    final class Coordinator {
        var lastSignature: String?
    }
}

private enum MapStyle {
    /// 지점이 하나뿐일 때 사용할 줌 레벨입니다.
    static let singlePointZoom: Double = 13
    /// 경로가 지도 가장자리에 붙지 않도록 주는 여백입니다.
    static let fitPadding: CGFloat = 40
}
