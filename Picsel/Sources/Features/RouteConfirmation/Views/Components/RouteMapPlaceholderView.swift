//
//  RouteMapPlaceholderView.swift
//  Picsel
//
//  Created by Jonghyeon Lee on 8/31/26.
//

import SwiftUI

/// 카카오맵 경로 컴포넌트가 연결될 자리입니다.
struct RouteMapPlaceholderView: View {
    var body: some View {
        RoundedRectangle(cornerRadius: 16, style: .continuous)
            .fill(Color(.secondarySystemBackground))
            .overlay {
                Text("지도 사진 + 경로 (네비게이션처럼)")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("경로 지도 준비 중")
    }
}

#if DEBUG
#Preview {
    RouteMapPlaceholderView()
        .frame(width: 342, height: 286)
        .padding()
}
#endif
