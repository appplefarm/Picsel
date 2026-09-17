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
                    .padding(.top, proxy.size.height * OnboardingStyle.logoTopRatio)
            }
        }
        .ignoresSafeArea()
        .preferredColorScheme(.light)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Picsel")
    }
}

struct OnboardingLogo: View {
    var body: some View {
        HStack(spacing: 15) {
            Image("OnboardingLogoMark")
                .resizable()
                .frame(width: 35, height: 39)
                .accessibilityHidden(true)

            Text("Picsel")
                .font(PicselFont.title01)
                .foregroundStyle(OnboardingStyle.logoColor)
        }
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity)
        .offset(x: -9)
    }
}

enum OnboardingStyle {
    static let logoTopRatio = 0.38
    static let subtitleTopRatio = 0.515
    static let subtitleLeadingRatio = 0.345

    static let backgroundGradient = LinearGradient(
        stops: [
            .init(color: Color(hex: 0x54CA8B), location: 0.6875),
            .init(color: Color(hex: 0x70E4BA), location: 1)
        ],
        startPoint: .top,
        endPoint: .bottom
    )
    static let logoColor = Color(hex: 0xFBFFFD)
    static let subtitleGradient = LinearGradient(
        stops: [
            .init(color: Color(hex: 0x00725D), location: 0.33654),
            .init(color: Color(hex: 0x267B5E), location: 1)
        ],
        startPoint: .top,
        endPoint: .bottom
    )
}

#Preview {
    SplashView()
}
