//
//  SettingsSheetCloseButton.swift
//  Picsel
//

import SwiftUI

/// 설정 상세 sheet에서 공통으로 사용하는 닫기 버튼입니다.
struct SettingsSheetCloseButton: View {
    let accessibilityLabel: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: "xmark")
                .font(.system(size: 20, weight: .regular))
                .frame(width: 36, height: 36)
        }
        .buttonStyle(.glass)
        .buttonBorderShape(.circle)
        .foregroundStyle(PicselColor.homeText)
        .accessibilityLabel(accessibilityLabel)
    }
}

/// 설정의 정보성 sheet에서 공통으로 사용하는 고정 헤더입니다.
private struct SettingsModalHeader: View {
    let title: String
    let accessibilityLabel: String
    let showsBoundary: Bool
    let action: () -> Void

    var body: some View {
        HStack(spacing: 16) {
            Text(title)
                .font(.system(size: 24, weight: .bold))
                .foregroundStyle(Color(hex: 0x303B37))

            Spacer(minLength: 0)

            SettingsSheetCloseButton(
                accessibilityLabel: accessibilityLabel,
                action: action
            )
        }
        .padding(.leading, 27)
        .padding(.trailing, 16)
        .frame(height: SettingsModalScaffoldMetrics.headerHeight)
        .background(Color.white)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(Color(hex: 0xDDE4E1))
                .frame(height: 0.5)
                .opacity(showsBoundary ? 1 : 0)
                .shadow(
                    color: Color.black.opacity(showsBoundary ? 0.08 : 0),
                    radius: 5,
                    y: 3
                )
        }
        .animation(.easeOut(duration: 0.18), value: showsBoundary)
    }
}

/// 제목과 닫기 버튼은 고정하고 본문만 스크롤하는 공통 sheet 구조입니다.
struct SettingsModalScaffold<Content: View>: View {
    @Environment(\.dismiss) private var dismiss

    let title: String
    let closeAccessibilityLabel: String
    private let content: Content

    @State private var isScrolled = false

    init(
        title: String,
        closeAccessibilityLabel: String,
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.closeAccessibilityLabel = closeAccessibilityLabel
        self.content = content()
    }

    var body: some View {
        ZStack(alignment: .top) {
            Color.white
                .ignoresSafeArea()

            ScrollView {
                VStack(spacing: 0) {
                    GeometryReader { proxy in
                        Color.clear
                            .preference(
                                key: SettingsModalScrollOffsetKey.self,
                                value: proxy.frame(
                                    in: .named(SettingsModalScaffoldMetrics.coordinateSpace)
                                ).minY
                            )
                    }
                    .frame(height: 0)

                    content
                        .padding(.horizontal, 27)
                        .padding(.top, SettingsModalScaffoldMetrics.headerHeight + 16)
                        .padding(.bottom, 48)
                }
            }
            .coordinateSpace(name: SettingsModalScaffoldMetrics.coordinateSpace)
            .scrollIndicators(.hidden)
            .onPreferenceChange(SettingsModalScrollOffsetKey.self) { offset in
                isScrolled = offset < -1
            }

            SettingsModalHeader(
                title: title,
                accessibilityLabel: closeAccessibilityLabel,
                showsBoundary: isScrolled,
                action: dismiss.callAsFunction
            )
            .zIndex(1)
        }
        .toolbar(.hidden, for: .navigationBar)
    }
}

private enum SettingsModalScaffoldMetrics {
    static let headerHeight: CGFloat = 76
    static let coordinateSpace = "settings-modal-scroll"
}

private struct SettingsModalScrollOffsetKey: PreferenceKey {
    static var defaultValue: CGFloat = 0

    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}
