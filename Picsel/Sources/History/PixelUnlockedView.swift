//
//  PixelUnlockedView.swift
//  Picsel
//
//  Created by kosoobin on 8/31/26.
//

import SwiftUI

struct PixelUnlockedView: View {

    let thumbnailData: Data?
    let regionName: String      // "영덕"
    let travelDate: Date
    let tripTitle: String
    let photoCount: Int
    let placeCount: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("새로운 픽셀이 채워졌어요!")
                .font(.title)
                .fontWeight(.bold)
            
            Text("\(regionName) 여행이 나의 픽셀 지도에 기록됐어요.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.gray.opacity(0.2))
                .frame(height: 240)
            
            TripSummaryCard(thumbnailData: thumbnailData, travelDate: travelDate, title: tripTitle, photoCount: photoCount, placeCount: placeCount)

            Spacer()

            // TODO: Step 6 - "홈으로" / "픽셀맵 확인하기" 버튼 2개
        }
        .padding(20)
        .navigationBarBackButtonHidden(true)
    }
}

#Preview {
    PixelUnlockedView(
        thumbnailData: nil,
        regionName: "영덕",
        travelDate: .now,
        tripTitle: "영덕 바다 여행",
        photoCount: 3,
        placeCount: 3)
}
