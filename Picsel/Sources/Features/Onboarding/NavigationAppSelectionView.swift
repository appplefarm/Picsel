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
    @AppStorage("preferredNavigationApp")
    private var selectedApp: NavigationApp = .kakaoMap

    let onContinue: () -> Void

    private let apps: [NavigationApp] = [.kakaoMap, .tmap, .naverMap]

    var body: some View {
        GeometryReader { proxy in
            let isCompactHeight = proxy.size.height < 760

            VStack(alignment: .leading, spacing: 0) {
                header
                    .padding(.top, proxy.safeAreaInsets.top + (isCompactHeight ? 24 : 68))

                appList
                    .padding(.top, isCompactHeight ? 28 : 48)

                Spacer(minLength: 24)

                continueButton
                    .padding(.bottom, proxy.safeAreaInsets.bottom + (isCompactHeight ? 12 : 48))
            }
            .padding(.horizontal, 20)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .background(Color.white.ignoresSafeArea())
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("길 찾을 때\n어떤 앱을 사용하세요?")
                .font(.system(size: 24, weight: .bold))
                .foregroundStyle(PicselColor.homeText)
                .lineSpacing(3)

            Text("선택한 앱으로 바로 길 안내를 연결해드릴게요.\n나중에 설정에서 언제든 바꿀 수 있어요.")
                .font(.system(size: 14))
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

    private var continueButton: some View {
        Button(action: onContinue) {
            Text("다음")
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(PicselColor.onPrimary)
                .frame(maxWidth: .infinity)
                .frame(height: 66)
                .background(
                    LinearGradient(
                        colors: [
                            PicselColor.homeCTA,
                            PicselColor.navigationButtonHighlight,
                            PicselColor.homeCTA
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityHint("선택한 길찾기 앱을 저장하고 홈 화면으로 이동합니다")
    }
}

private struct NavigationAppSelectionRow: View {
    let app: NavigationApp
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(app.assetName)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 52, height: 52)

                VStack(alignment: .leading, spacing: 4) {
                    Text(app.displayName)
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(PicselColor.homeText)

                    Text(app.selectionDescription)
                        .font(.system(size: 14))
                        .foregroundStyle(PicselColor.navigationDescription)
                }

                Spacer(minLength: 8)

                selectionIndicator
            }
            .padding(.horizontal, 12)
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
            Circle()
                .stroke(
                    isSelected ? PicselColor.navigationSelectedBorder : PicselColor.navigationBorder,
                    lineWidth: isSelected ? 2 : 1
                )
                .frame(width: 20, height: 20)

            if isSelected {
                Circle()
                    .fill(PicselColor.navigationSelectedBorder)
                    .frame(width: 10, height: 10)
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
