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
    /// 홈 화면 배경
    static let homeBackground = Color(hex: 0xF5F6F5)
    /// 홈 화면의 기본 글자
    static let homeText = Color(hex: 0x202722)
    /// 홈 CTA 배경
    static let homeCTA = Color(hex: 0x00725D)
    /// 지도 반경 원과 슬라이더 강조색
    static let radiusGreen = Color(hex: 0x2C8C74)
    /// 지도 반경 원 테두리
    static let radiusBorder = Color(hex: 0x009C7B)
    /// 슬라이더 양끝 아이콘
    static let sliderIcon = Color(hex: 0x7C8580)
    /// 슬라이더 눈금
    static let sliderTick = Color(hex: 0xCED3D0)
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
    /// 경로 목록 행 배경
    static let rowBackground = Color(hex: 0xFAFBFA)

    /// 네비게이션 앱 선택 화면
    static let navigationDescription = Color(hex: 0x748686)
    static let navigationSelectedBackground = Color(hex: 0xEBFAF5)
    static let navigationSelectedBorder = Color(hex: 0x37B28F)
    static let navigationBorder = Color(hex: 0xE3E8E0)
    static let navigationButtonHighlight = Color(hex: 0x149873)

    /// 설정 화면
    static let settingsBackground = Color(hex: 0xDEE7E2)
    static let settingsSectionTitle = Color(hex: 0x114D36)
    static let settingsSecondaryText = Color(hex: 0x5D6B63)
    static let settingsIcon = Color(hex: 0x31B98C)
    static let settingsIconBackground = Color(hex: 0xE6F7EE)
    static let settingsBorder = Color(hex: 0xDAE6DE)

    // MARK: - 디자이너 컬러 라이브러리
    // Figma 변수 이름을 그대로 옮겼습니다. 새 화면은 아래 토큰을 우선 씁니다.

    /// 화면 기본 배경 (Background/Warm White)
    static let backgroundWarmWhite = Color(hex: 0xF5F6F5)
    /// 카드·입력 칸 배경
    static let surface = Color(hex: 0xFFFFFF)
    /// 브랜드 CTA (Brand/Brand Color(CTA))
    static let brandCTA = Color(hex: 0x00725D)

    static let textPrimary = Color(hex: 0x1F1F1F)
    static let textSecondary = Color(hex: 0x5D6B63)
    static let textTertiary = Color(hex: 0x718076)
    /// 보조 안내 문구
    static let textHelper = Color(hex: 0x858585)
    static let textDisabled = Color(hex: 0xBCBCBC)

    static let borderBrandSubtle = Color(hex: 0xBEDBD4)
    static let borderDefault = Color(hex: 0xDAE6DE)

    // MARK: - 기록 작성 화면
    /// 제목·내용 입력 칸 테두리
    static let inputBorder = Color(hex: 0xF3F3F3)
    /// 입력 칸 placeholder
    static let inputPlaceholder = Color(hex: 0xDBDBDB)
    /// 사진 추가 버튼 배경
    static let photoAddBackground = Color(hex: 0xF1F9F7)
    /// 사진 추가 버튼의 + 기호
    static let photoAddIcon = Color(hex: 0xABABAB)

    // MARK: - 보조 버튼 (픽셀 획득 화면 "홈으로")
    static let secondaryButtonBackground = Color(hex: 0xFBFDFD)
    static let secondaryButtonBorder = Color(hex: 0xE4F1EB)
    static let secondaryButtonText = Color(hex: 0xA4B8B0)

    /// 픽셀맵에서 아직 가보지 않은 칸
    static let pixelLockedFill = Color(hex: 0xEFF1EF)
    static let pixelLockedStroke = Color(hex: 0xD5DAD7)
    /// 경로 목록 행 테두리
    static let rowBorder = Color(hex: 0xECF2EF)
    /// 경로 요약 문구
    static let summaryText = Color(hex: 0x868686)
    /// 편집 버튼 글자
    static let editLabel = Color(hex: 0x738376)
    /// 구간 이동 시간
    static let travelMinutes = Color(hex: 0x858585)

    /// 사진 탐색 로딩 화면
    static let photoLoadingWaveTint = Color(hex: 0x43C994)
    static let photoLoadingText = Color(hex: 0x639580)

    // MARK: - 여행 진행 중 홈
    static let tripHomeBackground = Color(hex: 0x121A16)
    static let tripHomeGlow = Color(hex: 0x00866D)
    static let tripHomeTitle = Color(hex: 0xFBFFFD)
    static let tripHomeSubtitle = Color(hex: 0xE6F7EE)
    static let tripHomeButtonStart = Color(hex: 0x37B287)
    static let tripHomeButtonEnd = Color(hex: 0x7ED2B5)
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
