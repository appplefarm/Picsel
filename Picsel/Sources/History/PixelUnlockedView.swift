//
//  PixelUnlockedView.swift
//  Picsel
//
//  Created by kosoobin on 8/31/26.
//

import SwiftUI

struct PixelUnlockedView: View {

    let regionName: String      // "영덕"
    let travelDate: Date
    let tripTitle: String
    let photoCount: Int
    let placeCount: Int

    var body: some View {
        VStack(spacing: 24) {
            // TODO: Step 6 - 헤더 ("새로운 픽셀이 채워졌어요!" + "OO 여행이 나의 픽셀 지도에 기록됐어요")

            // TODO: Step 6 - 대표 사진 / 픽셀맵 영역 (지금은 회색 박스 placeholder)

            // TODO: Step 6 - TripSummaryCard(...)

            Spacer()

            // TODO: Step 6 - "홈으로" / "픽셀맵 확인하기" 버튼 2개
        }
        .padding(20)
        .navigationBarBackButtonHidden(true)
    }
}

#Preview {
    PixelUnlockedView(regionName: "영덕",
                      travelDate: .now,
                      tripTitle: "영덕 바다 여행",
                      photoCount: 3,
                      placeCount: 3)
}
