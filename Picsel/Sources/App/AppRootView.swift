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
                MainTabView(
                    onLogout: logout,
                    onWithdraw: withdrawAccount
                )
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

    private func logout() {
        // 앱 내부 로그인 상태만 해제합니다. 여행 기록 등 로컬 데이터는 보존합니다.
        UserDefaults.standard.removeObject(forKey: "appleUserIdentifier")
        UserDefaults.standard.set(false, forKey: "isLoggedIn")

        withAnimation(.easeInOut(duration: 0.25)) {
            hasCompletedOnboarding = false
        }
    }

    private func withdrawAccount() {
        UserDefaults.standard.removeObject(forKey: "appleUserIdentifier")
        UserDefaults.standard.set(false, forKey: "isLoggedIn")

        withAnimation(.easeInOut(duration: 0.25)) {
            hasCompletedOnboarding = false
        }
    }
}

#Preview {
    AppRootView()
}
