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

    /// 크기와 색은 목록 타임라인과 같은 정의(RouteMarkerStyle)에서 가져옵니다.
    /// 지도에서만 흰 테두리가 배경과 마커를 떼어내는 역할을 합니다.
    private static func draw(_ kind: RouteMapMarker.Kind) -> UIImage {
        circle(
            diameter: RouteMarkerStyle.diameter(for: kind),
            fill: UIColor(RouteMarkerStyle.fill(for: kind)),
            border: UIColor(RouteMarkerStyle.border(for: kind)),
            borderWidth: RouteMarkerStyle.borderWidth(for: kind),
            innerDotDiameter: RouteMarkerStyle.innerDotDiameter(for: kind)
        )
    }

    /// 테두리는 stroke 대신 큰 원 위에 작은 원을 덮어 그립니다.
    /// stroke는 선의 절반이 바깥으로 나가 크기를 가늠하기 어렵습니다.
    private static func circle(
        diameter: CGFloat,
        fill: UIColor,
        border: UIColor,
        borderWidth: CGFloat,
        innerDotDiameter: CGFloat? = nil
    ) -> UIImage {
        // 그림자가 잘리지 않도록 여백을 둡니다.
        let padding = Metric.shadowPadding
        let canvasSize = CGSize(
            width: diameter + padding * 2,
            height: diameter + padding * 2
        )

        return UIGraphicsImageRenderer(size: canvasSize).image { context in
            let cgContext = context.cgContext
            let rect = CGRect(
                x: padding,
                y: padding,
                width: diameter,
                height: diameter
            )

            cgContext.setShadow(
                offset: .zero,
                blur: 3,
                color: UIColor.black.withAlphaComponent(0.22).cgColor
            )
            cgContext.setFillColor(border.cgColor)
            cgContext.fillEllipse(in: rect)

            // 그림자는 바깥 테두리에만 주고 나머지는 깔끔하게 그립니다.
            cgContext.setShadow(offset: .zero, blur: 0, color: nil)

            cgContext.setFillColor(fill.cgColor)
            cgContext.fillEllipse(in: rect.insetBy(dx: borderWidth, dy: borderWidth))

            guard let innerDotDiameter else { return }

            let inset = (diameter - innerDotDiameter) / 2
            cgContext.setFillColor(UIColor.white.cgColor)
            cgContext.fillEllipse(in: rect.insetBy(dx: inset, dy: inset))
        }
    }

    private enum Metric {
        static let shadowPadding: CGFloat = 3
    }
}
