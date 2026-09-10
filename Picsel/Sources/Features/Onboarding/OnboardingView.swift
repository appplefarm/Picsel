//
//  OnboardingView.swift
//  Picsel
//

import SwiftUI

struct OnboardingView: View {
    let onCompletion: () -> Void

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

                Button(action: onCompletion) {
                    Text("시작하기")
                        .font(.headline)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 56)
                        .background(.black)
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                }
                .buttonStyle(.plain)
                .accessibilityHint("Picsel 홈 화면으로 이동합니다")
            }
            .padding(.horizontal, 21)
            .padding(.bottom, 50)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .background(Color(.systemBackground))
    }
}

#Preview {
    OnboardingView(onCompletion: { })
}
