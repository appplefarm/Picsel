//
//  AppRootView.swift
//  Picsel
//

import AuthenticationServices
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
        .onAppear {
            checkAppleCredentialState()
        }
        .onReceive(
            NotificationCenter.default.publisher(
                for: ASAuthorizationAppleIDProvider.credentialRevokedNotification
            )
        ) { _ in
            handleAppleCredentialRevoked()
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

    private func checkAppleCredentialState() {
        guard let userIdentifier = UserDefaults.standard.string(forKey: "appleUserIdentifier") else {
            return
        }

        ASAuthorizationAppleIDProvider().getCredentialState(forUserID: userIdentifier) { state, error in
            // 네트워크 오류나 일시적인 조회 실패를 Apple 연결 해제로 판단하지 않습니다.
            guard error == nil else {
                return
            }

            switch state {
            case .revoked, .notFound:
                DispatchQueue.main.async {
                    handleAppleCredentialRevoked()
                }
            case .authorized, .transferred:
                break
            @unknown default:
                break
            }
        }
    }

    private func handleAppleCredentialRevoked() {
        // 사용자가 iOS 설정에서 Apple 계정 연결을 해제한 경우 앱 내부 로그인 상태만 정리합니다.
        // 회원탈퇴와 달리 여행/픽셀 데이터는 삭제하지 않습니다.
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
