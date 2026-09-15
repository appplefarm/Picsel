//
//  Version.swift
//  Picsel
//
//  Created by DS on 9/10/26.
//

import SwiftUI

struct VersionRow: View {
    var body: some View {
        HStack(spacing: 15) {
            
            Image(systemName: "info.circle")
                .font(.system(size: 18, weight: .medium))
                .foregroundStyle(PicselColor.settingsIcon)
                .frame(width: 36, height: 36)
                .background(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(PicselColor.settingsIconBackground)
                )

            VStack(alignment: .leading, spacing: 4) {
                Text("버전 정보")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(PicselColor.homeText)

                Text("현재 설치된 앱 버전")
                    .font(.system(size: 12))
                    .foregroundStyle(PicselColor.settingsSecondaryText)
            }

            Spacer()

            Text(AppInfo.displayVersion)
                .font(.system(size: 12))
                .foregroundStyle(PicselColor.settingsSecondaryText.opacity(0.85))
                .padding(.trailing, 9)
        }
        .padding(.horizontal, 11)
        .frame(minHeight: 76)
    }
}
