//
//  RouteMapPlaceholderView.swift
//  Picsel
//
//  Created by Jonghyeon Lee on 8/31/26.
//

import SwiftUI

/// 그릴 경로가 없을 때 지도 자리에 놓는 안내입니다.
///
/// 장소를 모두 지웠거나, 장소에 좌표가 없어 지도에 세울 것이 하나도 없는 경우입니다.
struct RouteMapPlaceholderView: View {
    var body: some View {
        RoundedRectangle(cornerRadius: 16, style: .continuous)
            .fill(Color(.secondarySystemBackground))
            .overlay {
                VStack(spacing: 8) {
                    Image(systemName: "map")
                        .font(PicselFont.title01)
                        .foregroundStyle(.tertiary)

                    Text("지도에 표시할 경로가 없어요")
                        .font(PicselFont.body02)
                        .foregroundStyle(.secondary)
                }
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("지도에 표시할 경로가 없어요")
    }
}

#if DEBUG
#Preview {
    RouteMapPlaceholderView()
        .frame(width: 342, height: 286)
        .padding()
}
#endif
