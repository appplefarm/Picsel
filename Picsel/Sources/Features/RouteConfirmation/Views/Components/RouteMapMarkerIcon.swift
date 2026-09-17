//
//  RouteMapMarkerIcon.swift
//  Picsel
//
//  Created by kosoobin on 9/14/26.
//

import NMapsMap
import SwiftUI
import UIKit

/// 경로 지도에 세울 마커 아이콘을 그립니다.
///
/// 네이버 지도의 기본 마커는 큼직한 핀이라 장소가 가까이 붙어 있으면 지도를 덮어 버립니다.
/// 종류만 구분되는 작은 원으로 대신합니다.
@MainActor
enum RouteMapMarkerIcon {

    /// 마커는 다시 그릴 때마다 만들어지므로 이미지는 한 번만 그려 재사용합니다.
    private static var cache: [RouteMapMarker.Kind: NMFOverlayImage] = [:]

    static func image(for kind: RouteMapMarker.Kind) -> NMFOverlayImage {
        if let cached = cache[kind] { return cached }

        let image = NMFOverlayImage(image: draw(kind))
        cache[kind] = image
        return image
    }

    // MARK: - 그리기

    /// 목록 타임라인의 점(RouteStopDot)과 똑같은 모양을 그립니다.
    ///
    /// 크기·색·테두리·가운데 점은 모두 RouteMarkerStyle에서 가져옵니다.
    /// 지도에만 있는 것은 바깥에 두르는 흰 후광 하나뿐입니다.
    private static func draw(_ kind: RouteMapMarker.Kind) -> UIImage {
        let diameter = RouteMarkerStyle.diameter(for: kind)
        let padding = Metric.shadowPadding

        let canvasSize = CGSize(
            width: diameter + padding * 2,
            height: diameter + padding * 2
        )

        return UIGraphicsImageRenderer(size: canvasSize).image { context in
            let cgContext = context.cgContext
            let body = CGRect(
                x: padding,
                y: padding,
                width: diameter,
                height: diameter
            )

            // 1. 흰 후광. 지름 바깥으로 두르기 때문에 안쪽 초록을 깎지 않습니다.
            cgContext.setShadow(
                offset: .zero,
                blur: 3,
                color: UIColor.black.withAlphaComponent(0.22).cgColor
            )
            cgContext.setFillColor(UIColor.white.cgColor)

            // 그림자는 바깥 후광에만 주고 나머지는 깔끔하게 그립니다.
            cgContext.setShadow(offset: .zero, blur: 0, color: nil)

            // 2. 본체를 채웁니다.
            cgContext.setFillColor(UIColor(RouteMarkerStyle.fill(for: kind)).cgColor)
            cgContext.fillEllipse(in: body)

            // 3. 안쪽 테두리(경유지의 초록 테두리)를 두릅니다.
            //    stroke는 선의 절반이 바깥으로 나가므로 절반만큼 안으로 밀어 그립니다.
            if let stroke = RouteMarkerStyle.stroke(for: kind) {
                cgContext.setStrokeColor(UIColor(stroke.color).cgColor)
                cgContext.setLineWidth(stroke.width)
                cgContext.strokeEllipse(in: body.insetBy(dx: stroke.width / 2, dy: stroke.width / 2))
            }

            // 4. 목적지 가운데를 비웁니다.
            if let innerDotDiameter = RouteMarkerStyle.innerDotDiameter(for: kind) {
                let inset = (diameter - innerDotDiameter) / 2
                cgContext.setFillColor(UIColor.white.cgColor)
                cgContext.fillEllipse(in: body.insetBy(dx: inset, dy: inset))
            }
        }
    }

    private enum Metric {
        static let shadowPadding: CGFloat = 3
    }
}
