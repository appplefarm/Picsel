//
//  TutorialPage.swift
//  Picsel
//

import SwiftUI

/// 세 페이지가 같은 레이아웃과 영상 플레이어를 공유합니다.
struct TutorialPage: Identifiable, Hashable {
    let id: String
    let description: String
    let highlightedText: String
    let trailingText: String
    let buttonTitle: String

    var videoName: String { id }
    var posterName: String { "Tutorial-\(id)" }

    var background: Color {
        switch id {
        case "radius-planning": Color(hex: 0xF2F2F2)
        case "photo-explore": Color(hex: 0xE6F3F2)
        default: PicselColor.surface
        }
    }

    /// Figma의 402 × 874 프레임을 기준으로 영상의 확대 및 잘림 영역을 지정합니다.
    var videoFrame: CGRect {
        switch id {
        case "radius-planning":
            // 제공된 영상은 이미 세로로 잘려 있습니다. 시안의 노출 높이(677 - 82)에
            // 원본 비율을 맞춰 지도 중심과 슬라이더가 다시 잘리지 않게 합니다.
            let width = 595.0 * 866 / 1206
            return CGRect(x: (402 - width) / 2, y: 0, width: width, height: 595)
        case "photo-explore":
            return CGRect(x: 0, y: 0, width: 402, height: 875)
        default:
            return CGRect(x: -71, y: 4, width: 514, height: 662)
        }
    }

    var gradientHeightRatio: CGFloat { (id == "radius-planning" ? 279.0 : 331.0) / 874 }
    var continueDelay: TimeInterval { id == "pixel" ? 1 : 2.5 }
}

extension TutorialPage {
    /// Figma 튜토리얼 4 / iPhone 17 - 73 / 튜토리얼 5 순서입니다.
    static let radiusDiscovery = TutorialPage(
        id: "radius-planning",
        description: "여행할 수 있는 범위를 정하면 그 안의",
        highlightedText: "새로운 풍경",
        trailingText: "을 만나볼 수 있어요",
        buttonTitle: "계속하기"
    )

    static let photoExplore = TutorialPage(
        id: "photo-explore",
        description: "사진 수상작으로 우리나라의 아름다운 풍경을",
        highlightedText: "공간 갤러리에서",
        trailingText: "자유롭게 둘러보세요",
        buttonTitle: "계속하기"
    )

    static let pixelMap = TutorialPage(
        id: "pixel",
        description: "여행을 마칠 때마다 하나의 픽셀로",
        highlightedText: "지도가 채워지고",
        trailingText: "그날의 이야기를 기록해요",
        buttonTitle: "계속하기"
    )

    static let defaultPages: [TutorialPage] = [
        .radiusDiscovery, .photoExplore, .pixelMap
    ]
}
