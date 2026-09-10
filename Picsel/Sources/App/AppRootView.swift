//
//  AppRootView.swift
//  Picsel
//

import SwiftUI

struct AppRootView: View {
    @AppStorage("hasCompletedOnboarding")
    private var hasCompletedOnboarding = false

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
