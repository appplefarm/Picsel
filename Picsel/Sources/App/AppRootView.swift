//
//  AppRootView.swift
//  Picsel
//

import SwiftUI

struct AppRootView: View {
    private enum LaunchPhase {
        case splash
        case onboarding
        case content
    }

    @State private var launchPhase: LaunchPhase = .splash

    @AppStorage("hasSelectedNavigationApp")
    private var hasSelectedNavigationApp = false

    /// 탭 이동과 여행 흐름 종료를 화면들이 함께 쓰기 위해 최상위에서 만듭니다.
    @State private var router = AppRouter()

    var body: some View {
        Group {
            switch launchPhase {
            case .splash:
                SplashView()
                    .task {
                        try? await Task.sleep(for: .seconds(0.8))
                        guard !Task.isCancelled else { return }
                        launchPhase = .onboarding
                    }

            case .onboarding:
                OnboardingView {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        launchPhase = .content
                    }
                }
                .transition(.opacity)

            case .content:
                if hasSelectedNavigationApp {
                    MainTabView()
                        .transition(.opacity)
                } else {
                    NavigationAppSelectionView {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            hasSelectedNavigationApp = true
                        }
                    }
                    .transition(.opacity)
                }
            }
        }
        .environment(router)
    }
}

#Preview {
    AppRootView()
}
