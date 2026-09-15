//
//  YearFilterChips.swift
//  Picsel
//
//  Created by kosoobin on 9/16/26.
//

import SwiftUI

/// 기록을 연도로 걸러 보는 칩 줄입니다.
///
/// 픽셀 히스토리(전국)와 픽셀 지역 상세가 같은 모양을 씁니다.
/// 기록이 있는 연도만 넘겨 주세요. 없는 연도를 눌러 빈 목록을 보게 되지 않도록요.
struct YearFilterChips: View {

    /// 최신순으로 정렬해서 넘깁니다.
    let years: [Int]

    /// nil이면 "전체"입니다. `showsAllOption`이 false면 nil이 되지 않습니다.
    @Binding var selection: Int?

    /// "전체" 칩을 앞에 둘지입니다. 지역 상세는 연도만 고릅니다.
    var showsAllOption: Bool = true

    var font: Font = PicselFont.body01

    var body: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 16) {
                if showsAllOption {
                    chip(label: "전체", isSelected: selection == nil) {
                        selection = nil
                    }
                }

                ForEach(years, id: \.self) { year in
                    chip(label: String(year), isSelected: selection == year) {
                        selection = year
                    }
                }
            }
            .padding(.horizontal, 20)
        }
        .scrollIndicators(.hidden)
        // ScrollView는 스크롤하지 않는 축으로도 주어진 공간을 전부 차지합니다.
        .fixedSize(horizontal: false, vertical: true)
    }

    private func chip(
        label: String,
        isSelected: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Text(label)
                .font(font)
                .foregroundStyle(isSelected ? .white : PicselColor.textSecondary)
                .padding(.horizontal, 15)
                .padding(.vertical, 8)
                .background {
                    Capsule()
                        .fill(isSelected ? PicselColor.mapYearActive : PicselColor.backgroundWarmWhite)
                        .overlay {
                            // stroke는 선의 절반이 도형 밖으로 나가 모서리가 흐려집니다.
                            Capsule()
                                .strokeBorder(
                                    isSelected ? PicselColor.iconSecondary : PicselColor.borderBrandSubtle,
                                    lineWidth: 1
                                )
                        }
                }
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? [.isSelected, .isButton] : .isButton)
    }
}

#Preview("전체 포함") {
    struct PreviewWrapper: View {
        @State private var selection: Int?

        var body: some View {
            YearFilterChips(years: [2026, 2025, 2024], selection: $selection)
                .padding(.vertical, 12)
                .background(PicselColor.backgroundWarmWhite)
        }
    }

    return PreviewWrapper()
}

#Preview("연도만") {
    struct PreviewWrapper: View {
        @State private var selection: Int? = 2026

        var body: some View {
            YearFilterChips(
                years: [2026, 2025, 2024],
                selection: $selection,
                showsAllOption: false,
                font: PicselFont.subtitle01
            )
            .padding(.vertical, 12)
            .background(PicselColor.surface)
        }
    }

    return PreviewWrapper()
}
