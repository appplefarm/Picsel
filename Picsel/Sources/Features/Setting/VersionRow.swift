//
//  Version.swift
//  Picsel
//
//  Created by DS on 9/10/26.
//

import SwiftUI

struct VersionRow: View {
    private var appVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "-"
    }

    var body: some View {
        HStack(spacing: 16) {
            
            Image(systemName: "info.circle")
                .font(.system(size: 22))
                .foregroundStyle(Color.green)
                .frame(width: 52, height: 52)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color.green.opacity(0.10))
                )

            VStack(alignment: .leading, spacing: 4) {
                Text("버전 정보")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(Color.primary)

                Text("현재 설치된 앱 버전")
                    .font(.system(size: 14))
                    .foregroundStyle(Color.secondary)
            }

            Spacer()

            Text(appVersion)
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
    }
}
