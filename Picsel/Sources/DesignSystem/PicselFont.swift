//
//  PicselFont.swift
//  Picsel
//
//  Created by kosoobin on 9/14/26.
//

import SwiftUI

/// 디자이너가 준 타이포그래피 스케일입니다.
///
/// 번들에 포함된 Pretendard를 사용하며 각 토큰은 Dynamic Type에 대응합니다.
enum PicselFont {

    // MARK: - Title
    /// Bold 28
    static let title01 = pretendard("Bold", size: 28, relativeTo: .title)
    /// SemiBold 24 — 화면 제목
    static let title02 = pretendard("SemiBold", size: 24, relativeTo: .title2)
    /// SemiBold 20
    static let title03 = pretendard("SemiBold", size: 20, relativeTo: .title3)

    // MARK: - Subtitle
    /// Regular 16
    static let subtitle01 = pretendard("Regular", size: 16, relativeTo: .callout)

    // MARK: - Label
    /// SemiBold 16 — 버튼 글자
    static let label01 = pretendard("SemiBold", size: 16, relativeTo: .callout)
    /// Medium 15 — 입력 칸 제목
    static let label02 = pretendard("Medium", size: 15, relativeTo: .subheadline)
    /// SemiBold 13
    static let label03 = pretendard("SemiBold", size: 13, relativeTo: .footnote)

    // MARK: - Body
    /// Regular 14 — 화면 설명
    static let body01 = pretendard("Regular", size: 14, relativeTo: .subheadline)
    /// Regular 13 — 입력 값
    static let body02 = pretendard("Regular", size: 13, relativeTo: .footnote)

    // MARK: - Caption
    /// Regular 12 — 보조 안내, 글자 수
    static let caption01 = pretendard("Regular", size: 12, relativeTo: .caption)

    private static func pretendard(
        _ weight: String,
        size: CGFloat,
        relativeTo textStyle: Font.TextStyle
    ) -> Font {
        .custom("Pretendard-\(weight)", size: size, relativeTo: textStyle)
    }
}
