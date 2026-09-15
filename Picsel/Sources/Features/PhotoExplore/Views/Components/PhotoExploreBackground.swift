//
//  PhotoExploreBackground.swift
//  Picsel
//
//  Created by Jonghyeon Lee on 8/28/26.
//

import SwiftUI

/// Figma 배경의 수직 Linear Gradient를 그대로 표현합니다.
struct PhotoExploreBackground: View {
    var body: some View {
        LinearGradient(
            stops: [
                .init(color: PicselColor.surface, location: 0.20192),
                .init(color: Color(hex: 0xF4FAF9), location: 0.48558),
                .init(color: Color(hex: 0xC5E1E1), location: 0.65385),
                .init(color: Color(hex: 0xEEF8F6), location: 1)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
        .ignoresSafeArea()
        .accessibilityHidden(true)
    }
}
