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
            RoundedRectangle(cornerRadius: 18)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 18)
                .stroke(
                    Color.green.opacity(0.2),
                    lineWidth: 1
                )
        }
    }
}
