//
//  PicselFont.swift
//  Picsel
//
//  Created by kosoobin on 9/14/26.
//

import SwiftUI

/// 디자이너가 준 타이포그래피 스케일입니다.
///
/// 아직 프리텐다드를 번들에 넣지 않아 시스템 폰트로 대신합니다.
/// 화면마다 `.font(.system(size:weight:))`를 흩어 두면 나중에 교체할 때 전부 찾아야 하므로,
/// 반드시 이 타입을 거쳐 쓰고 교체는 아래 `pretendard(size:weight:)` 한 곳만 고칩니다.
enum PicselFont {

    // MARK: - Title
    /// Bold 28
    static let title01 = pretendard(size: 28, weight: .bold)
    /// SemiBold 24 — 화면 제목
    static let title02 = pretendard(size: 24, weight: .semibold)
    /// SemiBold 20
    static let title03 = pretendard(size: 20, weight: .semibold)

    // MARK: - Subtitle
    /// Regular 16
    static let subtitle01 = pretendard(size: 16, weight: .regular)

    // MARK: - Label
    /// SemiBold 16 — 버튼 글자
    static let label01 = pretendard(size: 16, weight: .semibold)
    /// Medium 15 — 입력 칸 제목
    static let label02 = pretendard(size: 15, weight: .medium)
    /// SemiBold 13
    static let label03 = pretendard(size: 13, weight: .semibold)

    // MARK: - Body
    /// Regular 14 — 화면 설명
    static let body01 = pretendard(size: 14, weight: .regular)
    /// Regular 13 — 입력 값
    static let body02 = pretendard(size: 13, weight: .regular)

    // MARK: - Caption
    /// Regular 12 — 보조 안내, 글자 수
    static let caption01 = pretendard(size: 12, weight: .regular)

    /// TODO: 프리텐다드를 번들에 넣은 뒤
    ///       `.custom("Pretendard-\(weight)", size: size)` 형태로 바꿉니다.
    ///       이 함수만 고치면 앱 전체 폰트가 한 번에 바뀝니다.
    private static func pretendard(size: CGFloat, weight: Font.Weight) -> Font {
        .system(size: size, weight: weight)
    }
}
