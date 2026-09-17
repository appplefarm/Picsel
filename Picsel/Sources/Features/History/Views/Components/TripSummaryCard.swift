//
//  TripSummaryCard.swift
//  Picsel
//
//  Created by kosoobin on 8/31/26.
//

import SwiftUI

struct TripSummaryCard: View {
    let thumbnailData: Data?
    let travelDate: Date
    let title: String
    let photoCount: Int
    let placeCount: Int
    
    var body: some View {
        // TODO: Step 6 - 좌측 썸네일 + 우측(날짜 / 제목 / "사진 3장 · 방문 3곳")
        HStack(spacing: 12) {
            Group {
                if let data = thumbnailData, let uiImage = UIImage(data: data) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFill()
                } else {
                    Color.gray.opacity(0.2)
                }
            }
            .frame(width: 56, height: 56)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            
            VStack(alignment: .leading, spacing: 4) {
                Text(travelDate, format: .dateTime.year().month(.twoDigits).day(.twoDigits))
                    .font(PicselFont.caption01)
                    .foregroundStyle(.secondary)
                
                Text(title)
                    .font(PicselFont.label01)
                
                Text("사진 \(photoCount)장 · 방문 \(placeCount)곳")
                    .font(PicselFont.caption01)
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 18)
                .fill(Color.gray.opacity(0.08))
        )
        
    }
}


