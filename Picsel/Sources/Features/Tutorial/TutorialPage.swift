//
//  TutorialPage.swift
//  Picsel
//

import Foundation

/// 튜토리얼 화면은 레이아웃을 공유하고 문구만 이 데이터로 교체합니다.
struct TutorialPage: Identifiable, Hashable {
    let id: String
    let description: String
    let highlightedText: String
    let trailingText: String
    let buttonTitle: String
}

extension TutorialPage {
    /// Figma `튜토리얼 6` (node-id: 2703:11458)
    static let radiusDiscovery = TutorialPage(
        id: "radius-discovery",
        description: "여행할 수 있는 범위를 정하면 그 안의",
        highlightedText: "새로운 풍경",
        trailingText: "을 만나볼 수 있어요",
        buttonTitle: "계속하기"
    )

    static let defaultPages: [TutorialPage] = [
        .radiusDiscovery
    ]
}
