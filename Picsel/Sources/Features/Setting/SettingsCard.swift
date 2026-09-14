//
//  Untitled.swift
//  Picsel
//
//  Created by DS on 9/10/26.
//
import SwiftUI

struct SettingsCard<Content: View>: View {

    @ViewBuilder let content: Content

    var body: some View {
        VStack(spacing: 0) {
            content
        }
        .background(Color.white)
        .clipShape(
            RoundedRectangle(cornerRadius: 13, style: .continuous)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 13, style: .continuous)
                .stroke(
                    PicselColor.settingsBorder,
                    lineWidth: 1
                )
        }
    }
}
