//
//  PicselColor.swift
//  Picsel
//
//  Created by kosoobin on 9/6/26.
//

import SwiftUI

/// 하이파이 시안에서 쓰는 색입니다.
/// 화면마다 hex를 흩어 놓지 않도록 여기에 모아 둡니다.
enum PicselColor {
    /// 주요 액션 버튼 (길찾기)
    static let actionGreen = Color(hex: 0x48C98B)
    /// 큰 완료 버튼
    static let primaryGreen = Color(hex: 0x28985E)
    /// 큰 완료 버튼 위의 글자
    static let onPrimary = Color(hex: 0xECFDF8)
    /// 장소 이름
    static let placeName = Color(hex: 0x141A17)
    /// 지역 표기
    static let locationLabel = Color(hex: 0x178C5E)
    /// 화면 설명 문구
    static let subtitle = Color(hex: 0x1F1F1F)
    /// 타임라인 점선
    static let timelineLine = Color(hex: 0x48C98B).opacity(0.45)
    /// 카드 그림자
    static let cardShadow = Color.black.opacity(0.1)
}

extension Color {
    /// 0xRRGGBB 형태의 정수로 색을 만듭니다.
    init(hex: UInt32) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            opacity: 1
        )
    }
}
