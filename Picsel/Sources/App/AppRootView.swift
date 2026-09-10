//
//  AppRootView.swift
//  Picsel
//

import SwiftUI

struct AppRootView: View {
    @AppStorage("hasCompletedOnboarding")
    private var hasCompletedOnboarding = false

    /// 탭 이동과 여행 흐름 종료를 화면들이 함께 쓰기 위해 최상위에서 만듭니다.
    @State private var router = AppRouter()

    var body: some View {
        Group {
            if hasCompletedOnboarding {
                MainTabView()
                    .transition(.opacity)
            } else {
                OnboardingView {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        hasCompletedOnboarding = true
                    }
                }
                .transition(.opacity)
            }
        }
        .environment(router)
    }
}

#Preview {
    AppRootView()
}
