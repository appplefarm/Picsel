//
//  HomeSettingsButton.swift
//  Picsel
//

import SwiftUI

/// Home 계열 화면에서 공통으로 사용하는 원형 glass 설정 버튼입니다.
struct HomeSettingsButton: View {
    let foregroundColor: Color?
    let action: () -> Void

    init(
        foregroundColor: Color? = nil,
        action: @escaping () -> Void
    ) {
        self.foregroundColor = foregroundColor
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            icon
        }
        .buttonStyle(.glass)
        .buttonBorderShape(.circle)
        .controlSize(.large)
        .accessibilityLabel("설정")
    }

    @ViewBuilder
    private var icon: some View {
        if let foregroundColor {
            settingsIcon
                .foregroundStyle(foregroundColor)
        } else {
            settingsIcon
        }
    }

    private var settingsIcon: some View {
        Image(systemName: "gearshape")
            .font(.system(size: 22, weight: .medium))
    }
}

