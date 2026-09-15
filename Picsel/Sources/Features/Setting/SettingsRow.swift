//
//  SettingsRow.swift
//  Picsel
//
//  Created by DS on 9/10/26.
//
import SwiftUI

struct SettingsRow: View {
    let icon: String
    let title: String
    let description: String
    var minHeight: CGFloat = 76
    let action: () -> Void

    var body: some View {
        Button {
            action()
        } label: {
            HStack(spacing: 15) {

                Image(systemName: icon)
                    .font(.system(size: 18, weight: .medium))
                    .foregroundStyle(PicselColor.settingsIcon)
                    .frame(width: 36, height: 36)
                    .background(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(PicselColor.settingsIconBackground)
                    )

                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(PicselColor.homeText)

                    Text(description)
                        .font(.system(size: 12))
                        .foregroundStyle(PicselColor.settingsSecondaryText)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(PicselColor.settingsSecondaryText.opacity(0.75))
                    .frame(width: 20)
            }
            .padding(.horizontal, 11)
            .frame(minHeight: minHeight)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
