//
//  PicxelMapView.swift
//  Picsel
//

import SwiftUI

struct PicxelMapView: View {
    var body: some View {
        ContentUnavailableView(
            "픽셀맵 준비 중",
            systemImage: "mappin.and.ellipse",
            description: Text("여행으로 채운 픽셀을 이곳에서 확인할 수 있어요.")
        )
        .navigationTitle("픽셀맵")
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    NavigationStack {
        PicxelMapView()
    }
}
