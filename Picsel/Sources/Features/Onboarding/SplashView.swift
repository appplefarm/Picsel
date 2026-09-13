//
//  SplashView.swift
//  Picsel
//

import SwiftUI

struct SplashView: View {
    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .topLeading) {
                OnboardingStyle.backgroundGradient
                    .ignoresSafeArea()

                OnboardingLogo()
                    .padding(.top, proxy.size.height * 0.38)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Picsel")
    }
}

struct OnboardingLogo: View {
    var body: some View {
        Text("Picsel")
            .font(.system(size: 36, weight: .semibold))
            .foregroundStyle(OnboardingStyle.logoColor)
            .frame(maxWidth: .infinity)
    }
}

enum OnboardingStyle {
    static let backgroundGradient = LinearGradient(
        stops: [
            .init(color: Color(hex: 0x54CA8B), location: 0.6875),
            .init(color: Color(hex: 0x70E4BA), location: 1)
        ],
        startPoint: .top,
        endPoint: .bottom
    )
    static let logoColor = Color(hex: 0xF2FDF8)
    static let subtitleColor = Color(hex: 0x00725D)
}

#Preview {
    SplashView()
}
