//
//  NavigationAppSelectionView.swift
//  Picsel
//

import SwiftUI

/// 첫 진입 시 길찾기에 사용할 앱을 선택하는 화면입니다.
///
/// 선택값은 여행 진행 화면의 `preferredNavigationApp`과 같은 키에 저장되어
/// 이후 길찾기 실행 시 별도의 변환 없이 그대로 사용됩니다.
struct NavigationAppSelectionView: View {
    enum Presentation {
        case onboarding
        case settings
    }

    @AppStorage("preferredNavigationApp")
    private var storedApp: NavigationApp = .kakaoMap

    @State private var selectedApp: NavigationApp = .kakaoMap

    let presentation: Presentation
    let onContinue: () -> Void

    private let apps: [NavigationApp] = [.kakaoMap, .tmap, .naverMap]

    init(
        presentation: Presentation = .onboarding,
        onContinue: @escaping () -> Void
    ) {
        self.presentation = presentation
        self.onContinue = onContinue
    }

    @ViewBuilder
    var body: some View {
        switch presentation {
        case .onboarding:
            onboardingContent

        case .settings:
            settingsContent
                .settingsNavigationBar(title: "네비게이션")
        }
    }

    private var onboardingContent: some View {
        GeometryReader { proxy in
            let isCompactHeight = proxy.size.height < 760

            VStack(alignment: .leading, spacing: 0) {
                header
                    .padding(.top, proxy.safeAreaInsets.top + (isCompactHeight ? 24 : 78))

                appList
                    .padding(.top, isCompactHeight ? 28 : 48)

                Spacer(minLength: 24)

                saveButton(title: "다음")
                    // 상위 레이아웃의 20pt에 4pt를 더해 최종 24pt로 맞춘다.
                    .padding(.horizontal, 4)
                    .padding(.bottom, 24)
            }
            .padding(.horizontal, 20)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .background(Color.white.ignoresSafeArea())
        }
        .onAppear(perform: loadStoredSelection)
    }

    private var settingsContent: some View {
        GeometryReader { proxy in
            VStack(alignment: .leading, spacing: 0) {
                VStack {
                    Text("길 안내에 사용할 기본 앱을 선택해주세요.\n여행 중 언제든 다시 변경할 수 있어요.")
                        .font(PicselFont.body01)
                        .foregroundStyle(PicselColor.settingsSecondaryText)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: true, vertical: false)
                }
                .frame(maxWidth: .infinity)
                .frame(height: 100)
                .padding(.horizontal, 16)
                .padding(.vertical, 20)

                appList
                    .padding(.leading, 24)
                    .padding(.trailing, 16)
                    .padding(.top, proxy.size.height < 700 ? 40 : 78)

                Spacer(minLength: 24)

                saveButton(title: "선택 저장")
                    .padding(.horizontal, 24)
                    .padding(.bottom, 24)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .background(PicselColor.settingsBackground.ignoresSafeArea())
        }
        .onAppear(perform: loadStoredSelection)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("길 찾을 때\n어떤 앱을 사용하세요?")
                .font(PicselFont.title02)
                .foregroundStyle(PicselColor.homeText)
                .lineSpacing(3)

            Text("선택한 앱으로 바로 길 안내를 연결해드릴게요.\n나중에 설정에서 언제든 바꿀 수 있어요.")
                .font(PicselFont.body01)
                .foregroundStyle(PicselColor.navigationDescription)
                .lineSpacing(7)
        }
    }

    private var appList: some View {
        VStack(spacing: 12) {
            ForEach(apps) { app in
                NavigationAppSelectionRow(
                    app: app,
                    isSelected: selectedApp == app
                ) {
                    selectedApp = app
                }
            }
        }
    }

    private func saveButton(title: String) -> some View {
        Button(action: saveSelection) {
            Text(title)
                .font(PicselFont.label01)
        }
        .buttonStyle(.primaryGradient)
        .accessibilityHint("선택한 길찾기 앱을 기본 앱으로 저장합니다")
    }

    private func loadStoredSelection() {
        selectedApp = storedApp
    }

    private func saveSelection() {
        storedApp = selectedApp
        onContinue()
    }
}

private struct NavigationAppSelectionRow: View {
    let app: NavigationApp
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 19) {
                Image(app.assetName)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 52, height: 52)

                VStack(alignment: .leading, spacing: 4) {
                    Text(app.displayName)
                        .font(PicselFont.label01)
                        .foregroundStyle(PicselColor.homeText)

                    Text(app.selectionDescription)
                        .font(PicselFont.caption01)
                        .foregroundStyle(PicselColor.navigationDescription)
                }

                Spacer(minLength: 8)

                selectionIndicator
            }
            .padding(.leading, 14)
            .padding(.trailing, 16)
            .frame(maxWidth: .infinity)
            .frame(height: 76)
            .background(isSelected ? PicselColor.navigationSelectedBackground : Color.white)
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(
                        isSelected ? PicselColor.navigationSelectedBorder : PicselColor.navigationBorder,
                        lineWidth: isSelected ? 2 : 1
                    )
            }
            .contentShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(app.displayName), \(app.selectionDescription)")
        .accessibilityValue(isSelected ? "선택됨" : "선택 안 됨")
    }

    private var selectionIndicator: some View {
        ZStack {
            if isSelected {
                Circle()
                    .fill(PicselColor.navigationSelectedBorder)
                    .frame(width: 22, height: 22)

                Circle()
                    .fill(Color.white)
                    .frame(width: 7, height: 7)
            } else {
                Circle()
                    .stroke(PicselColor.navigationBorder, lineWidth: 1.5)
                    .frame(width: 22, height: 22)
            }
        }
        .accessibilityHidden(true)
    }
}

private extension NavigationApp {
    var selectionDescription: String {
        switch self {
        case .kakaoMap: "장소 탐색과 길찾기"
        case .tmap: "운전 경로와 실시간 교통"
        case .naverMap: "대중교통과 장소 검색"
        }
    }

    var assetName: String {
        switch self {
        case .kakaoMap: "KakaoMapIcon"
        case .tmap: "TMapIcon"
        case .naverMap: "NaverMapIcon"
        }
    }
}

#Preview {
    NavigationAppSelectionView(onContinue: { })
}
