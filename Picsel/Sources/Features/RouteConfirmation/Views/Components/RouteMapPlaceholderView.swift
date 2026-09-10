//
//  RouteMapPlaceholderView.swift
//  Picsel
//
//  Created by Jonghyeon Lee on 8/31/26.
//

import SwiftUI

/// 좌표가 없어 경로 지도를 표시할 수 없는 상태입니다.
struct RouteMapPlaceholderView: View {
    var body: some View {
        RoundedRectangle(cornerRadius: 16, style: .continuous)
            .fill(Color(.secondarySystemBackground))
            .overlay {
                Text("위치를 확인할 수 없음")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("위치를 확인할 수 없음")
    }
}

#if DEBUG
#Preview {
    RouteMapPlaceholderView()
        .frame(width: 342, height: 286)
        .padding()
}
#endif
