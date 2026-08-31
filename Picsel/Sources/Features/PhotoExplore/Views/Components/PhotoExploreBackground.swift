//
//  PhotoExploreBackground.swift
//  Picsel
//

import SwiftUI

/// Figma 배경의 수직 Linear Gradient를 그대로 표현합니다.
struct PhotoExploreBackground: View {
    var body: some View {
        LinearGradient(
            stops: [
                .init(color: color(255), location: 0.27),
                .init(color: color(180), location: 0.53),
                .init(color: color(153), location: 0.72),
                .init(color: color(243), location: 1)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
        .ignoresSafeArea()
        .accessibilityHidden(true)
    }

    private func color(_ grayscale: Double) -> Color {
        let channel = grayscale / 255
        return Color(
            .sRGB,
            red: channel,
            green: channel,
            blue: channel,
            opacity: 1
        )
    }
}
