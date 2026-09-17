//
//  RouteStopDot.swift
//  Picsel
//
//  Created by kosoobin on 9/16/26.
//

import SwiftUI

/// 경로에서 맡은 역할에 따라 점의 크기와 색을 정합니다.
///
/// 지도 마커(RouteMapMarkerIcon)와 목록 타임라인(RouteStopRow)이 같은 값을 씁니다.
/// 두 곳에 따로 적어 두면 한쪽만 고쳤을 때 같은 장소가 화면마다 다르게 보입니다.
enum RouteMarkerStyle {

    /// 지름(pt). 목적지 > 출발지 > 경유지 순으로 중요도를 크기로 드러냅니다.
    static func diameter(for kind: RouteMapMarker.Kind) -> CGFloat {
        switch kind {
        case .origin: 15
        case .waypoint: 12
        case .destination: 18
        }
    }

    /// 안쪽을 채우는 색입니다.
    static func fill(for kind: RouteMapMarker.Kind) -> Color {
        switch kind {
        // 출발지: 아직 지나지 않았지만 분명한 시작점이라 꽉 채웁니다.
        case .origin: PicselColor.actionGreen
        // 경유지: 들르는 곳이라 속을 비워 가볍게 둡니다.
        case .waypoint: .white
        // 목적지: 가장 진한 색으로 끝점임을 드러냅니다.
        case .destination: PicselColor.primaryGreen
        }
    }

    /// 지름 안쪽에 두르는 테두리입니다. 경유지만 초록 테두리를 갖습니다.
    ///
    /// 안쪽에 그리므로 지름은 그대로 두고 채움 면적만 줄어듭니다.
    static func stroke(for kind: RouteMapMarker.Kind) -> (color: Color, width: CGFloat)? {
        kind == .waypoint ? (PicselColor.actionGreen, 2) : nil
    }

    /// 목적지 가운데를 비우는 흰 점의 지름입니다. 다른 역할에는 없습니다.
    static func innerDotDiameter(for kind: RouteMapMarker.Kind) -> CGFloat? {
        kind == .destination ? 7 : nil
    }
}

/// 목록 타임라인에 찍는 점입니다. 지도 마커와 같은 모양을 씁니다.
///
/// 지도 마커와 다른 점은 바깥의 흰 후광뿐입니다.
/// 목록은 바탕이 흰색이라 후광을 그려도 보이지 않으므로 생략합니다.
struct RouteStopDot: View {
    let kind: RouteMapMarker.Kind

    var body: some View {
        let diameter = RouteMarkerStyle.diameter(for: kind)

        Circle()
            .fill(RouteMarkerStyle.fill(for: kind))
            .overlay {
                if let stroke = RouteMarkerStyle.stroke(for: kind) {
                    Circle()
                        .strokeBorder(stroke.color, lineWidth: stroke.width)
                }
            }
            .overlay {
                if let innerDotDiameter = RouteMarkerStyle.innerDotDiameter(for: kind) {
                    Circle()
                        .fill(.white)
                        .frame(width: innerDotDiameter, height: innerDotDiameter)
                }
            }
            .frame(width: diameter, height: diameter)
            .accessibilityHidden(true)
    }
}

#if DEBUG
#Preview("경로 점") {
    HStack(spacing: 24) {
        ForEach([RouteMapMarker.Kind.origin, .waypoint, .destination], id: \.self) { kind in
            VStack(spacing: 8) {
                RouteStopDot(kind: kind)
                    // 목록에서 점이 놓이는 열 너비입니다.
                    .frame(width: 22, height: 22)

                Text(String(describing: kind))
                    .font(PicselFont.caption01)
                    .foregroundStyle(.secondary)
            }
        }
    }
    .padding(32)
}
#endif
