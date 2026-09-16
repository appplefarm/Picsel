//
//  OnboardingView.swift
//  Picsel
//

import SwiftUI

struct OnboardingView: View {
    let onCompletion: () -> Void
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isShowingSlogan = false
    @State private var hasFinishedPresentation = false

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .topLeading) {
                OnboardingStyle.backgroundGradient
                    .ignoresSafeArea()

                OnboardingLogo()
                    .padding(.top, proxy.size.height * OnboardingStyle.logoTopRatio)

                Text("사진으로 고르고,\n여행을 떠나고,\n픽셀로 남겨요.")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(OnboardingStyle.subtitleGradient)
                    .lineSpacing(6)
                    .padding(.leading, proxy.size.width * OnboardingStyle.subtitleLeadingRatio)
                    .padding(.top, proxy.size.height * OnboardingStyle.subtitleTopRatio)
                    .opacity(isShowingSlogan ? 1 : 0)
                    .offset(y: reduceMotion || isShowingSlogan ? 0 : 18)
            }
        }
        .accessibilityElement(children: .combine)
        .task {
            guard !hasFinishedPresentation else { return }
            await Task.yield()

            if reduceMotion {
                isShowingSlogan = true
            } else {
                withAnimation(.easeOut(duration: 0.55)) {
                    isShowingSlogan = true
                }
            }

            try? await Task.sleep(for: .seconds(1.6))
            guard !Task.isCancelled else { return }

            hasFinishedPresentation = true
            onCompletion()
        }
    }
}

#Preview {
    OnboardingView(onCompletion: { })
}
