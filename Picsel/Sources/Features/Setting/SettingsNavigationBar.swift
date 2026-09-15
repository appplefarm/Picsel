//
//  SettingsNavigationBar.swift
//  Picsel
//

import SwiftUI

private struct SettingsNavigationHeader: View {
    @Environment(\.dismiss) private var dismiss

    let title: String

    var body: some View {
        ZStack {
            Text(title)
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(PicselColor.textPrimary)

            HStack(spacing: 0) {
                Button(action: dismiss.callAsFunction) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 22, weight: .medium))
                        .frame(width: 36, height: 36)
                }
                .buttonStyle(.glass)
                .buttonBorderShape(.circle)
                .foregroundStyle(PicselColor.homeText)
                .accessibilityLabel("뒤로 가기")

                Spacer(minLength: 0)
            }
        }
        .padding(.horizontal, 16)
        .frame(maxWidth: .infinity)
        .frame(height: 48)
        .padding(.top, 8)
        .background(PicselColor.settingsBackground)
    }
}

private struct SettingsNavigationBarModifier: ViewModifier {
    let title: String

    func body(content: Content) -> some View {
        content
            .toolbar(.hidden, for: .navigationBar)
            .safeAreaInset(edge: .top, spacing: 0) {
                SettingsNavigationHeader(title: title)
            }
    }
}

extension View {
    func settingsNavigationBar(title: String) -> some View {
        modifier(SettingsNavigationBarModifier(title: title))
    }
}
