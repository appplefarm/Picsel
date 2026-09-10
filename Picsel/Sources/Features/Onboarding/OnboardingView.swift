//
//  OnboardingView.swift
//  Picsel
//

import AuthenticationServices
import SwiftUI

struct OnboardingView: View {
    let onCompletion: () -> Void
    
    @State private var isShowingSignInError = false
    @State private var signInErrorMessage = "잠시 후 다시 시도해 주세요."
    
    var body: some View {
        GeometryReader { geometry in
            VStack(spacing: 0) {
                Spacer()
                    .frame(height: geometry.size.height * 0.40)
                
                Text("Picsel")
                    .font(.largeTitle)
                    .fontWeight(.semibold)
                    .foregroundStyle(.primary)
                    .frame(maxWidth: .infinity)
                
                Text("사진으로 고르고,\n경로로 떠나고,\n픽셀로 남겨요.")
                    .font(.title2)
                    .fontWeight(.semibold)
                    .foregroundStyle(.primary)
                    .multilineTextAlignment(.leading)
                    .padding(.top, 76)
                
                Spacer(minLength: 24)
                
                SignInWithAppleButton(
                    .continue,
                    onRequest: configureAppleIDRequest,
                    onCompletion: handleAppleIDCompletion
                )
                .signInWithAppleButtonStyle(.black)
                .frame(maxWidth: .infinity)
                .frame(height: 56)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .accessibilityHint("Apple 계정으로 인증하고 Picsel을 시작합니다")
                
                Text("계속하면 서비스 이용약관 및 개인정보 처리방침에 동의하게 됩니다.")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 6)
                    .padding(.top, 32)
                    .padding(.bottom, 50)
            }
            .padding(.horizontal, 21)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .background(Color(.systemBackground))
        .alert("Apple 계정으로 시작할 수 없어요", isPresented: $isShowingSignInError) {
            Button("확인", role: .cancel) { }
        } message: {
            Text(signInErrorMessage)
        }
    }
    
    private func configureAppleIDRequest(_ request: ASAuthorizationAppleIDRequest) {
        request.requestedScopes = [.fullName, .email]
    }
    
    private func handleAppleIDCompletion(
        _ result: Result<ASAuthorization, any Error>
    ) {
        switch result {
            
        case .success(let authorization):
            
            guard let credential =
                    authorization.credential as? ASAuthorizationAppleIDCredential
            else {
                return
            }
            
            let userIdentifier = credential.user
            
            UserDefaults.standard.set(
                userIdentifier,
                forKey: "appleUserIdentifier"
            )
            
            onCompletion()
            
        case .failure(let error):
            signInErrorMessage = error.localizedDescription
            isShowingSignInError = true
        }
    }
}

#Preview {
    OnboardingView(onCompletion: { })
}
